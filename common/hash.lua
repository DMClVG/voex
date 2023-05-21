local hash = {}

function hash.spatial(x, y, z) return table.concat({ x, y, z }, "/") end

return hash
