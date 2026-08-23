class TerrainCache {
	data = null;
	use_array = false;
	size = 0;
	gen = 0;
	FLAG_SEA = 1;
	FLAG_COAST = 2;
	FLAG_WATER = 4;
	FLAG_BUILDABLE = 8;
	FLAG_ROAD = 16;
	FLAG_RAIL = 32;
	FLAG_PAX = 64;
	FLAG_GROWTH = 128;
	FLAG_VALID = 256;

	constructor() {
		this.size = AIMap.GetMapSizeX() * AIMap.GetMapSizeY();
		this.use_array = this.size <= 262144;
		this.data = this.use_array ? array(this.size) : {};
		this.gen = 1;
	}

	function Clear() {
		this.gen++;
		this.data = this.use_array ? array(this.size) : {};
	}

	function InvalidateTile(tile) {
		if (this.use_array) {
			this.data[tile] = null;
		} else if (this.data.rawin(tile)) {
			this.data.rawdelete(tile);
		}
	}

	function Packed(tile) {
		local packed = this.use_array ? this.data[tile] : (this.data.rawin(tile) ? this.data[tile] : null);
		if (packed != null) return packed;
		local flags = this.FLAG_VALID;
		if (AITile.IsSeaTile(tile)) flags = flags | this.FLAG_SEA;
		if (AITile.IsCoastTile(tile)) flags = flags | this.FLAG_COAST;
		if (AITile.IsWaterTile(tile)) flags = flags | this.FLAG_WATER;
		if (AITile.IsBuildable(tile)) flags = flags | this.FLAG_BUILDABLE;
		if (AIRoad.IsRoadTile(tile)) flags = flags | this.FLAG_ROAD;
		if (AIRail.IsRailTile(tile)) flags = flags | this.FLAG_RAIL;
		local slope = AITile.GetSlope(tile);
		local height = AITile.GetMaxHeight(tile);
		packed = (flags & 0xFFFF) | ((slope & 0xFF) << 16) | ((height & 0xFF) << 24);
		if (this.use_array) this.data[tile] = packed;
		else this.data[tile] <- packed;
		return packed;
	}

	function Flags(tile) {
		return this.Packed(tile) & 0xFFFF;
	}

	function IsSea(tile) { return (this.Flags(tile) & this.FLAG_SEA) != 0; }
	function IsWater(tile) { return (this.Flags(tile) & this.FLAG_WATER) != 0; }
	function IsBuildable(tile) { return (this.Flags(tile) & this.FLAG_BUILDABLE) != 0; }
	function HasRoad(tile) { return (this.Flags(tile) & this.FLAG_ROAD) != 0; }
	function HasRail(tile) { return (this.Flags(tile) & this.FLAG_RAIL) != 0; }

	function MarkPax(tile) {
		local packed = this.Packed(tile) | this.FLAG_PAX;
		if (this.use_array) this.data[tile] = packed;
		else this.data[tile] <- packed;
	}

	function MarkGrowth(tile) {
		local packed = this.Packed(tile) | this.FLAG_GROWTH;
		if (this.use_array) this.data[tile] = packed;
		else this.data[tile] <- packed;
	}
}

class ProbeCache {
	hits = 0;
	misses = 0;
	table = null;

	constructor() {
		this.hits = 0;
		this.misses = 0;
		this.table = {};
	}

	function Clear() {
		this.table = {};
		this.hits = 0;
		this.misses = 0;
	}

	function Key(from_tile, tile, to_tile) {
		return from_tile + "-" + tile + "-" + to_tile;
	}

	function Get(from_tile, tile, to_tile) {
		local key = this.Key(from_tile, tile, to_tile);
		if (this.table.rawin(key)) {
			this.hits++;
			return this.table[key];
		}
		this.misses++;
		return null;
	}

	function Put(from_tile, tile, to_tile, ok, cost) {
		this.table[this.Key(from_tile, tile, to_tile)] <- { ok = ok, cost = cost };
	}

	function InvalidateAround(tile) {
		local drop = [];
		foreach (key, rec in this.table) {
			if (key.find(tile.tostring()) != null) drop.append(key);
		}
		foreach (key in drop) this.table.rawdelete(key);
	}
}
