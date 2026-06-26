# Agriculture Chatbot — FLAN-T5 Fine-Tuning Pipeline

Fine-tunes [FLAN-T5](https://huggingface.co/google/flan-t5-small) on the
agriculture Q&A dataset (`agri_chatbot.csv`) to build a question-answering
chatbot.

Training uses **LoRA (PEFT)** rather than full fine-tuning, which cuts GPU
memory roughly 5-10x. This matters on Apple Silicon (MPS), where full FLAN-T5
fine-tuning runs out of memory. The LoRA adapter is merged back into the base
model before saving, so the saved model is a plain seq2seq model and inference
needs no PEFT-specific code.

The pipeline is split into **three independent stages** so you clean and train
**once** and then reuse the cached data and saved model forever:

```
clean_dataset.py  ->  train_flan_t5.py  ->  inference.py
   (clean once)        (train once)          (load & answer, no retrain)
```

## Folder layout

Lives at `ml_train/chatbot/` (raw `agri_chatbot.csv` sits one level up in
`ml_train/`). Run the commands below from inside `ml_train/chatbot/`.

```
ml_train/chatbot/
├── config.py            # all paths + hyper-parameters in one place
├── clean_dataset.py     # Step 1: clean raw CSV -> cached parquet/csv
├── train_flan_t5.py     # Step 2: fine-tune FLAN-T5 on the cached data
├── inference.py         # Step 3: load saved model & answer questions
├── requirements.txt
├── data/
│   └── processed/       # cached cleaned data (created by step 1)
│       ├── agri_chatbot_clean.csv
│       ├── train.parquet
│       └── val.parquet
└── models/
    └── flan_t5_agri/    # saved fine-tuned model (created by step 2)
```

## Setup

```bash
cd ml_train/chatbot
pip install -r requirements.txt
```

## Usage

```bash
# 1. Clean the raw CSV once. Re-run only if ../agri_chatbot.csv changes.
python clean_dataset.py

# 2. Fine-tune FLAN-T5 once. The model is saved to models/flan_t5_agri/.
python train_flan_t5.py

# 3. Ask questions — loads the saved model, never retrains.
python inference.py "what is crop rotation?"
python inference.py            # interactive mode
```

## Why the data is cached

`clean_dataset.py` writes the cleaned, de-duplicated, train/val-split data to
`data/processed/`. Training reads those files directly, so the (slow) cleaning
step never runs again unless you choose to. Likewise the fine-tuned model is
saved to `models/flan_t5_agri/`, so inference and the API never retrain.

## Tuning

Edit `config.py`:

- `BASE_MODEL` — switch to `google/flan-t5-base` for better answers (needs a GPU).
- `NUM_EPOCHS`, `BATCH_SIZE`, `GRAD_ACCUM_STEPS`, `LEARNING_RATE` — training knobs.
  Effective batch size is `BATCH_SIZE * GRAD_ACCUM_STEPS`.
- `USE_LORA`, `LORA_R`, `LORA_ALPHA`, `LORA_TARGET_MODULES` — LoRA settings.
  Set `USE_LORA = False` for full fine-tuning (only if you have plenty of GPU RAM).
- `PROMPT_PREFIX` — the instruction prepended to every question.

## Memory notes (Apple Silicon / MPS)

- LoRA + `BATCH_SIZE=1` + `GRAD_ACCUM_STEPS=8` + gradient checkpointing keeps
  memory low while preserving an effective batch size of 8.
- Mixed-precision `fp16` is **off** — it's unsupported/buggy on MPS, which
  prefers fp32 (or bf16).
- If you still hit OOM, lower `MAX_INPUT_LENGTH`/`MAX_TARGET_LENGTH`, raise
  `GRAD_ACCUM_STEPS`, or switch to `flan-t5-small`.
- Note: **QLoRA (4-bit) is not used** because `bitsandbytes` does not support
  Apple MPS. Plain LoRA is the right choice here.

## Use from other code

```python
from ML.inference import AgriChatbot

bot = AgriChatbot()          # loads the saved model once
print(bot.answer("how do I control pests in maize?"))
```
