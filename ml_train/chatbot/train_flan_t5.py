"""
Step 2 of the pipeline: fine-tune FLAN-T5 on the cleaned agriculture Q&A data.

Run AFTER clean_dataset.py:

    python ML/train_flan_t5.py

Uses LoRA (PEFT) instead of full fine-tuning, which cuts GPU memory ~5-10x --
important on Apple Silicon (MPS) where full FLAN-T5 fine-tuning OOMs. The LoRA
adapter is merged back into the base model before saving, so the result is a
plain seq2seq model and inference.py needs no PEFT-specific loading code.

The fine-tuned model + tokenizer are saved to ML/models/flan_t5_agri/.
Because the model is saved to disk, you only train ONCE -- inference.py
loads the saved model and never retrains.

If the cleaned parquet files are missing, this script tells you to run the
cleaning step first (it will not silently re-clean).
"""

import os

# Let MPS fall back to CPU for any op it doesn't implement, and don't cap the
# memory high-watermark (lets PyTorch use more of the unified memory pool).
os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")
os.environ.setdefault("PYTORCH_MPS_HIGH_WATERMARK_RATIO", "0.0")

from datasets import Dataset
from peft import LoraConfig, TaskType, get_peft_model
from transformers import (
    AutoModelForSeq2SeqLM,
    AutoTokenizer,
    DataCollatorForSeq2Seq,
    Seq2SeqTrainer,
    Seq2SeqTrainingArguments,
)

import config


def load_cached_splits():
    """Load the train/val parquet files produced by clean_dataset.py."""
    if not config.TRAIN_PARQUET.exists() or not config.VAL_PARQUET.exists():
        raise FileNotFoundError(
            "Cleaned data not found. Run:  python ML/clean_dataset.py  first."
        )
    train_ds = Dataset.from_parquet(str(config.TRAIN_PARQUET))
    val_ds = Dataset.from_parquet(str(config.VAL_PARQUET))
    print(f"Loaded {len(train_ds):,} train / {len(val_ds):,} val examples")
    return train_ds, val_ds


def build_preprocessor(tokenizer):
    """Return a batched tokenisation function for question -> answer."""

    def preprocess(batch):
        inputs = [config.PROMPT_PREFIX + q for q in batch["question"]]
        model_inputs = tokenizer(
            inputs,
            max_length=config.MAX_INPUT_LENGTH,
            truncation=True,
            padding=False,
        )
        labels = tokenizer(
            text_target=batch["answer"],
            max_length=config.MAX_TARGET_LENGTH,
            truncation=True,
            padding=False,
        )
        model_inputs["labels"] = labels["input_ids"]
        return model_inputs

    return preprocess


def main() -> None:
    config.ensure_dirs()

    train_ds, val_ds = load_cached_splits()

    print(f"Loading base model: {config.BASE_MODEL}")
    tokenizer = AutoTokenizer.from_pretrained(config.BASE_MODEL)
    model = AutoModelForSeq2SeqLM.from_pretrained(config.BASE_MODEL)

    # --- wrap with LoRA: freeze the base model, train tiny adapters only --- #
    if config.USE_LORA:
        lora_config = LoraConfig(
            task_type=TaskType.SEQ_2_SEQ_LM,
            r=config.LORA_R,
            lora_alpha=config.LORA_ALPHA,
            lora_dropout=config.LORA_DROPOUT,
            target_modules=config.LORA_TARGET_MODULES,
        )
        model = get_peft_model(model, lora_config)
        model.print_trainable_parameters()

    preprocess = build_preprocessor(tokenizer)
    train_tok = train_ds.map(
        preprocess, batched=True, remove_columns=train_ds.column_names
    )
    val_tok = val_ds.map(
        preprocess, batched=True, remove_columns=val_ds.column_names
    )

    data_collator = DataCollatorForSeq2Seq(tokenizer, model=model)

    args = Seq2SeqTrainingArguments(
        output_dir=str(config.MODELS_DIR / "checkpoints"),
        num_train_epochs=config.NUM_EPOCHS,
        per_device_train_batch_size=config.BATCH_SIZE,
        per_device_eval_batch_size=config.BATCH_SIZE,
        gradient_accumulation_steps=config.GRAD_ACCUM_STEPS,
        learning_rate=config.LEARNING_RATE,
        weight_decay=0.01,
        # MPS prefers fp32/bf16; fp16 mixed-precision is buggy/unsupported on
        # Apple Silicon, so keep it off. LoRA already provides the memory win.
        fp16=False,
        bf16=False,
        # Trade compute for memory by not caching activations.
        gradient_checkpointing=True,
        eval_strategy="epoch",
        save_strategy="epoch",
        save_total_limit=1,
        logging_steps=50,
        predict_with_generate=True,
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        seed=config.SEED,
        report_to="none",
    )

    # Gradient checkpointing + PEFT: the frozen base produces no-grad inputs, so
    # we must explicitly make the input embeddings require grad.
    if config.USE_LORA and args.gradient_checkpointing:
        model.enable_input_require_grads()

    trainer = Seq2SeqTrainer(
        model=model,
        args=args,
        train_dataset=train_tok,
        eval_dataset=val_tok,
        tokenizer=tokenizer,
        data_collator=data_collator,
    )

    print("\nStarting fine-tuning ...")
    trainer.train()

    metrics = trainer.evaluate()
    print(f"Final eval_loss: {metrics.get('eval_loss'):.4f}")

    print(f"\nSaving fine-tuned model to {config.MODEL_DIR}")
    if config.USE_LORA:
        # Merge the LoRA adapter into the base weights and save a plain
        # seq2seq model. inference.py then loads it like any other model --
        # no PEFT dependency required at serving time.
        merged = trainer.model.merge_and_unload()
        merged.save_pretrained(str(config.MODEL_DIR))
    else:
        trainer.save_model(str(config.MODEL_DIR))
    tokenizer.save_pretrained(str(config.MODEL_DIR))

    print("\nDone. Run:  python ML/inference.py  to chat with the model.")


if __name__ == "__main__":
    main()
