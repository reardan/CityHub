class CityHubBench extends GSInfo {
	function GetAuthor() { return "Wesley Reardan"; }
	function GetName() { return "CityHubBench"; }
	function GetDescription() {
		return "Neutral scorekeeper: quarterly CHUB STAT lines and a cut-year pause.";
	}
	function GetVersion() { return 1; }
	function MinVersionToLoad() { return 1; }
	function GetDate() { return "2026-08-23"; }
	function CreateInstance() { return "CityHubBench"; }
	function GetShortName() { return "CHGS"; }
	function GetAPIVersion() { return "14"; }

	function GetSettings() {
		AddSetting({
			name = "cut_year_offset",
			description = "Pause this many years after the start date (0 = never)",
			easy_value = 2, medium_value = 2, hard_value = 5, custom_value = 2,
			min_value = 0, max_value = 100, flags = CONFIG_INGAME
		});
	}
}

RegisterGS(CityHubBench());
