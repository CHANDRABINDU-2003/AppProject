"""
Step 3: load a SAVED model and classify a leaf image. NO retraining.

    python ML/plant_disease/predict.py --model efficientnet_b0 path/to/leaf.jpg
    python ML/plant_disease/predict.py --model mobilenet_v3   path/to/leaf.jpg

Or import it (e.g. from the FastAPI service):
    from ML.plant_disease.predict import PlantDiseaseClassifier
    clf = PlantDiseaseClassifier("efficientnet_b0")   # loads weights once
    print(clf.predict("leaf.jpg"))                    # -> ("Tomato_Late_blight", 0.97)
"""

import argparse
import os

os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")

import torch
from PIL import Image

import config
from dataset import build_transforms
from models import build_model


class PlantDiseaseClassifier:
    """Loads a saved checkpoint once and serves predictions."""

    def __init__(self, arch: str, weights_path=None):
        weights_path = weights_path or (
            config.MODEL_DIRS[arch] / config.WEIGHTS_FILENAME
        )
        if not weights_path.exists():
            raise FileNotFoundError(
                f"No trained model at {weights_path}. Train it first:  "
                f"python ML/plant_disease/train.py --model {arch}"
            )
        if torch.cuda.is_available():
            self.device = "cuda"
        elif torch.backends.mps.is_available():
            self.device = "mps"
        else:
            self.device = "cpu"

        ckpt = torch.load(weights_path, map_location=self.device)
        self.class_names = ckpt["class_names"]
        self.model = build_model(
            ckpt["arch"], len(self.class_names), pretrained=False
        )
        self.model.load_state_dict(ckpt["model_state"])
        self.model.to(self.device).eval()
        self.transform = build_transforms(train=False)

    @torch.no_grad()
    def predict(self, image_path, top_k: int = 1):
        image = Image.open(image_path).convert("RGB")
        x = self.transform(image).unsqueeze(0).to(self.device)
        probs = torch.softmax(self.model(x), dim=1)[0]
        top_p, top_i = probs.topk(min(top_k, len(self.class_names)))
        results = [
            (self.class_names[i], round(float(p), 4))
            for p, i in zip(top_p, top_i)
        ]
        return results[0] if top_k == 1 else results


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, choices=list(config.MODEL_DIRS))
    parser.add_argument("image", help="path to a leaf image")
    parser.add_argument("--top-k", type=int, default=3)
    args = parser.parse_args()

    clf = PlantDiseaseClassifier(args.model)
    results = clf.predict(args.image, top_k=args.top_k)
    print(f"Predictions for {args.image} ({args.model}):")
    for name, prob in results:
        print(f"  {name:<45} {prob:.4f}")


if __name__ == "__main__":
    main()
