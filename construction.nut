class Construction {
	stack = null;

	constructor() {
		this.stack = [];
	}

	function Push(kind, tile, extra) {
		this.stack.append({ kind = kind, tile = tile, extra = extra });
	}

	function Clear() {
		this.stack = [];
	}

	function Rollback() {
		while (this.stack.len() > 0) {
			local rec = this.stack.pop();
			this._undo(rec);
		}
	}

	function _undo(rec) {
		switch (rec.kind) {
			case "airport":
				AIAirport.RemoveAirport(rec.tile);
				break;
			case "road":
				if (rec.extra != null) AIRoad.RemoveRoad(rec.tile, rec.extra);
				break;
			case "road_station":
				AIRoad.RemoveRoadStation(rec.tile);
				break;
			case "rail":
				if (rec.extra != null) {
					AIRail.RemoveRail(rec.extra.from, rec.tile, rec.extra.to);
				}
				break;
			case "rail_station":
				if (rec.extra != null) {
					AIRail.RemoveRailStationTileRectangle(rec.tile, rec.extra, false);
				}
				break;
			case "road_depot":
				AIRoad.RemoveRoadDepot(rec.tile);
				break;
			case "rail_depot":
				AITile.DemolishTile(rec.tile);
				break;
			case "bridge":
				AIBridge.RemoveBridge(rec.tile);
				break;
			case "tunnel":
				AITunnel.RemoveTunnel(rec.tile);
				break;
			case "vehicle":
				if (AIVehicle.IsValidVehicle(rec.extra)) {
					AIVehicle.SellVehicle(rec.extra);
				}
				break;
		}
	}
}

function YieldIfLow() {
	if (AIController.GetOpsTillSuspend() < 2000) {
		AIController.Sleep(1);
	}
}

function AdvertiseIfNeeded(town_id) {
	local rating = AITown.GetRating(town_id, AICompany.COMPANY_SELF);
	if (rating != AITown.TOWN_RATING_NONE && rating >= AITown.TOWN_RATING_POOR) return;
	if (AITown.IsActionAvailable(town_id, AITown.TOWN_ACTION_ADVERTISE_SMALL)) {
		AITown.PerformTownAction(town_id, AITown.TOWN_ACTION_ADVERTISE_SMALL);
	} else if (AITown.IsActionAvailable(town_id, AITown.TOWN_ACTION_ADVERTISE_MEDIUM)) {
		AITown.PerformTownAction(town_id, AITown.TOWN_ACTION_ADVERTISE_MEDIUM);
	}
}

function GrowTownIfAble(town_id, finance) {
	if (!AITown.IsValidTown(town_id)) return;
	AdvertiseIfNeeded(town_id);
	local cash = finance.Balance();
	if (cash >= 250000 && AITown.IsActionAvailable(town_id, AITown.TOWN_ACTION_BUILD_STATUE)) {
		AITown.PerformTownAction(town_id, AITown.TOWN_ACTION_BUILD_STATUE);
		cash = finance.Balance();
	}
	if (cash >= 25000 && AITown.IsActionAvailable(town_id, AITown.TOWN_ACTION_FUND_BUILDINGS)) {
		AITown.PerformTownAction(town_id, AITown.TOWN_ACTION_FUND_BUILDINGS);
	}
}

function ExclusiveSkip(town_id) {
	local owner = AITown.GetExclusiveRightsCompany(town_id);
	return owner != AICompany.COMPANY_INVALID && !AICompany.IsMine(owner);
}

function OppositeTile(tile, width, height) {
	return tile + (width - 1) + (height - 1) * AIMap.GetMapSizeX();
}

function TileOffset(tile, dx, dy) {
	return tile + dx + dy * AIMap.GetMapSizeX();
}

function CardinalOffset(dir) {
	if (dir == 0) return 1;
	if (dir == 1) return AIMap.GetMapSizeX();
	if (dir == 2) return -1;
	return -AIMap.GetMapSizeX();
}

function PathTile(hop) {
	if (typeof hop == "table") return hop.tile;
	return hop;
}

function PathExtra(hop) {
	if (typeof hop == "table" && hop.rawin("extra")) return hop.extra;
	return null;
}

function DirFromTiles(from_tile, to_tile) {
	local dx = AIMap.GetTileX(to_tile) - AIMap.GetTileX(from_tile);
	local dy = AIMap.GetTileY(to_tile) - AIMap.GetTileY(from_tile);
	if (dx > 0 && dy == 0) return 0;
	if (dx == 0 && dy > 0) return 1;
	if (dx < 0 && dy == 0) return 2;
	if (dx == 0 && dy < 0) return 3;
	return 0;
}

function VehicleCount(vt) {
	return AIGroup.GetNumVehicles(AIGroup.GROUP_ALL, vt);
}

function SortByScoreDesc(items) {
	for (local i = 1; i < items.len(); i++) {
		local cur = items[i];
		local j = i;
		while (j > 0 && items[j - 1].score < cur.score) {
			items[j] = items[j - 1];
			j--;
		}
		items[j] = cur;
	}
}
