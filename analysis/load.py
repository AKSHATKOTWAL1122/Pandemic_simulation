"""Load spec 14 run folders.

    run = load_run("output/baseline/run_0")
    runs = load_experiment("output/baseline")   # every run_<i>, sorted by i

A Run reads config.json, seir.csv, infections.csv and npcs.csv at once; contacts.csv
(can be millions of rows) is read on first access of `run.contacts`.
"""
from __future__ import annotations

import json
import re
from functools import cached_property
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MAP = ROOT / "data" / "map.png"
DEFAULT_BUILDINGS = ROOT / "data" / "buildings.json"
FILES = ("config.json", "seir.csv", "contacts.csv", "infections.csv", "npcs.csv")
SECONDS_PER_DAY = 86400


def _res_path(value: str | None, default: Path) -> Path:
    """Turn a config path (res://..., relative or absolute) into a local path."""
    if not value:
        return default
    p = Path(value[len("res://"):]) if value.startswith("res://") else Path(value)
    if not p.is_absolute():
        p = ROOT / p
    return p if p.exists() else default


class Run:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        missing = [f for f in FILES if not (self.path / f).exists()]
        if missing:
            raise FileNotFoundError(f"{self.path}: missing {', '.join(missing)}")
        self.config: dict = json.loads((self.path / "config.json").read_text())
        self.seir = pd.read_csv(self.path / "seir.csv")
        self.infections = pd.read_csv(self.path / "infections.csv")
        self.npcs = pd.read_csv(self.path / "npcs.csv")

    # --- identity
    @property
    def name(self) -> str:
        return self.path.name

    @property
    def experiment_dir(self) -> Path:
        return self.path.parent

    @property
    def experiment(self) -> str:
        return self.config.get("name") or self.experiment_dir.name

    @property
    def plots_dir(self) -> Path:
        d = self.experiment_dir / "plots"
        d.mkdir(parents=True, exist_ok=True)
        return d

    # --- config-derived numbers
    @property
    def tick_seconds(self) -> float:
        return float(self.config.get("tick_seconds", 60))

    @property
    def ticks_per_day(self) -> float:
        return SECONDS_PER_DAY / self.tick_seconds

    @property
    def population(self) -> int:
        return len(self.npcs)

    @property
    def seed(self):
        return self.config.get("seed")

    @property
    def immune_share(self) -> float:
        if "immune_share" in self.config:
            return float(self.config["immune_share"])
        return float(self.npcs["immune_forever"].mean())

    @property
    def map_path(self) -> Path:
        return _res_path(self.config.get("map_path"), DEFAULT_MAP)

    @property
    def buildings_path(self) -> Path:
        return _res_path(self.config.get("buildings_path"), DEFAULT_BUILDINGS)

    # --- data
    @cached_property
    def contacts(self) -> pd.DataFrame:
        return pd.read_csv(self.path / "contacts.csv")

    def days(self, ticks) -> np.ndarray:
        """Ticks -> fractional days since Monday 00:00."""
        return np.asarray(ticks, dtype=float) / self.ticks_per_day

    def hour_of_day(self, ticks) -> np.ndarray:
        """Ticks -> fractional hour of the day, 0 <= h < 24."""
        sec = np.asarray(ticks, dtype=float) * self.tick_seconds
        return (sec % SECONDS_PER_DAY) / 3600.0

    def seir_pct(self) -> pd.DataFrame:
        """seir.csv with a `days` column and S/E/I/R/immune_forever as % of population."""
        df = pd.DataFrame({"days": self.days(self.seir["tick"])})
        total = self.seir[["S", "E", "I", "R"]].sum(axis=1).to_numpy(dtype=float)
        for c in ("S", "E", "I", "R", "immune_forever"):
            df[c] = 100.0 * self.seir[c].to_numpy(dtype=float) / total
        return df

    def ever_infected_pct(self) -> float:
        return 100.0 * float((self.npcs["first_infected_tick"] >= 0).mean())

    def __repr__(self) -> str:
        return f"Run({self.path})"


def _run_index(p: Path) -> tuple[int, str]:
    m = re.fullmatch(r"run_(\d+)", p.name)
    return (int(m.group(1)) if m else 10**9, p.name)


def load_run(path: str | Path) -> Run:
    return Run(path)


def load_experiment(path: str | Path) -> list[Run]:
    """All run_* folders of an experiment folder (sorted by index). A run folder itself
    is accepted too and gives a one-element list."""
    path = Path(path)
    if (path / "config.json").exists():
        return [Run(path)]
    runs = sorted((p for p in path.glob("run_*") if (p / "config.json").exists()), key=_run_index)
    if not runs:
        raise FileNotFoundError(f"{path}: no run_*/ folders with config.json")
    return [Run(p) for p in runs]


def experiment_plots_dir(path: str | Path) -> Path:
    """`<experiment>/plots` for an experiment folder (or a run folder's experiment)."""
    path = Path(path)
    exp = path.parent if (path / "config.json").exists() else path
    d = exp / "plots"
    d.mkdir(parents=True, exist_ok=True)
    return d


def experiment_name(path: str | Path) -> str:
    path = Path(path)
    return path.parent.name if (path / "config.json").exists() else path.name
