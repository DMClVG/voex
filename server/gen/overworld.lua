local gen = require("gen")
local chunk = loex.chunk
local size = chunk.size
local floor = math.floor
local tiles = loex.tiles
local ffi = require("ffi")
local spatialhash = loex.hash.spatial
local boundedbrush = loex.brush.bounded
local concat = lume.concat
local insert = table.insert
local distance3d = loex.utils.distance3d
local max, min = math.max, math.min

local pred = gen.predicates
local layer_terrain = gen.layer.new(size, size)
local layer_trees_sampler = gen.layer.new(200, 200)
local layer_rocks_sampler = gen.layer.new(50, 50)
local layer_trees = gen.layer.new(5, 5)
local layer_rocks = gen.layer.new(5, 5)
local layer_caves = gen.layer.new(100, 100)

local air, dirt, grass, stone, leaves, log =
  tiles.air.id, tiles.dirt.id, tiles.grass.id, tiles.stone.id, tiles.leaves.id, tiles.log.id
local noise = love.math.noise

local function debug(layer, t)
  t = t or stone
  return function(b)
    local d = 100
    for i = 0, layer.w - 1 do
      b:paint(i, 0, d, stone)
      b:paint(i, layer.h - 1, d, t)
    end
    for j = 0, layer.h - 1 do
      b:paint(0, j, d, stone)
      b:paint(layer.w - 1, j, d, t)
    end
  end
end

local overworld = {}
overworld.columnheight = 10
-- overworld.strategy = gen.strategy.new {
--   layers = { layer_trees, layer_terrain, layer_rock },
--   deps = { [layer_rock] = { layer_terrain }, [layer_trees] = { layer_terrain } },
-- }

overworld.layers = {
  layer_trees_sampler,
  layer_rocks_sampler,
  layer_terrain,
  layer_trees,
  layer_rocks,
  layer_caves,
}

local function carvecave(b, rng, ox, oy, oz, startradius, minradius, maxradius)
  local r = min(max(startradius, minradius), maxradius)
  local radiusdfactor = 1
  local dx, dy, dz = ox, oy, oz
  for _ = 0, 100 do
    for i = -r, r do
      for j = -r, r do
        for k = -r, r do
          if
            distance3d(i, j, k, 0, 0, 0, true) <= r * r
            and not (
              floor(dx + i) < 0
              or floor(dx + i) >= b.w
              or floor(dy + j) < 0
              or floor(dy + j) >= b.h
              or floor(dz + k) < 0
              or floor(dz + k) >= b.d
            )
          then
            b:paint(floor(dx + i), floor(dy + j), floor(dz + k), air)
          end
        end
      end
    end
    r = min(max(r + (rng:random() * 2 - 1) * radiusdfactor, minradius), maxradius)
    dx = dx + (rng:random() * 2 - 1) * 5
    dy = dy + (rng:random() * 2 - 1) * 5
    dz = dz - (rng:random()) * 1.6
  end
end

