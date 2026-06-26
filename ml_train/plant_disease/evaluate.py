"""
Optional: evaluate a trained model on the held-out TEST manifest.

    python ML/plant_disease/evaluate.py --model efficientnet_b0
    python ML/plant_disease/evaluate.py --model mobilenet_v3

Reports overall test accuracy and per-class accuracy. Does NOT train.
"""

import argparse
import os

os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")

import torch
from torch.utils.data import DataLoader

import config
from dataset import PlantDiseaseDataset
from predict import PlantDiseaseClassifier


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, choices=list(config.MODEL_DIRS))
    parser.add_argument("--batch-size", type=int, default=config.BATCH_SIZE)
    args = parser.parse_args()

    if not config.TEST_MANIFEST.exists():
        raise FileNotFoundError(
            "Test manifest not found. Run prepare_dataset.py first."
        )

    clf = PlantDiseaseClassifier(args.model)
    model, device = clf.model, clf.device
    class_names = clf.class_names

    test_ds = PlantDiseaseDataset(config.TEST_MANIFEST, train=False)
    loader = DataLoader(test_ds, batch_size=args.batch_size, shuffle=False)
    print(f"Evaluating {args.model} on {len(test_ds):,} test images ...")

    n_classes = len(class_names)
    correct = [0] * n_classes
    total = [0] * n_classes
    overall_correct = 0

    with torch.no_grad():
        for images, labels in loader:
            images = images.to(device)
            preds = model(images).argmax(1).cpu()
            for pred, label in zip(preds, labels):
                total[label] += 1
                if pred == label:
                    correct[label] += 1
                    overall_correct += 1

    print(f"\nOverall test accuracy: {overall_correct / len(test_ds):.4f}\n")
    print("Per-class accuracy:")
    for i, name in enumerate(class_names):
        acc = correct[i] / total[i] if total[i] else 0.0
        print(f"  {name:<45} {acc:.4f}  ({correct[i]}/{total[i]})")


if __name__ == "__main__":
    main()
