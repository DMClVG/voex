local nethandler = {}

function nethandler.joinsuccess(_, d)
  local spawnx, spawny, spawnz = tonumber(d.x), tonumber(d.y), tonumber(d.z)
  assert(d.id)
  local player = loex.entity.new(spawnx, spawny, spawnz, d.id)
  player.username = username

  print(
    ("Joined under username " .. player.username .. " (ID: " .. player.id .. ") at spawn point %d, %d, %d"):format(
      spawnx,
      spawny,
      spawnz
    )
  )

  scene(require("scenes/gameworld"), player)
end

function nethandler.joinfailure(_, d) scene(require("scenes/errorscreen"), d.cause) end

function nethandler.broken(g, d)
  local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
  local hash = ("%d/%d/%d"):format(x, y, z)
  if not g.breakqueue[hash] then g.world:tile(x, y, z, loex.tiles.air.id, true) end
  g.breakqueue[hash] = nil
end

function nethandler.placed(g, d)
  local x, y, z, t = tonumber(d.x), tonumber(d.y), tonumber(d.z), tonumber(d.t)
  local hash = ("%d/%d/%d"):format(x, y, z)
  if not g.placequeue[hash] or g.placequeue[hash].placed ~= t then g.world:tile(x, y, z, t) end
  g.placequeue[hash] = nil
end

function nethandler.entitymove(g, d)
  assert(false)
  local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
  local entity = g.world:entity(d.id)
  assert(entity)
  entity.x = x
  entity.y = y
  entity.z = z
end

function nethandler.entityadd(g, d)
  if d.id == g.player.id then return end

  local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
  local entity = loex.entity.new(x, y, z, d.id)
  g.world:insert(entity)
end

function nethandler.entityremove(g, d) g.world:remove(d.id) end

function nethandler.entityremoteset(g, d)
  local entity = g.world:entity(d.id)
  if entity.id == g.player.id and d.property:match("[xyz]") then return end -- TODO: position correction
  entity[d.property] = d.value
end

function nethandler.chunkadd(g, d)
  local expectedsize = loex.chunk.size ^ 3
  local cx, cy, cz = tonumber(d.cx), tonumber(d.cy), tonumber(d.cz)
  local c = loex.chunk.new(cx, cy, cz)
  if d.bin then
    assert(
      d.bin:getSize() == expectedsize,
      ("Chunk data of wrong size! Expected %d bytes, got %d bytes"):format(expectedsize, d.bin:getSize())
    )
    c:init(d.bin)
  end
  g.world:insertchunk(c)
end

function nethandler.chunkremove(g, d)
  local cx, cy, cz = tonumber(d.cx), tonumber(d.cy), tonumber(d.cz)
  g.world:removechunk(loex.hash.spatial(cx, cy, cz)):destroy()
end

return nethandler
