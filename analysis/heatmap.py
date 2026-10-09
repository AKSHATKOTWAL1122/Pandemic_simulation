#!/usr/bin/env python3
"""Heatmap of contact or infection events of one run, over data/map.png.

Coordinates: event x, y are in tiles (floats); the event is on tile (floor(x), floor(y)).
map.png has one pixel per tile, pixel (col x, row y) = tile (x, y), y pointing down.
Both the map and the heat layer are drawn with imshow(origin="upper",
extent=(0, 256, 256, 0)), so data coordinate (x, y) is the same tile in both.

The KDE is a binned Gaussian KDE: events are counted per tile (256 x 256 histogram)
and smoothed with a Gaussian of --sigma tiles. Hotspots are the 5 tiles with the
most raw events, at least --min-sep tiles apart (printed with the building they belong
to and marked on the plot).

Usage:
  python analysis/heatmap.py output/baseline/run_0 --events contacts --hours 0-24
  python analysis/heatmap.py output/baseline/run_0 --events infections --hours 18-23
Hours are hour-of-day, [a, b), across all days; a > b wraps midnight (e.g. 22-6).
Default PNG: <experiment>/plots/heatmap_<events>_<run>_h<a>-<b>.png
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib.image as mpimg
import numpy as np
from matplotlib.colors import LinearSegmentedColormap
from scipy import ndimage

from common import plt, save
from load import load_run

SIZE = 256
EXTENT = (0, SIZE, SIZE, 0)  # left, right, bottom, top -> y grows downwards like the map
HEAT_CMAP = LinearSegmentedColormap.from_list(
    "heat", [(0.0, (1.0, 0.85, 0.3, 0.0)), (0.15, (1.0, 0.75, 0.2, 0.55)),
             (0.5, (0.93, 0.35, 0.1, 0.8)), (1.0, (0.6, 0.0, 0.1, 0.95))])


def parse_hours(text: str) -> tuple[float, float]:
    a, b = (float(v) for v in text.split("-"))
    if not (0 <= a <= 24 and 0 <= b <= 24):
        raise argparse.ArgumentTypeError("hours must be within 0-24")
    return a, b


def hour_mask(hours: np.ndarray, a: float, b: float) -> np.ndarray:
    if a == b or (a == 0 and b == 24):
        return np.ones(len(hours), dtype=bool)
    if a < b:
        return (hours >= a) & (hours < b)
    return (hours >= a) | (hours < b)  # wraps midnight


def tile_counts(x: np.ndarray, y: np.ndarray, size: int = SIZE) -> np.ndarray:
    """Events per tile as array[row = y, col = x]."""
    tx = np.clip(np.floor(np.asarray(x, dtype=float)).astype(int), 0, size - 1)
    ty = np.clip(np.floor(np.asarray(y, dtype=float)).astype(int), 0, size - 1)
    counts = np.zeros((size, size), dtype=float)
    np.add.at(counts, (ty, tx), 1.0)
    return counts


def density(x: np.ndarray, y: np.ndarray, sigma: float = 2.0) -> np.ndarray:
    """Binned Gaussian KDE on the tile grid, array[row = y, col = x], sums to the event count."""
    return ndimage.gaussian_filter(tile_counts(x, y), sigma=sigma, mode="constant")


def image_index(extent, shape, x: float, y: float, origin: str = "upper") -> tuple[int, int]:
    """(row, col) of the array element that imshow(extent, origin) draws at data (x, y)."""
    left, right, bottom, top = extent
    rows, cols = shape[:2]
    col = int(np.floor((x - left) / (right - left) * cols))
    if origin == "upper":
        row = int(np.floor((y - top) / (bottom - top) * rows))
    else:
        row = int(np.floor((y - bottom) / (top - bottom) * rows))
    return row, col


def building_grid(buildings_path: Path) -> tuple[np.ndarray, dict]:
    data = json.loads(Path(buildings_path).read_text())
    grid = np.full((SIZE, SIZE), -1, dtype=int)
    info = {}
    for b in data["buildings"]:
        x, y, w, h = b["rect"]
        grid[y:y + h, x:x + w] = b["id"]
        info[b["id"]] = "+".join(b["purposes"])
    return grid, info


def hotspots(counts: np.ndarray, k: int = 5, min_sep: int = 8) -> list[tuple[int, int, int]]:
    """Top-k tiles as (x, y, events), most events first, ties in (y, x) order.
    A tile closer than `min_sep` tiles (Chebyshev) to an already chosen one is skipped,
    so the 5 hotspots are 5 different places; min_sep = 0 gives the plain top 5 tiles."""
    flat = counts.ravel()
    picked: list[tuple[int, int, int]] = []
    for i in np.lexsort((np.arange(flat.size), -flat)):
        if flat[i] <= 0 or len(picked) == k:
            break
        x, y = int(i % SIZE), int(i // SIZE)
        if all(max(abs(x - px), abs(y - py)) >= min_sep for px, py, _ in picked):
            picked.append((x, y, int(flat[i])))
    return picked


def plot_heatmap(map_img: np.ndarray, x: np.ndarray, y: np.ndarray, sigma: float = 2.0,
                 title: str = "", spots: list | None = None):
    """Returns (fig, ax, map_im, heat_im, dens). Both images share EXTENT/origin."""
    dens = density(x, y, sigma)
    fig, ax = plt.subplots(figsize=(9, 9))
    ax.grid(False)
    map_im = ax.imshow(map_img, extent=EXTENT, origin="upper", interpolation="nearest",
                       alpha=0.55)
    vmax = float(dens.max()) if dens.max() > 0 else 1.0
    heat_im = ax.imshow(dens, extent=EXTENT, origin="upper", interpolation="bilinear",
                        cmap=HEAT_CMAP, vmin=0, vmax=vmax)
    for n, (tx, ty, _) in enumerate(spots or [], start=1):
        ax.plot(tx + 0.5, ty + 0.5, "o", ms=14, mfc="none", mec="#111111", mew=1.3)
        ax.annotate(str(n), (tx + 0.5, ty + 0.5), xytext=(9, -9), textcoords="offset points",
                    fontsize=9, fontweight="bold", color="#111111")
    ax.set_xlim(0, SIZE)
    ax.set_ylim(SIZE, 0)
    ax.set_xlabel("x (tile)")
    ax.set_ylabel("y (tile)")
    ax.set_title(title)
    cb = fig.colorbar(heat_im, ax=ax, fraction=0.035, pad=0.02)
    cb.set_label("Events per tile (Gaussian-smoothed)")
    return fig, ax, map_im, heat_im, dens


def main(argv=None) -> Path:
    ap = argparse.ArgumentParser(description="KDE heatmap of events over the map")
    ap.add_argument("run")
    ap.add_argument("--events", choices=("contacts", "infections"), default="contacts")
    ap.add_argument("--hours", type=parse_hours, default=(0.0, 24.0),
                    help="hour-of-day window a-b, e.g. 0-24, 18-23, 22-6")
    ap.add_argument("--sigma", type=float, default=2.0, help="KDE bandwidth in tiles")
    ap.add_argument("--min-sep", type=int, default=8,
                    help="hotspots closer than this many tiles count as one (0 = off)")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    run = load_run(args.run)
    ev = run.contacts if args.events == "contacts" else run.infections
    a, b = args.hours
    ev = ev[hour_mask(run.hour_of_day(ev["tick"]), a, b)]
    x, y = ev["x"].to_numpy(dtype=float), ev["y"].to_numpy(dtype=float)

    counts = tile_counts(x, y)
    spots = hotspots(counts, 5, args.min_sep)
    bgrid, binfo = building_grid(run.buildings_path)
    print(f"{len(ev)} {args.events} events, hours {a:g}-{b:g}. Top 5 hotspot tiles:")
    for n, (tx, ty, c) in enumerate(spots, start=1):
        bid = int(bgrid[ty, tx])
        where = f"building {bid} ({binfo[bid]})" if bid >= 0 else "outside"
        print(f"  {n}. tile ({tx}, {ty}): {c} events — {where}")

    map_img = mpimg.imread(run.map_path)
    title = (f"{args.events.capitalize()} — {run.experiment} / {run.name}, "
             f"hours {a:g}–{b:g} ({len(ev)} events)")
    fig, *_ = plot_heatmap(map_img, x, y, args.sigma, title, spots)
    tag = f"{args.events}_{run.name}_h{a:g}-{b:g}"
    out = Path(args.out) if args.out else run.plots_dir / f"heatmap_{tag}.png"
    return save(fig, out)


if __name__ == "__main__":
    main()
