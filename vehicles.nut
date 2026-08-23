class Vehicles {
	cargo = null;
	cfg = null;
	finance = null;

	constructor(cargo, cfg, finance) {
		this.cargo = cargo;
		this.cfg = cfg;
		this.finance = finance;
	}

	function PickAir(small_only) {
		local best = null;
		local best_score = 0;
		local list = AIEngineList(AIVehicle.VT_AIR);
		for (local e = list.Begin(); !list.IsEnd(); e = list.Next()) {
			if (!AIEngine.IsBuildable(e)) continue;
			if (!AIEngine.CanRefitCargo(e, this.cargo.pax)) continue;
			local pt = AIEngine.GetPlaneType(e);
			if (small_only && pt == AIAirport.PT_BIG_PLANE) continue;
			if (this.cfg.breakdowns && AIEngine.GetReliability(e) < 60) continue;
			local den = AIEngine.GetPrice(e) + AIEngine.GetRunningCost(e);
			if (den <= 0) den = 1;
			local score = AIEngine.GetCapacity(e) * AIEngine.GetMaxSpeed(e) * 1000 / den;
			if (score > best_score) {
				best_score = score;
				best = e;
			}
		}
		return best;
	}

	function PlaneFitsAirports(engine, type_a, type_b) {
		local pt = AIEngine.GetPlaneType(engine);
		if (pt == AIAirport.PT_BIG_PLANE) {
			return this._BigOk(type_a) && this._BigOk(type_b);
		}
		return true;
	}

	function _BigOk(t) {
		return t != AIAirport.AT_SMALL && t != AIAirport.AT_COMMUTER &&
			t != AIAirport.AT_HELIPORT && t != AIAirport.AT_HELISTATION &&
			t != AIAirport.AT_HELIDEPOT;
	}

	function RangeOk(engine, tile_a, tile_b) {
		local maxd = AIEngine.GetMaximumOrderDistance(engine);
		if (maxd == 0) return true;
		return AIOrder.GetOrderDistance(AIVehicle.VT_AIR, tile_a, tile_b) <= maxd;
	}

	function BuyPlane(hangar, engine) {
		if (!this.finance.EnsureMoney(AIEngine.GetPrice(engine))) return -1;
		local veh = -1;
		if (this.cargo.mail != null && AIEngine.CanRefitCargo(engine, this.cargo.mail)) {
			veh = AIVehicle.BuildVehicle(hangar, engine);
			if (AIVehicle.IsValidVehicle(veh) && this.cargo.pax != null) {
				AIVehicle.RefitVehicle(veh, this.cargo.pax);
			}
		} else {
			veh = AIVehicle.BuildVehicleWithRefit(hangar, engine, this.cargo.pax);
		}
		if (!AIVehicle.IsValidVehicle(veh)) {
			Log.Fail("buy_plane", { engine = engine });
			return -1;
		}
		return veh;
	}

	function PickRoad(cargo, road_veh_type) {
		local best = null;
		local best_score = 0;
		if (!AIRoad.IsRoadTypeAvailable(AIRoad.ROADTYPE_ROAD)) return null;
		local list = AIEngineList(AIVehicle.VT_ROAD);
		for (local e = list.Begin(); !list.IsEnd(); e = list.Next()) {
			if (!AIEngine.IsBuildable(e)) continue;
			if (AIEngine.GetRoadType(e) != AIRoad.ROADTYPE_ROAD) continue;
			if (!AIEngine.CanRefitCargo(e, cargo)) continue;
			if (AIRoad.GetRoadVehicleTypeForCargo(cargo) != road_veh_type) continue;
			if (this.cfg.breakdowns && AIEngine.GetReliability(e) < 50) continue;
			local den = AIEngine.GetPrice(e) + AIEngine.GetRunningCost(e);
			if (den <= 0) den = 1;
			local score = AIEngine.GetCapacity(e) * AIEngine.GetMaxSpeed(e) * 1000 / den;
			if (score > best_score) {
				best_score = score;
				best = e;
			}
		}
		return best;
	}

	function PickBus() {
		return this.PickRoad(this.cargo.pax, AIRoad.ROADVEHTYPE_BUS);
	}

	function PickTruck(cargo) {
		return this.PickRoad(cargo, AIRoad.ROADVEHTYPE_TRUCK);
	}

	function PickTrain() {
		local engine = null;
		local engine_score = 0;
		local wagon = null;
		local list = AIEngineList(AIVehicle.VT_RAIL);
		for (local e = list.Begin(); !list.IsEnd(); e = list.Next()) {
			if (!AIEngine.IsBuildable(e)) continue;
			if (AIEngine.IsWagon(e)) {
				if (AIEngine.CanRefitCargo(e, this.cargo.pax) && wagon == null) wagon = e;
				continue;
			}
			if (!AIEngine.CanPullCargo(e, this.cargo.pax)) continue;
			local rt = AIEngine.GetRailType(e);
			if (!AIRail.IsRailTypeAvailable(rt)) continue;
			if (!AIRail.TrainHasPowerOnRail(rt, rt)) continue;
			local den = AIEngine.GetPrice(e) + AIEngine.GetRunningCost(e);
			if (den <= 0) den = 1;
			local score = AIEngine.GetPower(e) * AIEngine.GetMaxSpeed(e) / den;
			if (score > engine_score) {
				engine_score = score;
				engine = e;
			}
		}
		return { engine = engine, wagon = wagon };
	}

	function SetAirOrders(veh, tile_a, tile_b) {
		AIOrder.AppendOrder(veh, tile_a, AIOrder.OF_NONE);
		AIOrder.AppendOrder(veh, tile_b, AIOrder.OF_NONE);
		AIVehicle.StartStopVehicle(veh);
	}

	function SetRailOrders(veh, tile_a, tile_b, depot) {
		AIOrder.AppendOrder(veh, tile_a, AIOrder.OF_NONE);
		AIOrder.AppendOrder(veh, tile_b, AIOrder.OF_NONE);
		if (this.cfg.breakdowns && depot != null && AIMap.IsValidTile(depot)) {
			AIOrder.AppendOrder(veh, depot, AIOrder.OF_SERVICE_IF_NEEDED);
		}
		AIVehicle.StartStopVehicle(veh);
	}

	function SetFeederOrders(veh, orphan_tile, hub_tile) {
		AIOrder.AppendOrder(veh, orphan_tile, AIOrder.OF_FULL_LOAD_ANY);
		AIOrder.AppendOrder(veh, hub_tile, AIOrder.OF_TRANSFER | AIOrder.OF_NO_LOAD);
		AIVehicle.StartStopVehicle(veh);
	}

	function SetFreightOrders(veh, src_tile, dst_tile) {
		AIOrder.AppendOrder(veh, src_tile, AIOrder.OF_FULL_LOAD_ANY);
		AIOrder.AppendOrder(veh, dst_tile, AIOrder.OF_UNLOAD | AIOrder.OF_NO_LOAD);
		AIVehicle.StartStopVehicle(veh);
	}

	function BuyRoadVehicle(depot, engine, cargo) {
		if (engine == null) return -1;
		if (!this.finance.EnsureMoney(AIEngine.GetPrice(engine))) return -1;
		local veh = AIVehicle.BuildVehicleWithRefit(depot, engine, cargo);
		if (!AIVehicle.IsValidVehicle(veh)) {
			Log.Fail("buy_road", { engine = engine });
			return -1;
		}
		return veh;
	}

	function BuyTrain(depot, pick, platform_len) {
		if (pick.engine == null) return -1;
		local need = AIEngine.GetPrice(pick.engine);
		if (pick.wagon != null) need += AIEngine.GetPrice(pick.wagon) * 3;
		if (!this.finance.EnsureMoney(need)) return -1;
		local veh = AIVehicle.BuildVehicle(depot, pick.engine);
		if (!AIVehicle.IsValidVehicle(veh)) {
			Log.Fail("buy_train", { engine = pick.engine });
			return -1;
		}
		if (pick.wagon != null) {
			local max_len = (platform_len - 1) * 16;
			for (local i = 0; i < 6; i++) {
				if (AIVehicle.GetLength(veh) + 16 > max_len) break;
				local wagon = AIVehicle.BuildVehicleWithRefit(depot, pick.wagon, this.cargo.pax);
				if (!AIVehicle.IsValidVehicle(wagon)) break;
				if (!AIVehicle.MoveWagon(wagon, 0, veh, AIVehicle.GetNumWagons(veh) - 1)) {
					AIVehicle.SellVehicle(wagon);
					break;
				}
			}
		}
		return veh;
	}

	function AnyBuildablePlane() {
		local list = AIEngineList(AIVehicle.VT_AIR);
		for (local e = list.Begin(); !list.IsEnd(); e = list.Next()) {
			if (!AIEngine.IsBuildable(e)) continue;
			if (this.cargo.pax != null && !AIEngine.CanRefitCargo(e, this.cargo.pax)) continue;
			if (AIEngine.GetPlaneType(e) != AIAirport.PT_HELICOPTER) return true;
		}
		return false;
	}
}
