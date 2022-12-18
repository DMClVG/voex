local Tiles = {}

Tiles.tiles = {
    air = { id=0, tex=-1 },
    stone = { id=1, tex=23 },
    planks = { id=2, tex=5 },
    grass = { id=3, tex={17,1,0,0,0,0}},
    dirt = { id=4, tex=1 },
    bricks = { id=5, tex=3 },
    log = { id=6, tex = {22, 22, 21, 21, 21, 21}},
    leaves = {id=7, tex=16}
}

setmetatable(Tiles, { __index=function (_, k)
    return Tiles.tiles[k]
end})

function Tiles:init()
    local tids = {}
    for name, tile in pairs(self.tiles) do
        tile["name"] = name
        tids[tile.id] = tile
    end
    self.tids = tids
    return Tiles
end

return Tiles