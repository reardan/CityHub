class BusBuilder {
	cfg = null;
	cargo = null;
	finance = null;
	vehicles = null;
	towns = null;
	air = null;
	construction = null;
	terrain = null;
	probes = null;
	orphans = null;

	constructor(cfg, cargo, finance, vehicles, towns, air, construction, terrain, probes) {
		this.cfg = cfg;
		this.cargo = cargo;
		this.finance = finance;
		this.vehicles = vehicles;
		this.towns = towns;
		this.air = air;
		this.construction = construction;
		this.terrain = terrain;
		this.probes = probes;
		this.orphans = [];
	}

	function CoverHubs() {
		if (this.cfg.disable_road) return;
		if (!AIRoad.IsRoadTypeAvailable(AIRoad.ROADTYPE_ROAD)) return;
		AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
		foreach (hub in this.towns.hubs) {
			YieldIfLow();
			if (AITown.GetRoadReworkDuration(hub.id) > 0) {
				Log.Warn("BUS", { town = hub.id, skip = "roadworks" });
				continue;
			}
			this.CoverOne(hub);
		}
	}

	function CoverOne(hub) {
		AdvertiseIfNeeded(hub.id);
		local radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
		local scan = min(40, 20 + hub.houses / 20);
		local pax_tiles = [];
		local future_tiles = [];
		this._scanTiles(hub.tile, scan, pax_tiles, future_tiles);
		local join = this._hubStation(hub.id);
		local rejected = {};
		local placed = 0;
		local attempts = 0;
		while (placed < 6 && attempts < 10) {
			YieldIfLow();
			attempts++;
			local cand = this._bestStop(hub, radius, rejected);
			if (cand == null || cand.cover < 8) break;
			if (!this.finance.EnsureMoney(5000)) break;
			if (this._buildStop(hub, cand, join)) {
				placed++;
			} else {
				rejected[cand.tile] <- true;
			}
		}
	}

	function _hubStation(town_id) {
		if (this.air.stations.rawin(town_id)) return this.air.stations[town_id].station;
		return null;
	}

	function _hubTile(town_id) {
		if (this.air.stations.rawin(town_id)) return this.air.stations[town_id].tile;
		local hub = this.towns.Find(town_id);
		return hub == null ? AIMap.TILE_INVALID : hub.tile;
	}

	function _scanTiles(center, scan, pax_tiles, future_tiles) {
		for (local dx = -scan; dx <= scan; dx++) {
			if ((dx % 8) == 0) YieldIfLow();
			for (local dy = -scan; dy <= scan; dy++) {
				local tile = TileOffset(center, dx, dy);
				if (!AIMap.IsValidTile(tile)) continue;
				if (this.cargo.pax != null && AITile.GetCargoProduction(tile, this.cargo.pax, 1, 1, 0) > 0) {
					this.terrain.MarkPax(tile);
					pax_tiles.append(tile);
				} else if (AITile.IsBuildable(tile) && AIRoad.GetNeighbourRoadCount(tile) >= 1) {
					this.terrain.MarkGrowth(tile);
					future_tiles.append(tile);
				}
			}
		}
	}

	function _bestStop(hub, radius, rejected) {
		local best = null;
		local center = hub.tile;
		for (local r = 2; r <= 18; r++) {
			YieldIfLow();
			for (local dx = -r; dx <= r; dx++) {
				for (local dy = -r; dy <= r; dy++) {
					if (abs(dx) != r && abs(dy) != r) continue;
					local tile = TileOffset(center, dx, dy);
					if (!AIMap.IsValidTile(tile)) continue;
					if (rejected.rawin(tile)) continue;
					if (!AIRoad.IsRoadTile(tile)) continue;
					if (AIRoad.IsRoadStationTile(tile)) continue;
					local front = this._front(tile);
					if (front == null) continue;
					local cover = 0;
					if (this.cargo.pax != null) {
						cover = AITile.GetCargoAcceptance(tile, this.cargo.pax, 1, 1, radius);
					}
					if (cover < 8) continue;
					if (best == null || cover > best.cover) {
						best = { tile = tile, front = front, cover = cover };
					}
				}
			}
			if (best != null && r >= 8) break;
		}
		return best;
	}

	function _front(tile) {
		for (local dir = 0; dir < 4; dir++) {
			local n = tile + CardinalOffset(dir);
			if (AIMap.IsValidTile(n) && AIRoad.IsRoadTile(n)) return n;
		}
		return null;
	}

	function _buildStop(hub, cand, join) {
		this.construction.Clear();
		local joins = [];
		if (join != null) joins.append(join);
		joins.append(AIStation.STATION_JOIN_ADJACENT);
		joins.append(AIStation.STATION_NEW);
		foreach (jid in joins) {
			if (this._tryDriveThrough(cand.tile, cand.front, jid)) {
				this._logStop(cand, jid, join);
				this.construction.Clear();
				return true;
			}
			if (this._tryNormal(cand.tile, cand.front, jid)) {
				this._logStop(cand, jid, join);
				this.construction.Clear();
				return true;
			}
		}
		if (this._tryStub(hub, cand)) {
			this.construction.Clear();
			return true;
		}
		this.construction.Rollback();
		Log.Warn("BUS", { town = hub.id, tile = cand.tile, skip = "join" });
		return false;
	}

	function _tryDriveThrough(tile, front, jid) {
		for (local dir = 0; dir < 4; dir++) {
			local other = tile + CardinalOffset(dir);
			if (!AIMap.IsValidTile(other) || !AIRoad.IsRoadTile(other)) continue;
			local ok = false;
			{
				local test = AITestMode();
				ok = AIRoad.BuildDriveThroughRoadStation(tile, other, AIRoad.ROADVEHTYPE_BUS, jid);
			}
			if (!ok) continue;
			if (AIRoad.BuildDriveThroughRoadStation(tile, other, AIRoad.ROADVEHTYPE_BUS, jid)) {
				this.construction.Push("road_station", tile, null);
				return true;
			}
		}
		return false;
	}

	function _tryNormal(tile, front, jid) {
		for (local dir = 0; dir < 4; dir++) {
			local side = tile + CardinalOffset(dir);
			if (!AIMap.IsValidTile(side) || !AITile.IsBuildable(side)) continue;
			local ok = false;
			{
				local test = AITestMode();
				ok = AIRoad.BuildRoadStation(side, tile, AIRoad.ROADVEHTYPE_BUS, jid);
			}
			if (!ok) continue;
			if (AIRoad.BuildRoadStation(side, tile, AIRoad.ROADVEHTYPE_BUS, jid)) {
				this.construction.Push("road_station", side, null);
				return true;
			}
		}
		return false;
	}

	function _tryStub(hub, cand) {
		local road = cand.tile;
		for (local dir = 0; dir < 4; dir++) {
			local a = road + CardinalOffset(dir);
			local b = a + CardinalOffset(dir);
			if (!AIMap.IsValidTile(a) || !AIMap.IsValidTile(b)) continue;
			if (!AITile.IsBuildable(a) || !AITile.IsBuildable(b)) continue;
			if (!AIRoad.BuildRoad(road, b)) continue;
			this.construction.Push("road", road, b);
			if (AIRoad.BuildRoadStation(a, road, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW)) {
				this.construction.Push("road_station", a, null);
				this._serveOrphan(hub, a);
				Log.Info("BUS", {
					tile = a, join = "new", coverNow = cand.cover, coverFuture = 0, orphan = 1
				});
				return true;
			}
		}
		return false;
	}

	function _logStop(cand, jid, airport_join) {
		local joined = (airport_join != null && jid == airport_join);
		if (jid == AIStation.STATION_NEW) {
			this._serveOrphanFromTile(cand.tile);
			Log.Info("BUS", {
				tile = cand.tile, join = "new", coverNow = cand.cover, coverFuture = 0, orphan = 1
			});
			return;
		}
		Log.Info("BUS", {
			tile = cand.tile,
			join = joined ? airport_join : "adj",
			coverNow = cand.cover,
			coverFuture = 0,
			orphan = 0
		});
	}

	function _serveOrphanFromTile(tile) {
		local hub = this.towns.hubs.len() > 0 ? this.towns.hubs[0] : null;
		foreach (h in this.towns.hubs) {
			if (AIMap.DistanceManhattan(h.tile, tile) < 40) {
				hub = h;
				break;
			}
		}
		if (hub != null) this._serveOrphan(hub, tile);
	}

	function _serveOrphan(hub, stop_tile) {
		if (VehicleCount(AIVehicle.VT_ROAD) >= this.cfg.max_roadveh) return;
		local depot = this._buildDepot(stop_tile);
		if (depot == null) {
			Log.Warn("BUS", { tile = stop_tile, skip = "depot" });
			return;
		}
		local hub_tile = this._roadNearHub(hub);
		if (hub_tile == null) return;
		local astar = AStar(this.terrain, this.probes, RoadNeighbors, RoadCost);
		local path = FindPathWithRetries(astar, [[depot, 0]], [hub_tile], stop_tile, hub_tile);
		if (path == null || !BuildRoadPath(path, this.construction, this.probes)) {
			Log.Fail("road_path", { src = stop_tile, dest = hub_tile });
			return;
		}
		local engine = this.vehicles.PickBus();
		local veh = this.vehicles.BuyRoadVehicle(depot, engine, this.cargo.pax);
		if (veh < 0) return;
		this.vehicles.SetFeederOrders(veh, stop_tile, this._hubOrderTile(hub, hub_tile));
		this.orphans.append({
			stop = stop_tile, hub = hub.id, veh = veh, depot = depot
		});
	}

	function _hubOrderTile(hub, road_tile) {
		if (this.air.stations.rawin(hub.id)) return this.air.stations[hub.id].tile;
		return road_tile;
	}

	function _roadNearHub(hub) {
		if (this.air.stations.rawin(hub.id)) {
			local t = this.air.stations[hub.id].tile;
			local found = this._nearestRoad(t, 12);
			if (found != null) return found;
		}
		return this._nearestRoad(hub.tile, 16);
	}

	function _nearestRoad(center, radius) {
		for (local r = 1; r <= radius; r++) {
			for (local dx = -r; dx <= r; dx++) {
				for (local dy = -r; dy <= r; dy++) {
					if (abs(dx) != r && abs(dy) != r) continue;
					local tile = TileOffset(center, dx, dy);
					if (AIMap.IsValidTile(tile) && AIRoad.IsRoadTile(tile)) return tile;
				}
			}
		}
		return null;
	}

	function _buildDepot(near) {
		for (local dir = 0; dir < 4; dir++) {
			local tile = near + CardinalOffset(dir);
			if (!AIMap.IsValidTile(tile) || !AITile.IsBuildable(tile)) continue;
			if (!AIRoad.BuildRoad(near, tile)) continue;
			this.construction.Push("road", near, tile);
			if (AIRoad.BuildRoadDepot(tile, near)) {
				this.construction.Push("road_depot", tile, null);
				this.construction.Clear();
				return tile;
			}
		}
		return null;
	}
}
