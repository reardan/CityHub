# CityHub

OpenTTD AI that opens with passenger hubs: pick large / close towns, plant
airports and planes, extend catchment with joined bus stops, then link nearby
hubs with rail. After the starter (or `starter_year_cap` years) it switches to
a thinner long-term scan for more hubs plus simple freight trucks.

Short name `CHUB`, API 14, instance class `CityHub`.

## Install

Symlink this repo into the OpenTTD AI directory:

```bash
./bench/stage_ai.sh
ln -sfn /home/w/git/TTD/CityHub/.stage/CityHub ~/.local/share/openttd/ai/CityHub
ln -sfn /home/w/git/TTD/CityHub/.stage/CityHub /home/w/git/TTD/OpenTTD/build/ai/CityHub
ln -sfn /home/w/git/TTD/CityHub/bench/gamescript ~/.local/share/openttd/game/CityHubBench
```

Do not symlink the repo root as the AI package. OpenTTD recursively loads every
`info.nut`, and `bench/gamescript/info.nut` is a Game Script (it uses `GSInfo`).

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `large_pop` | 800 | Population to treat a town as a seed hub |
| `pair_max_distance` | 64 | Max Manhattan distance for a close pair |
| `pair_min_combined_pop` | 600 | Min combined population for a close pair |
| `max_hubs` | 6 | Cap on starter hubs |
| `starter_year_cap` | 2 | Years after start before long-term mode |
| `disable_air` / `disable_road` / `disable_rail` | off | Mode kill-switches |
| `IsDebug` | off | Extra `PATH` detail and `Break` on `FAIL` |

## Runtime contract

`Start()` never returns. `Save()` / `Load()` store a small table (phase, hub
ids, station ids, vehicle ids, failed pairs). Terrain and build-probe caches
are rebuilt after load. Pathfinding yields when fewer than 2000 opcodes remain
on the tick.

## Logging

Every line is `CHUB <KIND> y=YYYY-MM-dd t=<tick> k=v`. Kinds: `STAT`, `HUB`,
`AIR`, `BUS`, `RAIL`, `PATH`, `CASH`, `EVT`, `FAIL`. Benches must pass
`-d script=4` so Info lines reach stderr.

## Benches

See [`bench/README.md`](bench/README.md) for 2-year and 5-year matches vs
AAAHogEx on 256×256 temperate maps starting in 1970.

## Development

Work on a feature branch when the change is large or needs isolation:
`username/TICKET-ID-short-description`. Commit directly to this repository.
Do **not** open GitHub or GitLab pull/merge requests.

Tickets live in [`issues/`](issues/README.md). Record the problem, acceptance
criteria, and outcome there. Update [`bench/README.md`](bench/README.md) when
a change is meant to move company value or cargo vs AAAHogEx.
