"""
PyTorch Dataset + transforms shared by training and inference.

Reads the manifest CSVs produced by prepare_dataset.py (filepath,label).
"""

import csv

import torch
from PIL import Image
from torch.utils.data import Dataset
from torchvision import transforms

import config


def build_transforms(train: bool):
    """Augment for training; just resize/normalise for val/test/inference."""
    if train:
        return transforms.Compose([
            transforms.RandomResizedCrop(config.IMAGE_SIZE, scale=(0.7, 1.0)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(20),
            transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
            transforms.ToTensor(),
            transforms.Normalize(config.NORM_MEAN, config.NORM_STD),
        ])
    return transforms.Compose([
        transforms.Resize(int(config.IMAGE_SIZE * 1.15)),
        transforms.CenterCrop(config.IMAGE_SIZE),
        transforms.ToTensor(),
        transforms.Normalize(config.NORM_MEAN, config.NORM_STD),
    ])


class PlantDiseaseDataset(Dataset):
    """Loads (image_tensor, label) pairs from a manifest CSV."""

    def __init__(self, manifest_path, train: bool):
        self.samples = []
        with open(manifest_path, newline="") as fh:
            for row in csv.DictReader(fh):
                self.samples.append((row["filepath"], int(row["label"])))
        self.transform = build_transforms(train=train)

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, idx):
        filepath, label = self.samples[idx]
        # convert("RGB") guards against grayscale / RGBA / CMYK images.
        image = Image.open(filepath).convert("RGB")
        return self.transform(image), label

    def labels(self) -> list[int]:
        return [label for _, label in self.samples]


def compute_class_weights(num_classes: int, labels: list[int]) -> torch.Tensor:
    """Inverse-frequency weights for CrossEntropyLoss (handles imbalance)."""
    counts = [0] * num_classes
    for label in labels:
        counts[label] += 1
    total = sum(counts)
    weights = [total / (num_classes * c) if c else 0.0 for c in counts]
    return torch.tensor(weights, dtype=torch.float32)
