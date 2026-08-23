function RailNeighbors(astar, cur) {
	local out = [];
	local par = cur.prev == null ? null : cur.prev.tile;
	for (local dir = 0; dir < 4; dir++) {
		local next = cur.tile + CardinalOffset(dir);
		if (!AIMap.IsValidTile(next)) continue;
		if (par != null && next == par) continue;
		if (astar.terrain.IsSea(next) && !AITile.IsBuildable(next)) continue;
		if (par != null && dir != cur.dir && astar.weight >= 4) {
			local turn = abs(dir - cur.dir);
			if (turn == 1 || turn == 3) continue;
		}
		local cached = astar.probes.Get(par == null ? cur.tile : par, cur.tile, next);
		local ok = false;
		local cost = 100;
		if (cached != null) {
			ok = cached.ok;
			cost = cached.cost;
		} else {
			local test = AITestMode();
			if (par == null) {
				ok = AITile.IsBuildable(next) || AIRail.IsRailTile(next);
			} else {
				ok = AIRail.BuildRail(par, cur.tile, next);
			}
			cost = 100;
			if (par != null && dir != cur.dir) cost += 300;
			if (AITile.GetSlope(next) != AITile.SLOPE_FLAT) cost += 80;
			astar.probes.Put(par == null ? cur.tile : par, cur.tile, next, ok, cost);
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
				if (AIBridge.BuildBridge(AIVehicle.VT_RAIL, bid, cur.tile, end)) {
					out.append([end, dir, { bridge = true, from = cur.tile }]);
					break;
				}
			}
		}
		local test2 = AITestMode();
		if (AITunnel.BuildTunnel(AIVehicle.VT_RAIL, cur.tile)) {
			local other = AITunnel.GetOtherTunnelEnd(cur.tile);
			if (AIMap.IsValidTile(other) && other != cur.tile) {
				out.append([other, dir, { tunnel = true }]);
			}
		}
	}
	return out;
}

function RailCost(_astar, cur, nb) {
	local cost = 100;
	if (nb[1] != cur.dir) cost += 250;
	if (nb.len() > 2 && nb[2] != null) {
		if (nb[2].rawin("bridge")) cost += 400;
		if (nb[2].rawin("tunnel")) cost += 350;
	}
	return cost;
}

function _pickBridge(len) {
	local bridges = AIBridgeList_Length(len);
	if (bridges.IsEmpty()) return null;
	return bridges.Begin();
}

function _buildRailSpecial(path, i, construction, probes) {
	local extra = PathExtra(path[i]);
	if (extra == null) return false;
	if (extra.rawin("bridge")) {
		local start = extra.rawin("from") ? extra.from : PathTile(path[i - 1]);
		local end = PathTile(path[i]);
		local len = AIMap.DistanceManhattan(start, end);
		local bid = _pickBridge(len);
		if (bid == null) {
			Log.Fail("rail_build", { tile = start, skip = "bridge" });
			return null;
		}
		if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bid, start, end)) {
			if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) {
				Log.Fail("rail_build", { tile = start, skip = "bridge" });
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
		if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, start)) {
			if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT) {
				Log.Fail("rail_build", { tile = start, skip = "tunnel" });
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

function _stepToward(from_tile, to_tile) {
	local dx = AIMap.GetTileX(to_tile) - AIMap.GetTileX(from_tile);
	local dy = AIMap.GetTileY(to_tile) - AIMap.GetTileY(from_tile);
	if (dx != 0) dx = dx > 0 ? 1 : -1;
	if (dy != 0) dy = dy > 0 ? 1 : -1;
	return TileOffset(from_tile, dx, dy);
}

function BuildRailPath(path, construction, probes) {
	if (path == null || path.len() < 3) return false;
	local i = 1;
	while (i < path.len() - 1) {
		local extra = PathExtra(path[i]);
		if (extra != null) {
			local special = _buildRailSpecial(path, i, construction, probes);
			if (special == null) return false;
			if (special) {
				i++;
				continue;
			}
		}
		local from = PathTile(path[i - 1]);
		local tile = PathTile(path[i]);
		local to = PathTile(path[i + 1]);
		local next_extra = PathExtra(path[i + 1]);
		if (next_extra != null &&
			(next_extra.rawin("bridge") || next_extra.rawin("tunnel"))) {
			to = _stepToward(tile, to);
		}
		if (!AIRail.BuildRail(from, tile, to)) {
			local err = AIError.GetLastError();
			if (err == AIError.ERR_ALREADY_BUILT) {
				i++;
				continue;
			}
			if (err == AIError.ERR_LAND_SLOPED_WRONG || err == AIError.ERR_AREA_NOT_CLEAR) {
				AITile.LevelTiles(tile, tile);
				if (!AIRail.BuildRail(from, tile, to)) {
					Log.Fail("rail_build", { tile = tile });
					probes.InvalidateAround(tile);
					return false;
				}
			} else {
				Log.Fail("rail_build", { tile = tile });
				return false;
			}
		}
		construction.Push("rail", tile, { from = from, to = to });
		probes.InvalidateAround(tile);
		i++;
	}
	return true;
}
