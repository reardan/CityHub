class CityHubInfo extends AIInfo {
	function GetAuthor() { return "Wesley Reardan"; }
	function GetName() { return "CityHub"; }
	function GetDescription() {
		return "Passenger-hub AI: airports, catchment buses, and rail at large cities, then a thinner long-term builder.";
	}
	function GetVersion() { return 1; }
	function MinVersionToLoad() { return 1; }
	function GetDate() { return "2026-08-23"; }
	function CreateInstance() { return "CityHub"; }
	function GetShortName() { return "CHUB"; }
	function GetAPIVersion() { return "14"; }
	function UseAsRandomAI() { return true; }

	function GetSettings() {
		AddSetting({
			name = "large_pop",
			description = "Minimum population to treat a town as a large hub",
			easy_value = 800, medium_value = 800, hard_value = 600, custom_value = 800,
			min_value = 200, max_value = 5000, flags = CONFIG_INGAME
		});
		AddSetting({
			name = "pair_max_distance",
			description = "Max Manhattan distance for a close town pair",
			easy_value = 64, medium_value = 64, hard_value = 80, custom_value = 64,
			min_value = 16, max_value = 200, flags = CONFIG_INGAME
		});
		AddSetting({
			name = "pair_min_combined_pop",
			description = "Min combined population for a close town pair",
			easy_value = 600, medium_value = 600, hard_value = 400, custom_value = 600,
			min_value = 200, max_value = 8000, flags = CONFIG_INGAME
		});
		AddSetting({
			name = "max_hubs",
			description = "Maximum starter hubs",
			easy_value = 6, medium_value = 6, hard_value = 8, custom_value = 6,
			min_value = 2, max_value = 12, flags = CONFIG_INGAME
		});
		AddSetting({
			name = "starter_year_cap",
			description = "Years after start before forcing long-term mode",
			easy_value = 2, medium_value = 2, hard_value = 2, custom_value = 2,
			min_value = 1, max_value = 10, flags = CONFIG_INGAME
		});
		AddSetting({
			name = "disable_air",
			description = "Disable aircraft",
			easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0,
			flags = AICONFIG_BOOLEAN + CONFIG_INGAME
		});
		AddSetting({
			name = "disable_road",
			description = "Disable road vehicles and bus stops",
			easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0,
			flags = AICONFIG_BOOLEAN + CONFIG_INGAME
		});
		AddSetting({
			name = "disable_rail",
			description = "Disable trains",
			easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0,
			flags = AICONFIG_BOOLEAN + CONFIG_INGAME
		});
		AddSetting({
			name = "IsDebug",
			description = "Verbose pathfinder logs and Break on FAIL",
			easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0,
			flags = AICONFIG_BOOLEAN + CONFIG_INGAME
		});
	}
}

RegisterAI(CityHubInfo());
