"""
Model factory: build EfficientNet-B0 or MobileNetV3-Large for transfer
learning, with the classifier head resized to our number of classes.

Both backbones load ImageNet-pretrained weights so training converges fast.
"""

import torch.nn as nn
from torchvision import models

import config


def build_model(arch: str, num_classes: int, pretrained: bool = True):
    """Return a torchvision model with a fresh classifier head.

    arch: "efficientnet_b0" (main model) or "mobilenet_v3" (deployment model).
    """
    if arch not in config.MODEL_DIRS:
        raise ValueError(
            f"Unknown arch '{arch}'. Choose from {list(config.MODEL_DIRS)}."
        )

    if arch == "efficientnet_b0":
        weights = models.EfficientNet_B0_Weights.DEFAULT if pretrained else None
        model = models.efficientnet_b0(weights=weights)
        # classifier = Sequential(Dropout, Linear); swap the final Linear.
        in_features = model.classifier[1].in_features
        model.classifier[1] = nn.Linear(in_features, num_classes)

    else:  # mobilenet_v3
        weights = (
            models.MobileNet_V3_Large_Weights.DEFAULT if pretrained else None
        )
        model = models.mobilenet_v3_large(weights=weights)
        # classifier = Sequential(Linear, Hardswish, Dropout, Linear).
        in_features = model.classifier[3].in_features
        model.classifier[3] = nn.Linear(in_features, num_classes)

    return model
