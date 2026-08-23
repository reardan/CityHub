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
	return out;
}

function RoadCost(astar, cur, nb) {
	local next = nb[0];
	if (AIRoad.AreRoadTilesConnected(cur.tile, next)) return 10;
	if (AIRail.IsLevelCrossingTile(next)) return 400;
	if (!AITile.IsBuildable(next) && !AIRoad.IsRoadTile(next)) return 500;
	return 100;
}

function BuildRoadPath(path, construction, probes) {
	if (path == null || path.len() < 2) return false;
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	local i = 0;
	while (i < path.len() - 1) {
		local start = path[i];
		local j = i + 1;
		local dir = DirFromTiles(start, path[j]);
		while (j + 1 < path.len() && DirFromTiles(path[j], path[j + 1]) == dir) j++;
		local end = path[j];
		if (!AIRoad.AreRoadTilesConnected(start, path[i + 1])) {
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
		i = j;
	}
	return true;
}
