class GameCfg {
	station_spread = 12;
	modified_catchment = false;
	distant_join = false;
	infra_maintenance = false;
	max_aircraft = 200;
	max_roadveh = 500;
	max_trains = 500;
	plane_speed = 1;
	breakdowns = false;
	build_on_slopes = true;
	max_bridge_length = 20;
	large_pop = 800;
	pair_max_distance = 64;
	pair_min_combined_pop = 600;
	max_hubs = 6;
	starter_year_cap = 2;
	disable_air = false;
	disable_road = false;
	disable_rail = false;

	constructor() {
	}

	function _read(name, fallback) {
		if (!AIGameSettings.IsValid(name)) return fallback;
		return AIGameSettings.GetValue(name);
	}

	function Refresh() {
		this.station_spread = this._read("station.station_spread", 12);
		this.modified_catchment = this._read("station.modified_catchment", 0) != 0;
		this.distant_join = this._read("station.distant_join_stations", 0) != 0;
		this.infra_maintenance = this._read("economy.infrastructure_maintenance", 0) != 0;
		this.max_aircraft = this._read("vehicle.max_aircraft", 200);
		this.max_roadveh = this._read("vehicle.max_roadveh", 500);
		this.max_trains = this._read("vehicle.max_trains", 500);
		this.plane_speed = this._read("vehicle.plane_speed", 1);
		this.breakdowns = this._read("difficulty.vehicle_breakdowns", 0) != 0;
		this.build_on_slopes = this._read("construction.build_on_slopes", 1) != 0;
		this.max_bridge_length = this._read("construction.max_bridge_length", 20);
		this.large_pop = AIController.GetSetting("large_pop");
		this.pair_max_distance = AIController.GetSetting("pair_max_distance");
		this.pair_min_combined_pop = AIController.GetSetting("pair_min_combined_pop");
		this.max_hubs = AIController.GetSetting("max_hubs");
		this.starter_year_cap = AIController.GetSetting("starter_year_cap");
		this.disable_air = AIController.GetSetting("disable_air") != 0;
		this.disable_road = AIController.GetSetting("disable_road") != 0;
		this.disable_rail = AIController.GetSetting("disable_rail") != 0;
	}
}
