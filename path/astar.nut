class MiniHeap {
	items = null;

	constructor() {
		this.items = [];
	}

	function Count() {
		return this.items.len();
	}

	function Push(node) {
		this.items.append(node);
		this._up(this.items.len() - 1);
	}

	function Pop() {
		if (this.items.len() == 0) return null;
		local top = this.items[0];
		local last = this.items.pop();
		if (this.items.len() > 0) {
			this.items[0] = last;
			this._down(0);
		}
		return top;
	}

	function _better(a, b) {
		if (a.f != b.f) return a.f < b.f;
		return a.h < b.h;
	}

	function _up(idx) {
		while (idx > 0) {
			local up = (idx - 1) / 2;
			if (!this._better(this.items[idx], this.items[up])) break;
			local tmp = this.items[idx];
			this.items[idx] = this.items[up];
			this.items[up] = tmp;
			idx = up;
		}
	}

	function _down(idx) {
		local n = this.items.len();
		while (true) {
			local left = idx * 2 + 1;
			local right = left + 1;
			local best = idx;
			if (left < n && this._better(this.items[left], this.items[best])) best = left;
			if (right < n && this._better(this.items[right], this.items[best])) best = right;
			if (best == idx) break;
			local tmp = this.items[idx];
			this.items[idx] = this.items[best];
			this.items[best] = tmp;
			idx = best;
		}
	}
}

class AStar {
	weight = 1;
	max_expansions = 4000;
	terrain = null;
	probes = null;
	neighbor_fn = null;
	cost_fn = null;
	goal_tiles = null;

	constructor(terrain, probes, neighbor_fn, cost_fn) {
		this.terrain = terrain;
		this.probes = probes;
		this.neighbor_fn = neighbor_fn;
		this.cost_fn = cost_fn;
		this.weight = 1;
		this.max_expansions = 4000;
		this.goal_tiles = {};
	}

	function Octile(tile, goals) {
		local best = 100000000;
		foreach (goal, _v in goals) {
			local dx = abs(AIMap.GetTileX(tile) - AIMap.GetTileX(goal));
			local dy = abs(AIMap.GetTileY(tile) - AIMap.GetTileY(goal));
			local cost = min(dx, dy) * 70 + abs(dx - dy) * 100;
			if (cost < best) best = cost;
		}
		return best;
	}

	function FindPath(sources, goals, weight, max_expansions) {
		this.weight = weight;
		this.max_expansions = max_expansions;
		this.goal_tiles = {};
		foreach (goal in goals) this.goal_tiles[goal] <- true;

		local open = MiniHeap();
		local closed = {};
		local expansions = 0;

		foreach (src in sources) {
			local h = this.Octile(src[0], this.goal_tiles);
			open.Push({
				tile = src[0], dir = src[1], g = 0, h = h,
				f = h * weight, prev = null
			});
		}

		while (open.Count() > 0 && expansions < max_expansions) {
			if ((expansions % 50) == 0) YieldIfLow();
			local cur = open.Pop();
			local ckey = cur.tile;
			local seen = closed.rawin(ckey) ? closed[ckey] : 0;
			local bit = 1 << (cur.dir & 3);
			if ((seen & bit) != 0) continue;
			closed[ckey] <- seen | bit;
			expansions++;

			if (this.goal_tiles.rawin(cur.tile)) {
				return { ok = true, node = cur, expansions = expansions };
			}

			local neighbors = this.neighbor_fn(this, cur);
			foreach (nb in neighbors) {
				local step = this.cost_fn(this, cur, nb);
				if (step < 0) continue;
				local g = cur.g + step;
				local h = this.Octile(nb[0], this.goal_tiles);
				open.Push({
					tile = nb[0], dir = nb[1], g = g, h = h,
					f = g + h * weight, prev = cur, extra = nb.len() > 2 ? nb[2] : null
				});
			}
		}
		return { ok = false, node = null, expansions = expansions };
	}

	function Reconstruct(node) {
		local tiles = [];
		local cur = node;
		while (cur != null) {
			tiles.insert(0, cur.tile);
			cur = cur.prev;
		}
		return tiles;
	}
}

function FindPathWithRetries(astar, sources, goals, label_src, label_dest) {
	local attempts = [
		{ w = 4, cap = 1200 },
		{ w = 2, cap = 2500 },
		{ w = 1, cap = 5000 }
	];
	local last = null;
	foreach (att in attempts) {
		last = astar.FindPath(sources, goals, att.w, att.cap);
		if (last.ok) {
			local path = astar.Reconstruct(last.node);
			local manh = AIMap.DistanceManhattan(path[0], path[path.len() - 1]);
			Log.Info("PATH", {
				src = label_src, dest = label_dest, w = att.w, exp = last.expansions,
				ok = 1, len = path.len(), manh = manh,
				cacheHit = astar.probes.hits, cacheMiss = astar.probes.misses
			});
			if (path.len() > 3 * max(manh, 1)) {
				Log.Warn("PATH", { src = label_src, dest = label_dest, reason = "too_long" });
				return null;
			}
			return path;
		}
		Log.Warn("PATH", { src = label_src, dest = label_dest, w = att.w, exp = last.expansions, ok = 0 });
	}
	Log.Info("PATH", {
		src = label_src, dest = label_dest, w = 1, exp = last == null ? 0 : last.expansions,
		ok = 0, len = 0, manh = 0, cacheHit = astar.probes.hits, cacheMiss = astar.probes.misses
	});
	return null;
}
