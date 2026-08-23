class AirBuilder {
	cfg = null;
	cargo = null;
	finance = null;
	vehicles = null;
	towns = null;
	construction = null;
	stations = null;
	links = null;

	constructor(cfg, cargo, finance, vehicles, towns, construction) {
		this.cfg = cfg;
		this.cargo = cargo;
		this.finance = finance;
		this.vehicles = vehicles;
		this.towns = towns;
		this.construction = construction;
		this.stations = {};
		this.links = {};
	}

	function PreferredTypes() {
		local types = [];
		local poor = this.finance.Usable() < 200000 || this.cfg.infra_maintenance;
		if (poor) {
			types = [AIAirport.AT_SMALL, AIAirport.AT_COMMUTER, AIAirport.AT_LARGE];
		} else {
			types = [
				AIAirport.AT_LARGE, AIAirport.AT_METROPOLITAN, AIAirport.AT_COMMUTER,
				AIAirport.AT_SMALL
			];
		}
		local out = [];
		foreach (t in types) {
			if (AIAirport.IsValidAirportType(t)) out.append(t);
		}
		if (out.len() == 0 || !this.vehicles.AnyBuildablePlane()) {
			foreach (t in [AIAirport.AT_HELIPORT, AIAirport.AT_HELISTATION, AIAirport.AT_HELIDEPOT]) {
				if (AIAirport.IsValidAirportType(t)) out.append(t);
			}
		}
		return out;
	}

	function BuildHubs(max_new) {
		if (this.cfg.disable_air) return;
		local built = 0;
		foreach (hub in this.towns.hubs) {
			YieldIfLow();
			if (this.stations.rawin(hub.id)) continue;
			if (built >= max_new) break;
			if (this.stations.len() >= 2 && this.finance.Usable() < 80000) break;
			if (this.BuildOne(hub)) built++;
		}
		this.LinkPairs();
	}

	function BuildOne(hub) {
		AdvertiseIfNeeded(hub.id);
		local types = this.PreferredTypes();
		local best = null;
		foreach (t in types) {
			local cand = this.FindSite(hub, t);
			if (cand != null && (best == null || cand.score > best.score)) best = cand;
		}
		if (best == null) {
			Log.Warn("AIR", { town = hub.id, skip = "flat" });
			return false;
		}
		Log.Info("CASH", {
			bal = this.finance.Balance(), loan = AICompany.GetLoanAmount(),
			maxLoan = AICompany.GetMaxLoanAmount(), need = best.cost
		});
		if (best.cost > this.finance.ProjectCap() || !this.finance.EnsureMoney(best.cost)) {
			Log.Fail("money", { town = hub.id, need = best.cost });
			return false;
		}
		this.construction.Clear();
		if (best.level) {
			AITile.LevelTiles(best.tile, OppositeTile(best.tile, best.w, best.h));
			this.construction.Push("terraform", best.tile, null);
		}
		if (!AIAirport.BuildAirport(best.tile, best.type, AIStation.STATION_NEW)) {
			Log.Fail("airport", { town = hub.id, tile = best.tile, skip = "noise" });
			this.construction.Rollback();
			return false;
		}
		this.construction.Push("airport", best.tile, null);
		this.construction.Clear();
		local sid = AIStation.GetStationID(best.tile);
		this.stations[hub.id] <- {
			tile = best.tile, type = best.type, station = sid,
			hangar = AIAirport.GetHangarOfAirport(best.tile), town = hub.id
		};
		Log.Info("AIR", {
			type = best.type, tile = best.tile, nearestTown = best.nearest,
			noise = best.noise, cost = best.cost, stationId = sid
		});
		return true;
	}

	function FindSite(hub, type) {
		local w = AIAirport.GetAirportWidth(type);
		local h = AIAirport.GetAirportHeight(type);
		local radius = AIAirport.GetAirportCoverageRadius(type);
		local best = null;
		local center = hub.tile;
		for (local r = 3; r <= 35; r += (r < 12 ? 1 : 2)) {
			YieldIfLow();
			for (local dx = -r; dx <= r; dx++) {
				for (local dy = -r; dy <= r; dy++) {
					if (abs(dx) != r && abs(dy) != r) continue;
					local tile = center + dx + dy * AIMap.GetMapSizeX();
					if (!AIMap.IsValidTile(tile)) continue;
					if (!AIMap.IsValidTile(OppositeTile(tile, w, h))) continue;
					local nearest = AIAirport.GetNearestTown(tile, type);
					local noise = AIAirport.GetNoiseLevelIncrease(tile, type);
					if (noise > AITown.GetAllowedNoise(nearest)) continue;
					if (nearest != hub.id) continue;
					local level = false;
					local cost = AIAirport.GetPrice(type);
					if (!AITile.IsBuildableRectangle(tile, w, h)) {
						local test = AITestMode();
						local acc = AIAccounting();
						if (!AITile.LevelTiles(tile, OppositeTile(tile, w, h))) continue;
						cost += acc.GetCosts();
						if (cost > this.finance.ProjectCap()) continue;
						level = true;
					}
					{
						local test = AITestMode();
						if (!AIAirport.BuildAirport(tile, type, AIStation.STATION_NEW)) continue;
					}
					local cover = AITile.GetCargoAcceptance(tile, this.cargo.pax, w, h, radius);
					local score = cover - cost / 1000 - 2 * AIMap.DistanceManhattan(tile, hub.tile);
					if (best == null || score > best.score) {
						best = {
							tile = tile, type = type, w = w, h = h, score = score,
							cost = cost, level = level, nearest = nearest, noise = noise
						};
					}
				}
			}
			if (best != null && r >= 10) break;
		}
		return best;
	}

	function LinkPairs() {
		if (this.stations.len() < 2) return;
		if (VehicleCount(AIVehicle.VT_AIR) >= this.cfg.max_aircraft) return;
		local pairs = this.towns.air_pairs;
		if (pairs.len() == 0) {
			local ids = [];
			foreach (tid, st in this.stations) ids.append(tid);
			if (ids.len() >= 2) {
				pairs = [{
					a = this.towns.Find(ids[0]), b = this.towns.Find(ids[1]),
					dist = 1, score = 1
				}];
			}
		}
		local linked = 0;
		local n = this.stations.len();
		local cap = n * (n - 1) / 2;
		if (cap < 1) cap = 1;
		foreach (pair in pairs) {
			if (pair.a == null || pair.b == null) continue;
			if (!this.stations.rawin(pair.a.id) || !this.stations.rawin(pair.b.id)) continue;
			local key = min(pair.a.id, pair.b.id) + "-" + max(pair.a.id, pair.b.id);
			if (this.links.rawin(key)) continue;
			if (linked >= cap) break;
			this.FlyPair(this.stations[pair.a.id], this.stations[pair.b.id]);
			this.links[key] <- true;
			linked++;
		}
	}

	function FlyPair(st_a, st_b) {
		local small_only = !this.vehicles._BigOk(st_a.type) || !this.vehicles._BigOk(st_b.type);
		local engine = this.vehicles.PickAir(small_only);
		if (engine == null) {
			Log.Fail("no_plane", null);
			return;
		}
		if (!this.vehicles.RangeOk(engine, st_a.tile, st_b.tile)) {
			Log.Fail("range", { skip = "range" });
			return;
		}
		if (VehicleCount(AIVehicle.VT_AIR) >= this.cfg.max_aircraft) return;
		if (!AIAirport.IsHangarTile(st_a.hangar)) {
			Log.Fail("no_hangar", { tile = st_a.tile });
			return;
		}
		local veh = this.vehicles.BuyPlane(st_a.hangar, engine);
		if (veh < 0) return;
		this.vehicles.SetAirOrders(veh, st_a.tile, st_b.tile);
		Log.Info("AIR", { stationId = st_a.station, engine = engine, veh = veh });
	}

	function MaybeClone() {
		if (this.cargo.pax == null) return;
		if (VehicleCount(AIVehicle.VT_AIR) >= this.cfg.max_aircraft) return;
		if (this.finance.Usable() < 60000) return;
		foreach (tid, st in this.stations) {
			if (!AIStation.IsValidStation(st.station)) continue;
			local waiting = AIStation.GetCargoWaiting(st.station, this.cargo.pax);
			local list = AIVehicleList_Station(st.station);
			if (list.IsEmpty()) continue;
			local sample = list.Begin();
			local cap = AIVehicle.GetCapacity(sample, this.cargo.pax);
			if (cap <= 0) cap = 50;
			if (waiting > cap) {
				local extra = AIVehicle.CloneVehicle(st.hangar, sample, true);
				if (AIVehicle.IsValidVehicle(extra)) AIVehicle.StartStopVehicle(extra);
			}
		}
	}
}
