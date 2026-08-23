require("log.nut");
require("cargo.nut");
require("settings.nut");
require("finance.nut");
require("construction.nut");
require("events.nut");
require("path/cache.nut");
require("path/astar.nut");
require("path/rail.nut");
require("path/road.nut");
require("towns.nut");
require("vehicles.nut");
require("air.nut");
require("bus.nut");
require("rail.nut");
require("longterm.nut");

class CityHub extends AIController {
	cfg = null;
	cargo = null;
	finance = null;
	construction = null;
	events = null;
	terrain = null;
	probes = null;
	towns = null;
	vehicles = null;
	air = null;
	bus = null;
	rail = null;
	longterm = null;
	phase = "analyze";
	start_year = 0;
	last_stat_key = "";
	save_data = null;

	constructor() {
		this.save_data = null;
	}

	function Save() {
		local hubs = [];
		if (this.towns != null) {
			foreach (hub in this.towns.hubs) hubs.append(hub.id);
		}
		local airs = [];
		if (this.air != null) {
			foreach (tid, st in this.air.stations) {
				airs.append({ town = tid, tile = st.tile, type = st.type, station = st.station });
			}
		}
		local rails = [];
		if (this.rail != null) {
			foreach (tid, st in this.rail.stations) {
				rails.append({ town = tid, tile = st.tile, station = st.station, depot = st.depot });
			}
		}
		local orphans = [];
		if (this.bus != null) {
			foreach (o in this.bus.orphans) orphans.append(o);
		}
		local edges = [];
		if (this.rail != null) {
			foreach (e in this.rail.edges) edges.append(e);
		}
		local failed = [];
		if (this.rail != null) {
			foreach (k, _v in this.rail.failed_pairs) failed.append(k);
		}
		return {
			version = 1,
			phase = this.phase,
			start_year = this.start_year,
			hubTownIds = hubs,
			airStations = airs,
			railStations = rails,
			orphanBusRoutes = orphans,
			railEdges = edges,
			failedPairs = failed,
			loanPolicy = "min"
		};
	}

	function Load(version, data) {
		this.save_data = data;
	}

	function Start() {
		this.cfg = GameCfg();
		this.cfg.Refresh();
		this.cargo = Cargo();
		if (!this.cargo.Resolve()) {
			while (true) AIController.Sleep(100);
		}
		this.finance = Finance();
		this.construction = Construction();
		this.events = EventPump();
		this.terrain = TerrainCache();
		this.probes = ProbeCache();
		this.towns = Towns(this.cfg, this.cargo);
		this.vehicles = Vehicles(this.cargo, this.cfg, this.finance);
		this.air = AirBuilder(this.cfg, this.cargo, this.finance, this.vehicles, this.towns, this.construction);
		this.bus = BusBuilder(
			this.cfg, this.cargo, this.finance, this.vehicles, this.towns, this.air,
			this.construction, this.terrain, this.probes
		);
		this.rail = RailBuilder(
			this.cfg, this.cargo, this.finance, this.vehicles, this.towns, this.air,
			this.construction, this.terrain, this.probes
		);
		this.longterm = LongTerm(
			this.cfg, this.cargo, this.finance, this.vehicles, this.towns, this.air, this.bus,
			this.rail, this.construction, this.terrain, this.probes, this.events
		);
		this.start_year = AIDate.GetYear(AIDate.GetCurrentDate());
		this._hydrate();
		AICompany.SetName("CityHub");
		Log.Info("HUB", { phase = "start", year = this.start_year });

		while (true) {
			this.events.Pump();
			this.cfg.Refresh();
			this._maybeStat();
			local year = AIDate.GetYear(AIDate.GetCurrentDate());
			if (this.phase != "longterm" && year >= this.start_year + this.cfg.starter_year_cap) {
				this.phase = "longterm";
				Log.Info("HUB", { phase = "longterm" });
			}
			if (!this.events.in_trouble) this._step();
			this.air.MaybeClone();
			this.rail.MaybeClone();
			this.finance.MaybeRepay();
			AIController.Sleep(50);
		}
	}

