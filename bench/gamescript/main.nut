class CityHubBench extends GSController {
	start_year = 0;
	last_key = "";
	cut_logged = false;

	constructor() {
		this.start_year = 0;
		this.last_key = "";
		this.cut_logged = false;
	}

	function Start() {
		this.start_year = GSDate.GetYear(GSDate.GetCurrentDate());
		while (true) {
			this._maybeStat();
			this._maybeCut();
			GSController.Sleep(74);
		}
	}

	function Save() {
		return { start_year = this.start_year, last_key = this.last_key, cut_logged = this.cut_logged };
	}

	function Load(version, data) {
		if (data.rawin("start_year")) this.start_year = data.start_year;
		if (data.rawin("last_key")) this.last_key = data.last_key;
		if (data.rawin("cut_logged")) this.cut_logged = data.cut_logged;
	}

	function _stamp() {
		local d = GSDate.GetCurrentDate();
		local y = GSDate.GetYear(d);
		local m = GSDate.GetMonth(d);
		local day = GSDate.GetDayOfMonth(d);
		local ms = m < 10 ? "0" + m : m.tostring();
		local ds = day < 10 ? "0" + day : day.tostring();
		return y + "-" + ms + "-" + ds;
	}

	function _maybeStat() {
		local d = GSDate.GetCurrentDate();
		local y = GSDate.GetYear(d);
		local q = (GSDate.GetMonth(d) - 1) / 3;
		local key = y + "-" + q;
		if (key == this.last_key) return;
		this.last_key = key;
		this._emitStats();
	}

	function _emitStats() {
		local ymd = this._stamp();
		local tick = GSController.GetTick();
		for (local c = GSCompany.COMPANY_FIRST; c < GSCompany.COMPANY_LAST; c++) {
			if (GSCompany.ResolveCompanyID(c) == GSCompany.COMPANY_INVALID) continue;
			local name = GSCompany.GetName(c);
			if (name == null) name = "unknown";
			name = this._oneWord(name);
			local rating = GSCompany.GetQuarterlyPerformanceRating(c, 1);
			GSLog.Info(
				"CHUB STAT y=" + ymd +
				" t=" + tick +
				" self=-1" +
				" id=" + c +
				" name=" + name +
				" val=" + GSCompany.GetQuarterlyCompanyValue(c, GSCompany.CURRENT_QUARTER) +
				" income=" + GSCompany.GetQuarterlyIncome(c, 1) +
				" exp=" + GSCompany.GetQuarterlyExpenses(c, 1) +
				" rating=" + rating +
				" cargo=" + GSCompany.GetQuarterlyCargoDelivered(c, 1) +
				" bal=" + GSCompany.GetBankBalance(c) +
				" loan=0 t=-1 r=-1 p=-1 s=-1"
			);
		}
	}

	function _maybeCut() {
		local offset = GSController.GetSetting("cut_year_offset");
		if (offset <= 0 || this.cut_logged) return;
		local y = GSDate.GetYear(GSDate.GetCurrentDate());
		if (y < this.start_year + offset) return;
		this.cut_logged = true;
		GSLog.Info("CHUB CUT y=" + this._stamp() + " t=" + GSController.GetTick());
		this._emitStats();
		GSGame.Pause();
	}

	function _oneWord(name) {
		local out = "";
		for (local i = 0; i < name.len(); i++) {
			local ch = name[i];
			if (ch == 32 || ch == 9) out += "_";
			else out += ch.tochar();
		}
		return out;
	}
}
