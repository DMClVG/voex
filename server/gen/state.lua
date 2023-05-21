local state = {}
local spatialhash = loex.hash.spatial
local floor = math.floor

local hunks = {}

function hunks:xy(x, y, hunk)
  local layer = self.layer
  local hash = spatialhash(floor(x / layer.w), floor(y / layer.h))
  if hunk then
    self[hash] = hunk
  else
    return self[hash]
  end
end

function state.new(layers, seed)
  local new = {}
  new.seed = seed
  new.rng = love.math.newRandomGenerator(seed)
  new.w = loex.world.new()
  for _, layer in ipairs(layers) do
    local newhunks = { layer = layer }
    setmetatable(newhunks, { __index = hunks })
    new[layer] = newhunks
  end
  return new
end

return state
