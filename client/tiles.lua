tiles = {
    stone = { tex=2 },
    planks = { tex=7 },
}

tids = {}

do -- set ids
    local id = 1
    for name, tile in pairs(tiles) do
        tile["id"] = id
        tile["name"] = name
        table.insert(tids, tile)
        id = id + 1
    end
end