function RoadNeighbors(astar, cur) {
	local out = [];
	local par = cur.prev == null ? null : cur.prev.tile;
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	for (local dir = 0; dir < 4; dir++) {
		local next = cur.tile + CardinalOffset(dir);
		if (!AIMap.IsValidTile(next)) continue;
		if (par != null && next == par) continue;
		if (par != null) {
			local connect = AIRoad.CanBuildConnectedRoadPartsHere(cur.tile, par, next);
			if (connect == 0 || connect == -1) continue;
		}
		local cached = astar.probes.Get(par == null ? cur.tile : par, cur.tile, next);
		local ok = false;
		if (cached != null) {
			ok = cached.ok;
		} else {
			local test = AITestMode();
			ok = AIRoad.AreRoadTilesConnected(cur.tile, next) || AIRoad.BuildRoad(cur.tile, next);
			astar.probes.Put(par == null ? cur.tile : par, cur.tile, next, ok, 100);
		}
		if (ok) out.append([next, dir]);
	}
	local max_len = 8;
	if (AIGameSettings.IsValid("construction.max_bridge_length")) {
		max_len = min(AIGameSettings.GetValue("construction.max_bridge_length"), 12);
	}
	if (par != null) {
		local dir = cur.dir;
		local off = CardinalOffset(dir);
		for (local len = 3; len <= max_len; len++) {
			local end = cur.tile + off * len;
			if (!AIMap.IsValidTile(end)) break;
			local test = AITestMode();
			local bridges = AIBridgeList_Length(len);
			if (!bridges.IsEmpty()) {
				local bid = bridges.Begin();
				if (AIBridge.BuildBridge(AIVehicle.VT_ROAD, bid, cur.tile, end)) {
					out.append([end, dir, { bridge = true, from = cur.tile }]);
					break;
				}
			}
		}
		local test2 = AITestMode();
		if (AITunnel.BuildTunnel(AIVehicle.VT_ROAD, cur.tile)) {
			local other = AITunnel.GetOtherTunnelEnd(cur.tile);
			if (AIMap.IsValidTile(other) && other != cur.tile) {
				out.append([other, dir, { tunnel = true }]);
			}
		}
	}
	return out;
}

function RoadCost(astar, cur, nb) {
	local next = nb[0];
	if (nb.len() > 2 && nb[2] != null) {
		if (nb[2].rawin("bridge")) return 400;
		if (nb[2].rawin("tunnel")) return 350;
	}
	if (AIRoad.AreRoadTilesConnected(cur.tile, next)) return 10;
	if (AIRail.IsLevelCrossingTile(next)) return 400;
	if (!AITile.IsBuildable(next) && !AIRoad.IsRoadTile(next)) return 500;
	return 100;
}

function _buildRoadSpecial(path, i, construction, probes) {
	local extra = PathExtra(path[i]);
	if (extra == null) return false;
	if (extra.rawin("bridge")) {
		local start = extra.rawin("from") ? extra.from : PathTile(path[i - 1]);
		local end = PathTile(path[i]);
		local len = AIMap.DistanceManhattan(start, end);
		local bridges = AIBridgeList_Length(len);
		if (bridges.IsEmpty()) {
			Log.Fail("road_build", { tile = start, skip = "bridge" });
			return null;
		}
		local bid = bridges.Begin();
		if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bid, start, end)) {
			if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) {
				Log.Fail("road_build", { tile = start, skip = "bridge" });
				return null;
			}
		} else {
			construction.Push("bridge", start, null);
		}
		probes.InvalidateAround(start);
		probes.InvalidateAround(end);
		return true;
	}
	if (extra.rawin("tunnel")) {
		local start = PathTile(path[i - 1]);
		if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, start)) {
			if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) {
				Log.Fail("road_build", { tile = start, skip = "tunnel" });
				return null;
			}
		} else {
			construction.Push("tunnel", start, null);
		}
		probes.InvalidateAround(start);
		return true;
	}
	return false;
}

function BuildRoadPath(path, construction, probes) {
	if (path == null || path.len() < 2) return false;
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	local i = 0;
	while (i < path.len() - 1) {
		local next_i = i + 1;
		local special = _buildRoadSpecial(path, next_i, construction, probes);
		if (special == null) return false;
		if (special) {
			i = next_i;
			continue;
		}
		local start = PathTile(path[i]);
		local end = PathTile(path[i + 1]);
		if (!AIRoad.AreRoadTilesConnected(start, end)) {
			if (!AIRoad.BuildRoad(start, end)) {
				if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) {
					Log.Fail("road_build", { tile = start });
					return false;
				}
			} else {
				construction.Push("road", start, end);
			}
		}
		probes.InvalidateAround(start);
		i = i + 1;
	}
	return true;
}
