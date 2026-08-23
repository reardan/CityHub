class Cargo {
	pax = null;
	mail = null;

	constructor() {
		this.pax = null;
		this.mail = null;
	}

	function Resolve() {
		local cargos = AICargoList();
		for (local c = cargos.Begin(); !cargos.IsEnd(); c = cargos.Next()) {
			if (this.pax == null && AICargo.HasCargoClass(c, AICargo.CC_PASSENGERS)) {
				this.pax = c;
			}
			if (this.mail == null && AICargo.HasCargoClass(c, AICargo.CC_MAIL)) {
				this.mail = c;
			}
		}
		if (this.pax == null) {
			Log.Fail("no_pax_cargo", null);
		}
		return this.pax != null;
	}
}
