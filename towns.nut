class Towns {
	cfg = null;
	cargo = null;
	hubs = null;
	air_pairs = null;
	rail_pairs = null;

	constructor(cfg, cargo) {
		this.cfg = cfg;
		this.cargo = cargo;
		this.hubs = [];
		this.air_pairs = [];
		this.rail_pairs = [];
	}

	function Analyze() {
		this.hubs = [];
		this.air_pairs = [];
		this.rail_pairs = [];
		local towns = AITownList();
		local scored = AIList();
		local infos = {};
		local count = 0;
		for (local id = towns.Begin(); !towns.IsEnd(); id = towns.Next()) {
			if (!AITown.IsValidTown(id)) continue;
			count++;
			if ((count % 20) == 0) YieldIfLow();
			local pop = AITown.GetPopulation(id);
			local prod = this.cargo.pax == null ? 0 : AITown.GetLastMonthProduction(id, this.cargo.pax);
			infos[id] <- {
				id = id,
				pop = pop,
				houses = AITown.GetHouseCount(id),
				city = AITown.IsCity(id),
				tile = AITown.GetLocation(id),
				prod = prod,
				noise = AITown.GetAllowedNoise(id),
				exclusive = ExclusiveSkip(id)
			};
			scored.AddItem(id, pop);
		}
		scored.Sort(AIList.SORT_BY_VALUE, AIList.SORT_DESCENDING);

		local selected = {};
		local taken = 0;
		for (local id = scored.Begin(); !scored.IsEnd(); id = scored.Next()) {
			local info = infos[id];
			local seed = info.pop >= this.cfg.large_pop || info.city || taken < this.cfg.max_hubs;
			if (seed && !selected.rawin(id)) {
				info.role <- "seed";
				this.hubs.append(info);
				selected[id] <- true;
				taken++;
				if (taken >= this.cfg.max_hubs) break;
			}
		}

		local ids = [];
		foreach (id, info in infos) ids.append(id);
		local pairs = [];
		for (local i = 0; i < ids.len(); i++) {
			YieldIfLow();
			for (local j = i + 1; j < ids.len(); j++) {
				local a = infos[ids[i]];
				local b = infos[ids[j]];
				local dist = AIMap.DistanceManhattan(a.tile, b.tile);
				if (dist > this.cfg.pair_max_distance) continue;
				if (a.pop + b.pop < this.cfg.pair_min_combined_pop) continue;
				if (a.exclusive || b.exclusive) continue;
				local prod = min(a.prod, b.prod);
				if (prod < 1) prod = 1;
				local score = (a.pop + b.pop) * prod / max(dist, 8);
				pairs.append({ a = a, b = b, dist = dist, score = score });
			}
		}
		SortByScoreDesc(pairs);

		foreach (pair in pairs) {
			if (this.hubs.len() >= this.cfg.max_hubs) break;
			foreach (side in [pair.a, pair.b]) {
				if (selected.rawin(side.id)) continue;
				if (this.hubs.len() >= this.cfg.max_hubs) break;
				side.role <- "pair";
				this.hubs.append(side);
				selected[side.id] <- true;
			}
		}

		foreach (hub in this.hubs) {
			Log.Info("HUB", {
				id = hub.id, pop = hub.pop, houses = hub.houses,
				city = hub.city ? 1 : 0, noiseRoom = hub.noise, role = hub.role
			});
		}

		this._classifyPairs();
		return this.hubs.len() >= 2;
	}

	function _classifyPairs() {
		local n = this.hubs.len();
		local rail_opts = [];
		for (local i = 0; i < n; i++) {
			for (local j = i + 1; j < n; j++) {
				local a = this.hubs[i];
				local b = this.hubs[j];
				local dist = AIMap.DistanceManhattan(a.tile, b.tile);
				local prod = min(a.prod, b.prod);
				if (prod < 1) prod = 1;
				local score = (a.pop + b.pop) * prod / max(dist, 8);
				if (n == 2 || dist >= 30) {
					this.air_pairs.append({ a = a, b = b, dist = dist, score = score });
				}
				if (dist >= 12 && dist <= this.cfg.pair_max_distance) {
					rail_opts.append({ a = a, b = b, dist = dist, score = score });
				}
			}
		}
		SortByScoreDesc(this.air_pairs);
		SortByScoreDesc(rail_opts);
		local used = {};
		foreach (pair in rail_opts) {
			if (this.rail_pairs.len() >= max(this.cfg.max_hubs - 1, 1)) break;
			local key = min(pair.a.id, pair.b.id) + "-" + max(pair.a.id, pair.b.id);
			if (used.rawin(key)) continue;
			this.rail_pairs.append(pair);
			used[key] <- true;
		}
	}

	function Find(town_id) {
		foreach (hub in this.hubs) {
			if (hub.id == town_id) return hub;
		}
		return null;
	}
}
