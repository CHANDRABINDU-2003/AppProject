# Plant Disease Classification — EfficientNet-B0 + MobileNetV3

Trains image classifiers on the **PlantVillage** leaf-disease dataset
(in `archive/PlantVillage/`, 15 classes / 20,638 images) using transfer
learning, and saves the trained weights for reuse.

Two models from the same data:

| Model | Role | Why |
|-------|------|-----|
| **EfficientNet-B0** | main model | higher accuracy |
| **MobileNetV3-Large** | deployment model | small & fast for mobile/edge |

Pipeline stages — clean & train **once**, then reuse the cached manifests and
saved weights:

```
prepare_dataset.py  ->  train.py  ->  predict.py / evaluate.py
   (clean once)         (train once)    (load & use, no retrain)
```

## Folder layout

```
ML/plant_disease/
├── config.py            # paths, image size, hyper-parameters
├── prepare_dataset.py   # Step 1: verify images -> cached split manifests
├── dataset.py           # PyTorch Dataset + train/val transforms
├── models.py            # build EfficientNet-B0 / MobileNetV3 heads
├── train.py             # Step 2: train one model -> saved weights
├── predict.py           # Step 3: classify an image (no retrain)
├── evaluate.py          # optional: test-set accuracy per class
├── requirements.txt
├── data/processed/      # cached manifests (created by step 1) ✅ already built
│   ├── train.csv  val.csv  test.csv
│   └── class_names.json
└── models/              # saved weights (created by step 2)
    ├── efficientnet_b0/best_model.pt
    └── mobilenet_v3/best_model.pt
```

## Important: Python version

`torch` has **no Python 3.14 wheels yet** (your system Python is 3.14). Create a
Python 3.10–3.12 virtual environment first:

```bash
# install python 3.12 if needed:  brew install python@3.12
python3.12 -m venv ML/plant_disease/.venv
source ML/plant_disease/.venv/bin/activate
pip install -r ML/plant_disease/requirements.txt
```

On Apple Silicon, PyTorch automatically uses the **MPS** GPU; otherwise it falls
back to CPU (which is slow for 20k images — expect a long run).

## Step-by-step

```bash
# 1. Clean / verify images and build split manifests.
#    (Already run once — re-run only if the images change.)
python ML/plant_disease/prepare_dataset.py

# 2. Train each model. Weights saved to models/<arch>/best_model.pt
python ML/plant_disease/train.py --model efficientnet_b0     # main model
python ML/plant_disease/train.py --model mobilenet_v3        # deployment model

#    Useful flags:
#    --epochs 8 --batch-size 32 --lr 1e-3

# 3a. Predict on a single leaf image (loads saved weights, no retrain).
python ML/plant_disease/predict.py --model efficientnet_b0 path/to/leaf.jpg

# 3b. Measure accuracy on the held-out test set.
python ML/plant_disease/evaluate.py --model efficientnet_b0
```

## What gets stored (so you don't retrain)

- **Cached cleaned data** — `data/processed/*.csv` + `class_names.json`. These
  list every verified image and its split, so the slow image-verification scan
  runs only once.
- **Trained model** — `models/<arch>/best_model.pt` holds the weights, the
  architecture name, the class names, and the normalisation stats. `predict.py`
  / `evaluate.py` load this file and never retrain. The best (highest val
  accuracy) epoch is saved automatically.

## How the cleaning works

`prepare_dataset.py`:
- scans only the top-level class folders and **ignores the nested duplicate**
  `archive/PlantVillage/PlantVillage/`;
- skips non-image files (`.DS_Store`, extension-less junk);
- opens and verifies every image, dropping any corrupt/truncated files;
- builds a reproducible stratified 70/15/15 train/val/test split.

## Use from other code

```python
from ML.plant_disease.predict import PlantDiseaseClassifier

clf = PlantDiseaseClassifier("efficientnet_b0")   # loads weights once
label, prob = clf.predict("some_leaf.jpg")        # -> ("Tomato_Late_blight", 0.97)
print(clf.predict("some_leaf.jpg", top_k=3))      # top-3 with probabilities
```

## Tuning

Edit `config.py`:
- `NUM_EPOCHS`, `BATCH_SIZE`, `LEARNING_RATE`, `WEIGHT_DECAY` — training knobs.
- `USE_CLASS_WEIGHTS` — inverse-frequency loss weighting (on by default) to
  handle class imbalance (e.g. `Potato___healthy` has only 152 images).
- `VAL_SPLIT` / `TEST_SPLIT` — split ratios.
