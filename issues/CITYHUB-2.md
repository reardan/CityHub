# CITYHUB-2: Scale passenger hubs vs AAAHogEx

## Status

done — `w/CITYHUB-2-scale-passenger-hubs`, merged to `main`.

## Description

CityHub stayed solvent against AAAHogEx but froze as a small-plane company.
After Q1 it stopped compounding: aggressive loan repay plus a clone guard
capped the fleet, full-load orders on both ends stalled cargo, and rail
never built because pathfinder extras were dropped and `BuildRail` was
called across a compressed stretch. 5-year seed 12345 was 599k vs HogEx
6.76M.

This ticket scales the existing passenger-hub strategy (air, joined buses,
rail). It does not port HogEx's estimator or all-cargo scanner.

## Acceptance Criteria

- [x] CityHub stays leveraged until cash covers the loan plus a buffer; planes
      keep cloning when passengers wait
- [x] Air and rail orders are not full-load on both ends; 5-year cargo is not
      flat after year 2
- [x] Rail paths that A* finds (including bridges/tunnels) can build; 2-year
      benches show trains on at least two of seeds 12345/22222/33333
- [x] Hub selection uses large_pop/city seeds plus pair-fill; long-term adds
      more airports and funds/statues towns
- [ ] 2-year seed 12345 company value around 1.0M or better — **missed**
      (416k GS cut in the CITYHUB-2 run)
- [ ] 5-year seed 12345 still rising at 1975 and around 2.5M — **missed**
      (485k GS cut; value oscillates under a maxed 300k loan)
- [x] No copied AAAHogEx source

## Resources

- Bench notes: [`bench/README.md`](../bench/README.md)
- Opponent: sibling repo `AAAHogEx`

## Notes

Three commits on `w/CITYHUB-2-scale-passenger-hubs`:

1. Leveraged loan, load-if-available orders, clone without the 4-plane guard
2. Preserve A* extras; build rail tile-by-tile; retry failed pairs; road
   bridges; wider depot search
3. Hub seed fix, long-term airport cap, town fund/statue, replace lost
   vehicles

OpenTTD Squirrel requires an exact argument count. `BuildHubs()` with an
optional `max_new` crashed until the starter always passed `3`.

Maps are not strictly reproducible across OpenTTD default-cfg drift. Compare
scores within a run. Residual gap vs HogEx is still about an order of
magnitude on 5-year value.