	function _hydrate() {
		if (this.save_data == null) return;
		local data = this.save_data;
		this.save_data = null;
		if (data.rawin("phase")) this.phase = data.phase;
		if (data.rawin("start_year")) this.start_year = data.start_year;
		if (data.rawin("failedPairs") && this.rail != null) {
			foreach (k in data.failedPairs) this.rail.failed_pairs[k] <- true;
		}
		if (data.rawin("airStations")) {
			foreach (st in data.airStations) {
				if (!AIMap.IsValidTile(st.tile)) continue;
				this.air.stations[st.town] <- {
					tile = st.tile, type = st.type, station = st.station,
					hangar = AIAirport.GetHangarOfAirport(st.tile), town = st.town
				};
			}
		}
		if (data.rawin("railStations")) {
			foreach (st in data.railStations) {
				this.rail.stations[st.town] <- {
					tile = st.tile, station = st.station, depot = st.depot,
					approach = st.tile, exit_dir = 0, town = st.town
				};
			}
		}
		if (data.rawin("orphanBusRoutes")) this.bus.orphans = data.orphanBusRoutes;
		if (data.rawin("railEdges")) this.rail.edges = data.railEdges;
		this.terrain.Clear();
		this.probes.Clear();
	}

	function _step() {
		if (this.phase == "analyze") {
			Log.Info("HUB", { phase = "analyze" });
			this.towns.Analyze();
			this.phase = "air";
		} else if (this.phase == "air") {
			Log.Info("HUB", { phase = "air" });
			this.air.BuildHubs();
			this.phase = "bus";
		} else if (this.phase == "bus") {
			Log.Info("HUB", { phase = "bus" });
			this.bus.CoverHubs();
			this.phase = "rail";
		} else if (this.phase == "rail") {
			Log.Info("HUB", { phase = "rail" });
			this.rail.BuildPairs();
			this.phase = "longterm";
			Log.Info("HUB", { phase = "longterm" });
		} else {
			this.longterm.Step();
		}
	}

	function _maybeStat() {
		local d = AIDate.GetCurrentDate();
		local y = AIDate.GetYear(d);
		local m = AIDate.GetMonth(d);
		local q = (m - 1) / 3;
		local key = y + "-" + q;
		if (key == this.last_stat_key) return;
		this.last_stat_key = key;
		this._emitStats();
	}

	function _emitStats() {
		local self = AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
		for (local c = AICompany.COMPANY_FIRST; c < AICompany.COMPANY_LAST; c++) {
			if (AICompany.ResolveCompanyID(c) == AICompany.COMPANY_INVALID) continue;
			local name = AICompany.GetName(c);
			if (name == null) name = "unknown";
			local rating = 0;
			if (AIDate.GetMonth(AIDate.GetCurrentDate()) != 1 || AIDate.GetDayOfMonth(AIDate.GetCurrentDate()) != 1) {
				rating = AICompany.GetQuarterlyPerformanceRating(c, 1);
			} else {
				rating = AICompany.GetQuarterlyPerformanceRating(c, 1);
			}
			local trains = 0;
			local road = 0;
			local planes = 0;
			local ships = 0;
			local loan = 0;
			if (c == self) {
				trains = VehicleCount(AIVehicle.VT_RAIL);
				road = VehicleCount(AIVehicle.VT_ROAD);
				planes = VehicleCount(AIVehicle.VT_AIR);
				ships = VehicleCount(AIVehicle.VT_WATER);
				loan = AICompany.GetLoanAmount();
			}
			Log.Info("STAT", {
				self = self,
				id = c,
				name = name,
				val = AICompany.GetQuarterlyCompanyValue(c, AICompany.CURRENT_QUARTER),
				income = AICompany.GetQuarterlyIncome(c, 1),
				exp = AICompany.GetQuarterlyExpenses(c, 1),
				rating = rating,
				cargo = AICompany.GetQuarterlyCargoDelivered(c, 1),
				bal = AICompany.GetBankBalance(c),
				loan = loan,
				t = trains,
				r = road,
				p = planes,
				s = ships
			});
		}
	}
}
