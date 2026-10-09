"""Shared plotting helpers: Agg backend, spec 11 state colours, mean + 10-90 % bands."""
from __future__ import annotations

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))

# Spec 11 state colours.
COLORS = {"S": "#7A8CA5", "E": "#F2C14E", "I": "#D7263D", "R": "#3BB273",
          "immune_forever": "#2E86AB"}
LABELS = {"S": "Susceptible", "E": "Exposed", "I": "Infected", "R": "Recovered",
          "immune_forever": "Immune forever"}
INK = "#333333"
MUTED = "#777777"

plt.rcParams.update({
    "figure.dpi": 110,
    "savefig.dpi": 130,
    "axes.edgecolor": "#BBBBBB",
    "axes.labelcolor": INK,
    "axes.titlesize": 12,
    "axes.titleweight": "bold",
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.color": "#E6E6E6",
    "grid.linewidth": 0.8,
    "xtick.color": MUTED,
    "ytick.color": MUTED,
    "legend.frameon": False,
    "lines.linewidth": 2.0,
})


def resample(days: np.ndarray, values: np.ndarray, grid: np.ndarray) -> np.ndarray:
    """Step-hold resample of one run's per-tick series onto a common day grid."""
    idx = np.searchsorted(days, grid, side="right") - 1
    idx = np.clip(idx, 0, len(values) - 1)
    out = values[idx].astype(float)
    out[grid > days[-1] + 1e-9] = np.nan
    return out


def stack_runs(runs, column: str, grid: np.ndarray | None = None):
    """(grid, matrix runs x grid) of `column` in % of population. Grid = hourly by default."""
    frames = [r.seir_pct() for r in runs]
    if grid is None:
        max_day = max(f["days"].iloc[-1] for f in frames)
        step = 1.0 / 24.0
        grid = np.arange(0.0, max_day + 1e-9, step)
    m = np.vstack([resample(f["days"].to_numpy(), f[column].to_numpy(), grid) for f in frames])
    return grid, m


def band(ax, x, matrix, color, label, alpha=0.2, lw=2.0):
    """Mean line + 10-90 % band (just the line for one run)."""
    mean = np.nanmean(matrix, axis=0)
    if matrix.shape[0] > 1:
        lo, hi = np.nanpercentile(matrix, [10, 90], axis=0)
        ax.fill_between(x, lo, hi, color=color, alpha=alpha, linewidth=0)
    ax.plot(x, mean, color=color, lw=lw, label=label)
    return mean


def runs_note(runs) -> str:
    n = len(runs)
    return f"{n} run" if n == 1 else f"{n} runs · line = mean, band = 10–90 %"


def titled(ax, title: str, note: str = "") -> None:
    """Bold title with a small grey note line centred under it."""
    ax.set_title(title, pad=20 if note else 6)
    if note:
        ax.text(0.5, 1.012, note, transform=ax.transAxes, ha="center", va="bottom",
                fontsize=9, color=MUTED)


def day_axis(ax, max_day: float) -> None:
    ax.set_xlabel("Day")
    ax.set_xlim(0, max_day)


def pct_axis(ax, top: float = 100.0) -> None:
    ax.set_ylabel("% of population")
    ax.set_ylim(0, top)


def save(fig, path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"saved {path}")
    return path


def spread(values) -> str:
    """'mean ± sd (10–90 %: lo–hi)' for a list of numbers."""
    v = np.asarray(values, dtype=float)
    if len(v) == 0:
        return "n/a"
    sd = v.std(ddof=1) if len(v) > 1 else 0.0
    lo, hi = np.percentile(v, [10, 90])
    return f"{v.mean():.1f} ± {sd:.1f} (10–90 %: {lo:.1f}–{hi:.1f})"
