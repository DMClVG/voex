local tiles = {}

tiles.tiles = {
  air = { id = 0, tex = -1 },
  stone = { id = 1, tex = 23 },
  planks = { id = 2, tex = 5 },
  grass = { id = 3, tex = { 17, 1, 0, 0, 0, 0 } },
  dirt = { id = 4, tex = 1 },
  bricks = { id = 5, tex = 3 },
}

local id = {}
for name, tile in pairs(tiles.tiles) do
  tile["name"] = name
  id[tile.id] = tile
end
tiles.id = id

setmetatable(tiles, {
  __index = function(_, k) return tiles.tiles[k] end,
})

return tiles
