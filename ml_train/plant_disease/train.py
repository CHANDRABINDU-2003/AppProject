"""
Step 2: train an image classifier and SAVE it.

Run AFTER prepare_dataset.py. Train each model separately:

    python ML/plant_disease/train.py --model efficientnet_b0    # main model
    python ML/plant_disease/train.py --model mobilenet_v3       # deployment

Saves the best (highest val-accuracy) checkpoint to
ML/plant_disease/models/<arch>/best_model.pt, containing:
    * model_state  -> the trained weights
    * arch, class_names, image_size  -> everything predict.py needs

Because the weights are saved to disk, you train ONCE. predict.py loads the
checkpoint and never retrains.
"""

import argparse
import json
import os

os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")

import torch
import torch.nn as nn
from torch.utils.data import DataLoader

import config
from dataset import PlantDiseaseDataset, compute_class_weights
from models import build_model


def pick_device() -> str:
    if torch.cuda.is_available():
        return "cuda"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def run_epoch(model, loader, criterion, optimizer, device, train: bool):
    model.train() if train else model.eval()
    total_loss, correct, seen = 0.0, 0, 0
    torch.set_grad_enabled(train)
    for images, labels in loader:
        images, labels = images.to(device), labels.to(device)
        if train:
            optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        if train:
            loss.backward()
            optimizer.step()
        total_loss += loss.item() * images.size(0)
        correct += (outputs.argmax(1) == labels).sum().item()
        seen += images.size(0)
    torch.set_grad_enabled(True)
    return total_loss / seen, correct / seen


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--model", required=True, choices=list(config.MODEL_DIRS),
        help="efficientnet_b0 (main) or mobilenet_v3 (deployment)",
    )
    parser.add_argument("--epochs", type=int, default=config.NUM_EPOCHS)
    parser.add_argument("--batch-size", type=int, default=config.BATCH_SIZE)
    parser.add_argument("--lr", type=float, default=config.LEARNING_RATE)
    args = parser.parse_args()

    config.ensure_dirs()
    if not config.TRAIN_MANIFEST.exists():
        raise FileNotFoundError(
            "Manifests not found. Run:  "
            "python ML/plant_disease/prepare_dataset.py  first."
        )

    class_names = json.loads(config.CLASS_NAMES_JSON.read_text())
    num_classes = len(class_names)
    device = pick_device()
    print(f"Device: {device} | Model: {args.model} | Classes: {num_classes}")

    train_ds = PlantDiseaseDataset(config.TRAIN_MANIFEST, train=True)
    val_ds = PlantDiseaseDataset(config.VAL_MANIFEST, train=False)
    print(f"Train: {len(train_ds):,}  Val: {len(val_ds):,}")

    # pin_memory only helps on CUDA; workers=0 is safest on macOS/MPS.
    pin = device == "cuda"
    workers = config.NUM_WORKERS if device == "cuda" else 0
    train_loader = DataLoader(
        train_ds, batch_size=args.batch_size, shuffle=True,
        num_workers=workers, pin_memory=pin,
    )
    val_loader = DataLoader(
        val_ds, batch_size=args.batch_size, shuffle=False,
        num_workers=workers, pin_memory=pin,
    )

    model = build_model(args.model, num_classes, pretrained=True).to(device)

    if config.USE_CLASS_WEIGHTS:
        weights = compute_class_weights(num_classes, train_ds.labels()).to(device)
        criterion = nn.CrossEntropyLoss(weight=weights)
    else:
        criterion = nn.CrossEntropyLoss()

    optimizer = torch.optim.AdamW(
        model.parameters(), lr=args.lr, weight_decay=config.WEIGHT_DECAY
    )
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer, T_max=args.epochs
    )

    out_dir = config.MODEL_DIRS[args.model]
    out_dir.mkdir(parents=True, exist_ok=True)
    weights_path = out_dir / config.WEIGHTS_FILENAME

    best_val_acc = 0.0
    history = []
    for epoch in range(1, args.epochs + 1):
        tr_loss, tr_acc = run_epoch(
            model, train_loader, criterion, optimizer, device, train=True
        )
        va_loss, va_acc = run_epoch(
            model, val_loader, criterion, optimizer, device, train=False
        )
        scheduler.step()
        print(f"Epoch {epoch:2d}/{args.epochs}  "
              f"train_loss {tr_loss:.4f} acc {tr_acc:.4f}  |  "
              f"val_loss {va_loss:.4f} acc {va_acc:.4f}")
        history.append({"epoch": epoch, "train_acc": round(tr_acc, 4),
                        "val_acc": round(va_acc, 4)})

        if va_acc > best_val_acc:
            best_val_acc = va_acc
            torch.save({
                "arch": args.model,
                "model_state": model.state_dict(),
                "class_names": class_names,
                "image_size": config.IMAGE_SIZE,
                "norm_mean": config.NORM_MEAN,
                "norm_std": config.NORM_STD,
            }, weights_path)
            print(f"  ^ saved new best to {weights_path} (val_acc {va_acc:.4f})")

    (out_dir / config.METRICS_FILENAME).write_text(json.dumps({
        "arch": args.model,
        "best_val_acc": round(best_val_acc, 4),
        "epochs": args.epochs,
        "history": history,
    }, indent=2))

    print(f"\nDone. Best val accuracy: {best_val_acc:.4f}")
    print(f"Saved model to {weights_path}")
    print(f"Evaluate on the held-out test set:  "
          f"python ML/plant_disease/evaluate.py --model {args.model}")


if __name__ == "__main__":
    main()
