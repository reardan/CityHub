class LongTerm {
	cfg = null;
	cargo = null;
	finance = null;
	vehicles = null;
	towns = null;
	air = null;
	bus = null;
	rail = null;
	construction = null;
	terrain = null;
	probes = null;
	events = null;
	freight_built = null;
	bad_income = 0;
	step_i = 0;

	constructor(cfg, cargo, finance, vehicles, towns, air, bus, rail, construction, terrain, probes, events) {
		this.cfg = cfg;
		this.cargo = cargo;
		this.finance = finance;
		this.vehicles = vehicles;
		this.towns = towns;
		this.air = air;
		this.bus = bus;
		this.rail = rail;
		this.construction = construction;
		this.terrain = terrain;
		this.probes = probes;
		this.events = events;
		this.freight_built = {};
		this.bad_income = 0;
		this.step_i = 0;
	}

	function Step() {
		if (this.events.in_trouble) return;
		this.step_i++;
		this.air.MaybeClone();
		this.rail.MaybeClone();
		this._maintain();
		if ((this.step_i % 40) != 0) return;
		if (this.finance.Usable() < 50000) return;
		this.towns.Analyze();
		if (!this.cfg.disable_air) this.air.BuildHubs(this.cfg.max_hubs);
		if (!this.cfg.disable_road) this.bus.CoverHubs();
		if (!this.cfg.disable_rail) this.rail.BuildPairs();
		this._growHubs();
		if (this.finance.UnusedLoan() > 40000) this._tryFreight();
	}

	function _tryFreight() {
		if (this.cfg.disable_road) return;
		if (VehicleCount(AIVehicle.VT_ROAD) >= this.cfg.max_roadveh) return;
		if (this.finance.Usable() < 80000) return;
		local pair = this._bestFreight();
		if (pair == null) return;
		local key = pair.src + "-" + pair.dst + "-" + pair.cargo;
		if (this.freight_built.rawin(key)) return;
		if (this._buildFreight(pair)) this.freight_built[key] <- true;
	}

	function _bestFreight() {
		local industries = AIIndustryList();
		local producers = [];
		local acceptors = [];
		local n = 0;
		for (local id = industries.Begin(); !industries.IsEnd(); id = industries.Next()) {
			n++;
			if ((n % 15) == 0) YieldIfLow();
			if (!AIIndustry.IsValidIndustry(id)) continue;
			local itype = AIIndustry.GetIndustryType(id);
			if (!AIIndustryType.IsValidIndustryType(itype)) continue;
			local produced = AIIndustryType.GetProducedCargo(itype);
			for (local c = produced.Begin(); !produced.IsEnd(); c = produced.Next()) {
				if (c == this.cargo.pax || c == this.cargo.mail) continue;
				local amount = AIIndustry.GetLastMonthProduction(id, c);
				if (amount <= 0) continue;
				producers.append({
					id = id, cargo = c, amount = amount, tile = AIIndustry.GetLocation(id)
				});
			}
			local accepted = AIIndustryType.GetAcceptedCargo(itype);
			for (local c = accepted.Begin(); !accepted.IsEnd(); c = accepted.Next()) {
				if (c == this.cargo.pax || c == this.cargo.mail) continue;
				if (AIIndustry.IsCargoAccepted(id, c) == AIIndustry.CAS_NOT_ACCEPTED) continue;
				acceptors.append({ id = id, cargo = c, tile = AIIndustry.GetLocation(id) });
			}
		}
		local best = null;
		foreach (src in producers) {
			foreach (dst in acceptors) {
				if (src.cargo != dst.cargo || src.id == dst.id) continue;
				local dist = AIMap.DistanceManhattan(src.tile, dst.tile);
				if (dist < 8 || dist > 90) continue;
				local pay = AICargo.GetCargoIncome(src.cargo, dist, 20);
				local trips = max(1, 40 / max(dist / 8, 1));
				local score = src.amount * trips * pay / max(dist, 8);
				if (best == null || score > best.score) {
					best = {
						src = src.id, dst = dst.id, cargo = src.cargo, score = score,
						src_tile = src.tile, dst_tile = dst.tile, amount = src.amount
					};
				}
			}
		}
		return best;
	}

	function _buildFreight(pair) {
		if (!AIRoad.IsRoadTypeAvailable(AIRoad.ROADTYPE_ROAD)) return false;
		AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
		local src_stop = this._industryStop(pair.src_tile, pair.cargo, true);
		local dst_stop = this._industryStop(pair.dst_tile, pair.cargo, false);
		if (src_stop == null || dst_stop == null) {
			Log.Fail("freight_stop", { src = pair.src, dst = pair.dst });
			return false;
		}
		local depot = this.bus._buildDepot(src_stop);
		if (depot == null) return false;
		local astar = AStar(this.terrain, this.probes, RoadNeighbors, RoadCost);
		local path = FindPathWithRetries(astar, [[src_stop, 0]], [dst_stop], src_stop, dst_stop);
		if (path == null || !BuildRoadPath(path, this.construction, this.probes)) {
			Log.Fail("freight_path", { src = pair.src, dst = pair.dst });
			return false;
		}
		local engine = this.vehicles.PickTruck(pair.cargo);
		local veh = this.vehicles.BuyRoadVehicle(depot, engine, pair.cargo);
		if (veh < 0) return false;
		this.vehicles.SetFreightOrders(veh, src_stop, dst_stop);
		Log.Info("HUB", { role = "freight", src = pair.src, dest = pair.dst, cargo = pair.cargo });
		return true;
	}

	function _industryStop(center, cargo, is_pickup) {
		local vtype = AIRoad.GetRoadVehicleTypeForCargo(cargo);
		local road = this.bus._nearestRoad(center, 10);
		if (road == null) {
			for (local dir = 0; dir < 4; dir++) {
				local t = center + CardinalOffset(dir);
				if (AIMap.IsValidTile(t) && AITile.IsBuildable(t)) {
					if (AIRoad.BuildRoad(center, t) || AIError.GetLastError() == AIError.ERR_ALREADY_BUILT) {
						road = t;
						break;
					}
				}
			}
		}
		if (road == null) return null;
		local front = this.bus._front(road);
		if (front == null) front = road + CardinalOffset(0);
		{
			local test = AITestMode();
			if (AIRoad.BuildDriveThroughRoadStation(road, front, vtype, AIStation.STATION_NEW)) {
			} else if (!AIRoad.BuildRoadStation(road, front, vtype, AIStation.STATION_NEW)) {
				return null;
			}
		}
		if (!AIRoad.BuildDriveThroughRoadStation(road, front, vtype, AIStation.STATION_NEW)) {
			if (!AIRoad.BuildRoadStation(road, front, vtype, AIStation.STATION_NEW)) return null;
		}
		return road;
	}

	function _maintain() {
		local income = AICompany.GetQuarterlyIncome(AICompany.COMPANY_SELF, 1);
		if (income < 0) this.bad_income++;
		else this.bad_income = 0;
		if (this.bad_income >= 2) this._sellLosers();
		this._replaceLost();
	}

	function _sellLosers() {
		local list = AIVehicleList();
		for (local v = list.Begin(); !list.IsEnd(); v = list.Next()) {
			if (!AIVehicle.IsValidVehicle(v)) continue;
			if (AIVehicle.GetProfitLastYear(v) >= 0) continue;
			local orders = AIOrder.GetOrderCount(v);
			if (orders <= 0) continue;
			local dest = AIOrder.GetOrderDestination(v, 0);
			if (!AIMap.IsValidTile(dest)) continue;
			local sid = AIStation.GetStationID(dest);
			local waiting = 0;
			if (AIStation.IsValidStation(sid) && this.cargo.pax != null) {
				waiting = AIStation.GetCargoWaiting(sid, this.cargo.pax);
			}
			if (waiting > 20) continue;
			AIVehicle.SendVehicleToDepot(v);
		}
	}

	function _growHubs() {
		foreach (hub in this.towns.hubs) {
			if (!this.air.stations.rawin(hub.id) && !this.rail.stations.rawin(hub.id)) {
				continue;
			}
			GrowTownIfAble(hub.id, this.finance);
		}
	}

	function _replaceLost() {
		while (this.events.lost_vehicles.len() > 0) {
			local vid = this.events.lost_vehicles.pop();
			this._replaceVehicle(vid);
		}
		this._replaceMissingRoutes();
		if (this.events.refresh_engines) {
			this.events.refresh_engines = false;
			this.air.MaybeClone();
			this.rail.MaybeClone();
		}
	}

	function _replaceVehicle(vid) {
		if (!AIVehicle.IsValidVehicle(vid)) return;
		if (AIOrder.GetOrderCount(vid) < 2) return;
		local vtype = AIVehicle.GetVehicleType(vid);
		if (vtype == AIVehicle.VT_AIR) {
			foreach (tid, st in this.air.stations) {
				if (!AIAirport.IsHangarTile(st.hangar)) continue;
				if (!this.finance.EnsureMoney(20000)) return;
				local extra = AIVehicle.CloneVehicle(st.hangar, vid, true);
				if (AIVehicle.IsValidVehicle(extra)) {
					AIVehicle.StartStopVehicle(extra);
					return;
				}
			}
		} else if (vtype == AIVehicle.VT_RAIL) {
			foreach (tid, st in this.rail.stations) {
				if (!AIMap.IsValidTile(st.depot)) continue;
				if (!this.finance.EnsureMoney(20000)) return;
				local extra = AIVehicle.CloneVehicle(st.depot, vid, true);
				if (AIVehicle.IsValidVehicle(extra)) {
					AIVehicle.StartStopVehicle(extra);
					return;
				}
			}
		}
	}

	function _replaceMissingRoutes() {
		foreach (e in this.rail.edges) {
			if (AIVehicle.IsValidVehicle(e.veh)) continue;
			if (!this.rail.stations.rawin(e.a) || !this.rail.stations.rawin(e.b)) continue;
			local st_a = this.rail.stations[e.a];
			local st_b = this.rail.stations[e.b];
			local pick = this.vehicles.PickTrain();
			local veh = this.vehicles.BuyTrain(st_a.depot, pick, this.rail.platform_len);
			if (veh < 0) continue;
			this.vehicles.SetRailOrders(veh, st_a.tile, st_b.tile, st_a.depot);
			e.veh = veh;
		}
		foreach (o in this.bus.orphans) {
			if (AIVehicle.IsValidVehicle(o.veh)) continue;
			local depot = o.depot;
			if (depot == null || !AIMap.IsValidTile(depot)) {
				depot = this.bus._buildDepot(o.stop);
			}
			if (depot == null) continue;
			local engine = this.vehicles.PickBus();
			local veh = this.vehicles.BuyRoadVehicle(depot, engine, this.cargo.pax);
			if (veh < 0) continue;
			local hub = this.towns.Find(o.hub);
			if (hub == null) continue;
			this.vehicles.SetFeederOrders(veh, o.stop, this.bus._hubOrderTile(hub, o.stop));
			o.veh = veh;
			o.depot = depot;
		}
	}
}
