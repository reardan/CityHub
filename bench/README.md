# CityHub bench harness

Dedicated OpenTTD matches for CityHub vs AAAHogEx (and a third AI if present).
Logs are the source of truth: every `CHUB STAT` / `CHUB CUT` / `CHUB FAIL` /
`CHUB PATH` line is parseable.

## Layout

- `openttd-bench.cfg` — 256×256 temperate, start 1970, CityHub + AAAHogEx
- `run_match.sh` — stage AI/GS symlinks, run headless, parse stderr
- `parse_log.py` — STAT CSV + FAIL/PATH summary
- `gamescript/` — `CityHubBench` Game Script scorekeeper

## Reproduce a 2-year match

From this repo, with OpenTTD built at `../OpenTTD/build/openttd`:

```bash
SEED=12345 YEARS=2 OPPONENT=AAAHogEx ./bench/run_match.sh
```

Artifacts land in `bench/out/`:

- `cityhub-vs-AAAHogEx-2yr-12345.log`
- `cityhub-vs-AAAHogEx-2yr-12345.csv`

The runner uses `-g -snull -mnull -vnull:ticks=N -d script=4` so Info-level
script logs appear on stderr (captured into the `.log` file). Default year
length is `years * 366 + 120` days at 74 ticks/day.

Optional dedicated-server form from the plan (slower, needs a client or
`-vnull` equivalent):

```bash
openttd -D -x -c bench/openttd-bench.cfg -G 12345 -d script=4
```

## Seeds

Starter benches: `12345`, `22222`, `33333` on 256×256 (`map_x=8`), start 1970.

```bash
for SEED in 12345 22222 33333; do
  SEED=$SEED YEARS=2 OPPONENT=AAAHogEx ./bench/run_match.sh
done
```

Five-year long-term:

```bash
SEED=12345 YEARS=5 OPPONENT=AAAHogEx ./bench/run_match.sh
```

## Observed starter benches (1970, 256×256 temperate)

Two improvement rounds from smoke/FAIL data: bus placement no longer
retries one tile forever; starter airports are capped and cheaper when
cash is tight; rail rollback uses `DemolishTile` (API 14 has no
`RemoveRailDepot`); long-term cloning stops when loan headroom is gone.

2-year vs AAAHogEx (GS cut values):

| Seed | CityHub | AAAHogEx |
| --- | ---: | ---: |
| 12345 | 239610 | 1425352 |
| 22222 | 555456 | 1641699 |
| 33333 | 94732 | 1118723 |

2-year vs Tempo seed 12345: CityHub 577586, Tempo 60219.

5-year vs AAAHogEx after the loan-guard: seed 12345 CityHub 599162 vs
AAAHogEx 6764340. CityHub stays solvent; it does not match HogEx scale.

## Interactive debug

Set `gui.ai_developer_tools = true` and CityHub setting `IsDebug = 1` to
`AIController.Break` on `FAIL`. Keep debug off in benches so the 400-line
AI window still holds quarterly STATs.
