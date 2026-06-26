"""
Step 3 of the pipeline: load the fine-tuned model and answer questions.

The model is loaded from disk (ML/models/flan_t5_agri/) -- NO retraining.

Use it interactively:
    python ML/inference.py

Or one-shot from the command line:
    python ML/inference.py "what is crop rotation?"

Or import it from other code (e.g. the FastAPI service):
    from ML.inference import AgriChatbot
    bot = AgriChatbot()
    print(bot.answer("how do I control pests?"))
"""

import sys

import os

os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")

import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

import config


class AgriChatbot:
    """Thin wrapper around the fine-tuned FLAN-T5 model. Load once, reuse."""

    def __init__(self, model_dir=None):
        model_dir = str(model_dir or config.MODEL_DIR)
        if not config.MODEL_DIR.exists():
            raise FileNotFoundError(
                f"No trained model at {config.MODEL_DIR}. "
                "Run:  python ML/train_flan_t5.py  first."
            )
        if torch.cuda.is_available():
            self.device = "cuda"
        elif torch.backends.mps.is_available():
            self.device = "mps"
        else:
            self.device = "cpu"
        self.tokenizer = AutoTokenizer.from_pretrained(model_dir)
        self.model = AutoModelForSeq2SeqLM.from_pretrained(model_dir).to(
            self.device
        )
        self.model.eval()

    @torch.no_grad()
    def answer(self, question: str, max_new_tokens: int = 128) -> str:
        prompt = config.PROMPT_PREFIX + question.strip()
        inputs = self.tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=config.MAX_INPUT_LENGTH,
        ).to(self.device)
        output_ids = self.model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            min_new_tokens=12,            # don't bail out after a word or two
            num_beams=4,
            early_stopping=True,
            # Stop the small model from looping ("a plant with a plant with…"):
            no_repeat_ngram_size=3,       # never repeat any 3-word sequence
            repetition_penalty=1.4,       # penalise reusing tokens
            length_penalty=1.0,
        )
        return self.tokenizer.decode(output_ids[0], skip_special_tokens=True)


def main() -> None:
    bot = AgriChatbot()

    # One-shot mode: question passed as command-line argument.
    if len(sys.argv) > 1:
        question = " ".join(sys.argv[1:])
        print(bot.answer(question))
        return

    # Interactive mode.
    print("AgriPulse chatbot ready. Type a question (or 'quit' to exit).")
    while True:
        try:
            question = input("\nYou: ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if question.lower() in {"quit", "exit", "q"}:
            break
        if question:
            print(f"Bot: {bot.answer(question)}")


if __name__ == "__main__":
    main()