overworld.gen = {
  [layer_terrain] = function(s, b)
    local hm = love.data.newByteData(ffi.sizeof("int32_t") * size * size)
    local hmptr = ffi.cast("int32_t *", hm:getFFIPointer())
    local x, y = b.ox, b.oy
    local waterlevel = 80
    local maxlevel = 120
    local f = 0.5 / 5
    for i = 0, size - 1 do
      for j = 0, size - 1 do
        -- local oc1 = noise((x + i) * f, (y + j) * f)
        -- local oc2 = 0.5 * noise((x + i + 32313213) * f / 2, (y + j + 21111) * f / 2)
        -- local oc3 = 0.25 * noise((x + i + 32129843) * f / 4, (y + j - 23121) * f / 4)
        -- local oc4 = 0.125 * noise((x + i - 2313722) * f / 8, (y + j + 3291083) * f / 8)
        -- local h = floor((oc1 + oc2 + oc3 + oc4) * 17) + 60
        -- hmptr[i + j * size] = h
        -- b:paint(i, j, h, grass)
        -- for k = 0, h - 1 do
        --   if h - k > 5 then
        --   b:paint(i, j, k, stone)
        --   else
        --   b:paint(i, j, k, dirt)
        --   end
        -- end
        local d = nil
        for k = maxlevel, 0, -1 do
          if noise((x + i) * f, (y + j) * f, k * f) * 21 >= k - waterlevel then
            if d == nil then d = k end
            if d - k == 0 then
              b:paint(i, j, k, grass)
            elseif d - k <= 5 then
              b:paint(i, j, k, dirt)
            else
              b:paint(i, j, k, stone)
            end
          end
        end
        hmptr[i + j * size] = d or 0
      end
    end
    s[layer_terrain]:xy(x, y, { data = hm, ptr = hmptr })
  end,
  [layer_trees] = function(s, b)
    local x, y = b.ox + 2, b.oy + 2
    local hm = s[layer_terrain]:xy(x, y)
    local d = hm.ptr[x % size + (y % size) * size]

    local len = math.random(3, 8)
    local root = d + 1
    local tip = root + len

    if b:look(2, 2, d) ~= grass then return end
    for i = -2 + 2, 2 + 2 do
      for j = -2 + 2, 2 + 2 do
        for k = tip - 2, tip - 1 do
          b:paintonair(i, j, k, leaves)
        end
      end
    end

    for i = -1 + 2, 1 + 2 do
      for j = -1 + 2, 1 + 2 do
        b:paintonair(i, j, tip, leaves)
      end
    end

    b:paintonair(2, 2, tip + 1, leaves)
    b:paintonair(2 + 1, 2, tip + 1, leaves)
    b:paintonair(2 - 1, 2, tip + 1, leaves)
    b:paintonair(2, 2 + 1, tip + 1, leaves)
    b:paintonair(2, 2 - 1, tip + 1, leaves)

    for k = root, tip do
      b:paint(2, 2, k, log)
    end
  end,
  [layer_rocks] = function(s, b)
    local x, y = b.ox, b.oy
    local hm = s[layer_terrain]:xy(x, y)
    local d = hm.ptr[x % size + (y % size) * size]

    local cx, cy, cz = 2, 2, d
    local r = 2

    for i = -r, r do
      for j = -r, r do
        for k = -r, r do
          if distance3d(i, j, k, 0, 0, 0, true) <= r * r then
            b:paint(floor(cx + i), floor(cy + j), floor(cz + k), stone)
          end
        end
      end
    end
  end,
  [layer_caves] = function(s, b)
    local rng = love.math.newRandomGenerator((b.ox + b.oy))
    local ox = rng:random(0, b.w - 1)
    local oy = rng:random(0, b.h - 1)

    local x, y = b.ox + ox, b.oy + oy
    local hm = s[layer_terrain]:xy(x, y)
    local oz = hm.ptr[x % size + (y % size) * size]

    carvecave(b, rng, ox, oy, oz, 4, 2, 5)
  end,
}

function overworld:initcolumn(w, x, y)
  for k = 0, self.columnheight - 1 do
    if not w:chunk(spatialhash(x, y, k)) then w:insertchunk(chunk.new(x, y, k)) end
  end
end

function overworld:genlayer(state, layer, hunks)
  for idx = 1, #hunks, 4 do
    local x, y = hunks[idx], hunks[idx + 1]
    local w, h = hunks[idx + 2], hunks[idx + 3]

    for i = floor(x / size), floor((x + w - 1) / size) do
      for j = floor(y / size), floor((y + h - 1) / size) do
        self:initcolumn(state.w, i, j)
      end
    end

    local brush = boundedbrush(state.w, x, y, 0, w, h, self.columnheight * size)
    overworld.gen[layer](state, brush)
  end
end

function overworld:randsample(state, regions, count, layer)
  local hunks = state[layer]
  local res = {}
  for idx = 1, #regions, 4 do
    local x, y = regions[idx] / layer.w, regions[idx + 1] / layer.h
    local w, h = regions[idx + 2] / layer.w, regions[idx + 3] / layer.h
    local rng = love.math.newRandomGenerator(math.abs(x + y * 32))

    for _ = 1, count do
      local rx, ry = (x + rng:random(0, w - 1)) * layer.w, (y + rng:random(0, h - 1)) * layer.h
      local hash = spatialhash(rx / layer.w, ry / layer.h)
      if not hunks[hash] then
        hunks[hash] = true
        insert(res, rx)
        insert(res, ry)
        insert(res, layer.w)
        insert(res, layer.h)
      end
    end
  end
  return res
end

function overworld:generate(state, cx, cy, cz)
  local c = { cx * size, cy * size, size, size }
  local res = {}

  res[layer_trees] = self:randsample(state, layer_trees_sampler:sample(state, c), 100, layer_trees)
  res[layer_rocks] = self:randsample(state, layer_rocks_sampler:sample(state, c), 2, layer_rocks)
  res[layer_caves] = layer_caves:sample(state, c)
  res[layer_terrain] = layer_terrain:sample(state, concat(c, res[layer_trees], res[layer_rocks], res[layer_caves]))

  self:genlayer(state, layer_terrain, res[layer_terrain])
  self:genlayer(state, layer_caves, res[layer_caves])
  self:genlayer(state, layer_trees, res[layer_trees])
  self:genlayer(state, layer_rocks, res[layer_rocks])

  return state.w:chunk(spatialhash(cx, cy, cz))
end

return overworld
