class EventPump {
	in_trouble = false;
	refresh_engines = false;
	lost_vehicles = null;

	constructor() {
		this.in_trouble = false;
		this.refresh_engines = false;
		this.lost_vehicles = [];
	}

	function Pump() {
		while (AIEventController.IsEventWaiting()) {
			local ev = AIEventController.GetNextEvent();
			if (ev == null) break;
			local et = ev.GetEventType();
			if (et == AIEvent.ET_VEHICLE_CRASHED) {
				local crashed = AIEventVehicleCrashed.Convert(ev);
				this.lost_vehicles.append(crashed.GetVehicleID());
				Log.Info("EVT", { kind = "crashed", veh = crashed.GetVehicleID() });
			} else if (et == AIEvent.ET_VEHICLE_LOST) {
				local lost = AIEventVehicleLost.Convert(ev);
				this.lost_vehicles.append(lost.GetVehicleID());
				Log.Info("EVT", { kind = "lost", veh = lost.GetVehicleID() });
			} else if (et == AIEvent.ET_AIRCRAFT_DEST_TOO_FAR) {
				local far = AIEventAircraftDestTooFar.Convert(ev);
				Log.Fail("range", { veh = far.GetVehicleID() });
				if (AIVehicle.IsValidVehicle(far.GetVehicleID())) {
					AIVehicle.SendVehicleToDepot(far.GetVehicleID());
				}
			} else if (et == AIEvent.ET_ENGINE_PREVIEW || et == AIEvent.ET_ENGINE_AVAILABLE) {
				this.refresh_engines = true;
				Log.Info("EVT", { kind = "engine" });
			} else if (et == AIEvent.ET_COMPANY_IN_TROUBLE) {
				this.in_trouble = true;
				Log.Info("EVT", { kind = "trouble" });
			} else if (et == AIEvent.ET_INDUSTRY_OPEN || et == AIEvent.ET_INDUSTRY_CLOSE) {
				Log.Info("EVT", { kind = "industry" });
			} else if (et == AIEvent.ET_ROAD_RECONSTRUCTION) {
				Log.Warn("EVT", { kind = "roadworks" });
			}
		}
	}
}
