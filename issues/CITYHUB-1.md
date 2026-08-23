# CITYHUB-1: CityHub starter AI and bench harness

## Status

done — `w/CITYHUB-1-cityhub-starter`, merged to `main`.

## Description

Add CityHub (`CHUB`, API 14) as a passenger-hub OpenTTD AI: analyze large and
close towns, plant airports and planes, extend catchment with joined bus
stops, link nearby hubs with rail, then switch to a thinner long-term
builder. Include an original pathfinder and a dedicated match harness vs
AAAHogEx.

## Acceptance Criteria

- [x] CityHub loads on API 14 and can share a game with AAAHogEx
- [x] `Start()` never returns; `Save()` / `Load()` stay small
- [x] Parseable `CHUB` logs and `bench/run_match.sh` reproduce 2-year matches
- [x] No copied AAAHogEx `.nut` code

## Resources

- [`README.md`](../README.md)
- [`bench/README.md`](../bench/README.md)

## Notes

Starter benches lost to AAAHogEx on company value. Rail often failed to
build; that is the subject of CITYHUB-2.
