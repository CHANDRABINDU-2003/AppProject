"""
Helper to import the existing ML prediction code WITHOUT modifying it.

Problem: each ML package (ML/, ML/plant_disease/, ML/fertilizer/) has its own
top-level `config.py` (and plant_disease also has `dataset.py` / `models.py`).
A plain `import config` would collide between packages.

Solution: load each predict module from its file path with its OWN directory
temporarily on sys.path, after clearing the cached sibling module names. Each
loaded module captures its own `config` object, so later calls keep working even
after another package re-imports `config`.
"""
import importlib.util
import sys
from pathlib import Path

# Generic module names that several ML packages reuse and that must not leak
# between loads.
_SIBLINGS = ("config", "dataset", "models")


def load_module(file_path: Path, unique_name: str):
    """Execute `file_path` as a module named `unique_name` and return it."""
    for name in _SIBLINGS:
        sys.modules.pop(name, None)

    pkg_dir = str(file_path.parent)
    added = pkg_dir not in sys.path
    if added:
        sys.path.insert(0, pkg_dir)
    try:
        spec = importlib.util.spec_from_file_location(unique_name, file_path)
        module = importlib.util.module_from_spec(spec)
        sys.modules[unique_name] = module
        spec.loader.exec_module(module)
        return module
    finally:
        if added:
            sys.path.remove(pkg_dir)
