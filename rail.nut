class RailBuilder {
	cfg = null;
	cargo = null;
	finance = null;
	vehicles = null;
	towns = null;
	air = null;
	construction = null;
	terrain = null;
	probes = null;
	stations = null;
	edges = null;
	failed_pairs = null;
	rail_type = null;
	platform_len = 4;
	nplat = 2;

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
		this.stations = {};
		this.edges = [];
		this.failed_pairs = {};
		this.rail_type = null;
	}

	function BuildPairs() {
		if (this.cfg.disable_rail) return;
		if (!this._pickRailType()) {
			Log.Warn("RAIL", { skip = "no_railtype" });
			return;
		}
		AIRail.SetCurrentRailType(this.rail_type);
		foreach (pair in this.towns.rail_pairs) {
			YieldIfLow();
			this.BuildPair(pair);
		}
	}

	function BuildPair(pair) {
		local key = min(pair.a.id, pair.b.id) + "-" + max(pair.a.id, pair.b.id);
		if (this.failed_pairs.rawin(key)) return;
		if (VehicleCount(AIVehicle.VT_RAIL) >= this.cfg.max_trains) return;
		local st_a = this._ensureStation(pair.a, pair.b);
		local st_b = this._ensureStation(pair.b, pair.a);
		if (st_a == null || st_b == null) {
			this.failed_pairs[key] <- true;
			Log.Info("RAIL", { pair = key, platforms = this.nplat, ok = 0, len = 0 });
			return;
		}
		local astar = AStar(this.terrain, this.probes, RailNeighbors, RailCost);
		local path = FindPathWithRetries(
			astar, [[st_a.approach, st_a.exit_dir]], [st_b.approach], st_a.tile, st_b.tile
		);
		if (path == null || !BuildRailPath(path, this.construction, this.probes)) {
			this.failed_pairs[key] <- true;
			Log.Info("RAIL", { pair = key, platforms = this.nplat, ok = 0, len = 0 });
			return;
		}
		local pick = this.vehicles.PickTrain();
		local veh = this.vehicles.BuyTrain(st_a.depot, pick, this.platform_len);
		if (veh < 0) {
			this.failed_pairs[key] <- true;
			return;
		}
		this.vehicles.SetRailOrders(veh, st_a.tile, st_b.tile, st_a.depot);
		this.edges.append({ a = pair.a.id, b = pair.b.id, veh = veh, key = key });
		Log.Info("RAIL", { pair = key, platforms = this.nplat, ok = 1, len = path.len() });
	}

	function _pickRailType() {
		local pick = this.vehicles.PickTrain();
		if (pick.engine == null) return false;
		this.rail_type = AIEngine.GetRailType(pick.engine);
		return AIRail.IsRailTypeAvailable(this.rail_type);
	}

	function _ensureStation(hub, peer) {
		if (this.stations.rawin(hub.id)) return this.stations[hub.id];
		AdvertiseIfNeeded(hub.id);
		if (ExclusiveSkip(hub.id)) {
			Log.Warn("RAIL", { town = hub.id, skip = "exclusive" });
			return null;
		}
		local dx = AIMap.GetTileX(peer.tile) - AIMap.GetTileX(hub.tile);
		local dy = AIMap.GetTileY(peer.tile) - AIMap.GetTileY(hub.tile);
		local track = abs(dx) >= abs(dy) ? AIRail.RAILTRACK_NE_SW : AIRail.RAILTRACK_NW_SE;
		local site = this._findSite(hub, track);
		if (site == null) {
			Log.Warn("RAIL", { town = hub.id, skip = "flat" });
			return null;
		}
		Log.Info("CASH", {
			bal = this.finance.Balance(), loan = AICompany.GetLoanAmount(),
			maxLoan = AICompany.GetMaxLoanAmount(), need = 40000
		});
		if (!this.finance.EnsureMoney(40000)) {
			Log.Fail("money", { town = hub.id, need = 40000 });
			return null;
		}
		this.construction.Clear();
		local join = AIStation.STATION_NEW;
		if (this.air.stations.rawin(hub.id)) join = this.air.stations[hub.id].station;
		if (!AIRail.BuildRailStation(site.tile, track, this.nplat, this.platform_len, join)) {
			if (join != AIStation.STATION_NEW) {
				join = AIStation.STATION_NEW;
				if (!AIRail.BuildRailStation(site.tile, track, this.nplat, this.platform_len, join)) {
					Log.Fail("rail_station", { town = hub.id, tile = site.tile });
					this.construction.Rollback();
					return null;
				}
			} else {
				Log.Fail("rail_station", { town = hub.id, tile = site.tile });
				this.construction.Rollback();
				return null;
			}
		}
		this.construction.Push("rail_station", site.tile, site.end);
		if (!this._buildApproach(site)) {
			this.construction.Rollback();
			return null;
		}
		this.construction.Clear();
		local rec = {
			tile = site.tile, end = site.end, approach = site.approach,
			depot = site.depot, exit_dir = site.exit_dir, town = hub.id,
			station = AIStation.GetStationID(site.tile)
		};
		this.stations[hub.id] <- rec;
		return rec;
	}

	function _findSite(hub, track) {
		local best = null;
		local center = hub.tile;
		for (local r = 4; r <= 28; r += 2) {
			YieldIfLow();
			for (local dx = -r; dx <= r; dx++) {
				for (local dy = -r; dy <= r; dy++) {
					if (abs(dx) != r && abs(dy) != r) continue;
					local tile = TileOffset(center, dx, dy);
					local site = this._measure(tile, track);
					if (site == null) continue;
					local score = -AIMap.DistanceManhattan(tile, hub.tile);
					if (this.cargo.pax != null) {
						score += AITile.GetCargoAcceptance(tile, this.cargo.pax, 2, this.platform_len, 4);
					}
					site.score <- score;
					if (best == null || site.score > best.score) best = site;
				}
			}
			if (best != null) break;
		}
		return best;
	}

	function _measure(tile, track) {
		if (!AIMap.IsValidTile(tile)) return null;
		local along_x = track == AIRail.RAILTRACK_NE_SW;
		local plen = this.platform_len;
		local nplat = this.nplat;
		local end = along_x ? TileOffset(tile, plen - 1, nplat - 1) : TileOffset(tile, nplat - 1, plen - 1);
		if (!AIMap.IsValidTile(end)) return null;
		local w = along_x ? plen + 2 : nplat + 1;
		local h = along_x ? nplat + 1 : plen + 2;
		if (!AITile.IsBuildableRectangle(tile, along_x ? plen : nplat, along_x ? nplat : plen)) {
			local test = AITestMode();
			if (!AITile.LevelTiles(tile, end)) return null;
		}
		{
			local test = AITestMode();
			if (!AIRail.BuildRailStation(tile, track, nplat, plen, AIStation.STATION_NEW)) return null;
		}
		local approach = along_x ? TileOffset(tile, plen, 0) : TileOffset(tile, 0, plen);
		local before = along_x ? TileOffset(tile, plen - 1, 0) : TileOffset(tile, 0, plen - 1);
		if (!AIMap.IsValidTile(approach) || !AITile.IsBuildable(approach)) return null;
		local depot_front = approach;
		local depot = along_x ? TileOffset(approach, 0, nplat) : TileOffset(approach, nplat, 0);
		if (!AIMap.IsValidTile(depot)) return null;
		{
			local test = AITestMode();
			if (!AIRail.BuildRailDepot(depot, depot_front)) {
				depot = along_x ? TileOffset(approach, 0, -1) : TileOffset(approach, -1, 0);
				if (!AIMap.IsValidTile(depot)) return null;
				if (!AIRail.BuildRailDepot(depot, depot_front)) return null;
			}
		}
		return {
			tile = tile, end = end, approach = approach, before = before,
			depot = depot, exit_dir = along_x ? 0 : 1, track = track
		};
	}

	function _buildApproach(site) {
		if (!AIRail.BuildRailTrack(site.approach, site.track) &&
			AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) {
			Log.Fail("rail_build", { tile = site.approach });
			return false;
		}
		this.construction.Push("rail", site.approach, { from = site.before, to = site.approach });
		if (!AIRail.BuildRailDepot(site.depot, site.approach)) {
			Log.Fail("rail_depot", { tile = site.depot });
			return false;
		}
		this.construction.Push("rail_depot", site.depot, null);
		AIRail.BuildRail(site.depot, site.approach, site.before);
		return true;
	}

	function MaybeClone() {
		if (this.cargo.pax == null) return;
		if (VehicleCount(AIVehicle.VT_RAIL) >= this.cfg.max_trains) return;
		if (this.finance.Usable() < 40000) return;
		foreach (tid, st in this.stations) {
			if (!AIStation.IsValidStation(st.station)) continue;
			local waiting = AIStation.GetCargoWaiting(st.station, this.cargo.pax);
			local list = AIVehicleList_Station(st.station);
			if (list.IsEmpty()) continue;
			local sample = list.Begin();
			if (AIVehicle.GetVehicleType(sample) != AIVehicle.VT_RAIL) continue;
			local cap = AIVehicle.GetCapacity(sample, this.cargo.pax);
			if (cap <= 0) cap = 80;
			if (waiting > 2 * cap) {
				local extra = AIVehicle.CloneVehicle(st.depot, sample, true);
				if (AIVehicle.IsValidVehicle(extra)) AIVehicle.StartStopVehicle(extra);
			}
		}
	}
}
