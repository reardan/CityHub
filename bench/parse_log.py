#!/usr/bin/env python3
"""Parse CHUB STAT / CUT / FAIL / PATH lines from an OpenTTD script log."""

from __future__ import annotations

import argparse
import csv
import re
from collections import Counter, defaultdict
from pathlib import Path

STAT_RE = re.compile(r"CHUB STAT\s+(.+)$")
CUT_RE = re.compile(r"CHUB CUT\s+")
FAIL_RE = re.compile(r"CHUB FAIL\s+(.+)$")
PATH_RE = re.compile(r"CHUB PATH\s+(.+)$")
PAIR_RE = re.compile(r"([A-Za-z0-9_]+)=(\S+)")


def parse_pairs(payload: str) -> dict[str, str]:
    """Parse `k=v` tokens from a CityHub log payload."""
    return {key: value for key, value in PAIR_RE.findall(payload)}


def _int(value: str | None, default: int = 0) -> int:
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def parse_log(text: str) -> dict[str, object]:
    """Collect STAT rows, FAIL reasons, PATH outcomes, and CUT presence."""
    stats: list[dict[str, str]] = []
    fails: list[dict[str, str]] = []
    paths: list[dict[str, str]] = []
    cut = False
    for raw in text.splitlines():
        line = raw.strip()
        stat_match = STAT_RE.search(line)
        if stat_match:
            stats.append(parse_pairs(stat_match.group(1)))
            continue
        fail_match = FAIL_RE.search(line)
        if fail_match:
            fails.append(parse_pairs(fail_match.group(1)))
            continue
        path_match = PATH_RE.search(line)
        if path_match:
            paths.append(parse_pairs(path_match.group(1)))
            continue
        if CUT_RE.search(line):
            cut = True
    return {"stats": stats, "fails": fails, "paths": paths, "cut": cut}


def latest_by_company(stats: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    """Return the last STAT row for each company name."""
    latest: dict[str, dict[str, str]] = {}
    for row in stats:
        name = row.get("name", "unknown")
        latest[name] = row
    return latest


def year_leaders(stats: list[dict[str, str]], years: tuple[int, ...]) -> dict[int, str]:
    """Name the highest-value company whose STAT date year matches each cut year."""
    by_year: dict[int, dict[str, int]] = defaultdict(dict)
    for row in stats:
        stamp = row.get("y", "")
        if len(stamp) < 4:
            continue
        try:
            year = int(stamp[:4])
        except ValueError:
            continue
        name = row.get("name", "unknown")
        by_year[year][name] = _int(row.get("val"))
    leaders: dict[int, str] = {}
    for year in years:
        if year not in by_year:
            continue
        leaders[year] = max(by_year[year], key=by_year[year].get)
    return leaders


def summarize(parsed: dict[str, object]) -> str:
    """Build a short human summary of one match log."""
    stats = parsed["stats"]
    fails = parsed["fails"]
    paths = parsed["paths"]
    lines = [f"STAT rows={len(stats)} CUT={int(bool(parsed['cut']))}"]
    latest = latest_by_company(stats)
    for name, row in sorted(latest.items()):
        lines.append(
            f"  {name} val={row.get('val', '?')} income={row.get('income', '?')} "
            f"rating={row.get('rating', '?')}"
        )
    leaders = year_leaders(stats, (1971, 1972, 1975))
    if leaders:
        bits = [f"y{year}={name}" for year, name in sorted(leaders.items())]
        lines.append("lead " + " ".join(bits))
    reasons = Counter(row.get("reason", "unknown") for row in fails)
    if reasons:
        lines.append("FAIL " + " ".join(f"{k}={v}" for k, v in reasons.most_common()))
    if paths:
        ok = sum(1 for row in paths if row.get("ok") == "1")
        lines.append(f"PATH ok={ok}/{len(paths)}")
    return "\n".join(lines)


def write_csv(stats: list[dict[str, str]], path: Path) -> None:
    """Write STAT rows to CSV."""
    fields = [
        "y",
        "t",
        "self",
        "id",
        "name",
        "val",
        "income",
        "exp",
        "rating",
        "cargo",
        "bal",
        "loan",
        "tveh",
        "r",
        "p",
        "s",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in stats:
            out = dict(row)
            out["tveh"] = row.get("t", "")
            writer.writerow(out)


def main() -> None:
    parser = argparse.ArgumentParser(description="Parse CityHub / CityHubBench logs")
    parser.add_argument("log", type=Path)
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()
    parsed = parse_log(args.log.read_text(encoding="utf-8", errors="replace"))
    if args.out is not None:
        write_csv(parsed["stats"], args.out)
    print(summarize(parsed))


if __name__ == "__main__":
    main()
