"""
Step 1: clean the PlantVillage image data ONCE and cache split manifests.

Run whenever the raw images change:

    python ML/plant_disease/prepare_dataset.py

"Cleaning" for images means:
    * scan only the top-level class folders (ignore the nested duplicate copy)
    * skip non-image files (.DS_Store, extension-less junk, etc.)
    * VERIFY every image actually opens & decodes -- drop corrupt files
    * build a stratified train/val/test split

It writes reusable manifests to ML/plant_disease/data/processed/:
    * train.csv, val.csv, test.csv   (columns: filepath,label)
    * class_names.json               (ordered list of class names)

train.py reads these manifests, so the (slow) scan + image verification runs
only once -- never again before training.
"""

import json
import random

from PIL import Image

import config


def discover_classes() -> list[str]:
    """Top-level folders that contain images, excluding the nested duplicate."""
    classes = []
    for d in sorted(config.DATA_ROOT.iterdir()):
        if not d.is_dir() or d.name in config.IGNORE_DIRS:
            continue
        has_image = any(
            f.suffix.lower() in config.VALID_EXTENSIONS for f in d.iterdir()
        )
        if has_image:
            classes.append(d.name)
    return classes


def collect_valid_images(class_name: str) -> list[str]:
    """Return paths of images in a class folder that open & decode cleanly."""
    folder = config.DATA_ROOT / class_name
    valid, corrupt = [], 0
    for f in sorted(folder.iterdir()):
        if f.suffix.lower() not in config.VALID_EXTENSIONS:
            continue
        try:
            # verify() catches truncated/corrupt files without full decode.
            with Image.open(f) as img:
                img.verify()
            valid.append(str(f))
        except Exception:
            corrupt += 1
    if corrupt:
        print(f"    (skipped {corrupt} corrupt/unreadable file(s))")
    return valid


def write_manifest(path, rows) -> None:
    with open(path, "w") as fh:
        fh.write("filepath,label\n")
        for filepath, label in rows:
            # filepaths have no commas in this dataset; quote defensively anyway
            fh.write(f'"{filepath}",{label}\n')


def main() -> None:
    config.ensure_dirs()

    if not config.DATA_ROOT.exists():
        raise FileNotFoundError(f"Image root not found at {config.DATA_ROOT}.")

    classes = discover_classes()
    if not classes:
        raise RuntimeError(f"No class folders with images under {config.DATA_ROOT}")
    print(f"Found {len(classes)} classes:")

    rng = random.Random(config.SEED)
    train_rows, val_rows, test_rows = [], [], []
    total = 0

    for label, cls in enumerate(classes):
        images = collect_valid_images(cls)
        rng.shuffle(images)
        n = len(images)
        n_test = int(n * config.TEST_SPLIT)
        n_val = int(n * config.VAL_SPLIT)
        test = images[:n_test]
        val = images[n_test : n_test + n_val]
        train = images[n_test + n_val :]

        train_rows += [(p, label) for p in train]
        val_rows += [(p, label) for p in val]
        test_rows += [(p, label) for p in test]
        total += n
        print(f"  [{label:2d}] {cls:<45} {n:5d}  "
              f"(train {len(train)}, val {len(val)}, test {len(test)})")

    # Shuffle across classes so batches are mixed.
    rng.shuffle(train_rows)
    rng.shuffle(val_rows)
    rng.shuffle(test_rows)

    write_manifest(config.TRAIN_MANIFEST, train_rows)
    write_manifest(config.VAL_MANIFEST, val_rows)
    write_manifest(config.TEST_MANIFEST, test_rows)
    config.CLASS_NAMES_JSON.write_text(json.dumps(classes, indent=2))

    print(f"\nTotal valid images: {total:,}")
    print("Saved manifests:")
    print(f"  {config.TRAIN_MANIFEST}  ({len(train_rows):,} rows)")
    print(f"  {config.VAL_MANIFEST}  ({len(val_rows):,} rows)")
    print(f"  {config.TEST_MANIFEST}  ({len(test_rows):,} rows)")
    print(f"  {config.CLASS_NAMES_JSON}  ({len(classes)} classes)")
    print("\nDone. Now train:")
    print("  python ML/plant_disease/train.py --model efficientnet_b0")
    print("  python ML/plant_disease/train.py --model mobilenet_v3")


if __name__ == "__main__":
    main()
