local gameworld = {}
local size = loex.chunk.size
local floor = math.floor
local threadpool = {}
local threadusage = 0
-- load up some threads so that chunk meshing won't block the main thread
for i = 1, 8 do
  threadpool[i] = love.thread.newThread("scenes/chunkremesh.lua")
end
local texturepack = lg.newImage("assets/texturepack.png")

local mouse = {} -- mouse state
local playerbox = {
  x = 0,
  y = 0,
  z = 0,
  w = 0.3,
  d = 0.3,
  h = 0.6,
}

local playerobj = g3d.newModel("assets/player.obj", "assets/saul.png")

-- create the mesh for the block cursor
local cursor, cursormodel

do
  local a = -0.005
  local b = 1.005
  cursormodel = g3d.newModel {
    { a, a, a },
    { b, a, a },
    { b, a, a },
    { a, a, a },
    { a, a, b },
    { a, a, b },
    { b, a, b },
    { a, a, b },
    { a, a, b },
    { b, a, b },
    { b, a, a },
    { b, a, a },

    { a, b, a },
    { b, b, a },
    { b, b, a },
    { a, b, a },
    { a, b, b },
    { a, b, b },
    { b, b, b },
    { a, b, b },
    { a, b, b },
    { b, b, b },
    { b, b, a },
    { b, b, a },

    { a, a, a },
    { a, b, a },
    { a, b, a },
    { b, a, a },
    { b, b, a },
    { b, b, a },
    { a, a, b },
    { a, b, b },
    { a, b, b },
    { b, a, b },
    { b, b, b },
    { b, b, b },
  }
end

function gameworld:init(player)
  self.master = master
  local world = loex.world.new()
  world.ontilemodified:catch(self.ontilemodified, self)
  world.onentityinserted:catch(self.onentityinserted, self)
  world.onentityremoved:catch(self.onentityremoved, self)
  world.onchunkinserted:catch(self.onchunkinserted, self)
  world.onchunkremoved:catch(self.onchunkremoved, self)

  self.world = world

  self.placequeue = {}
  self.breakqueue = {}
  self.remeshqueue = {}
  self.remeshchannel = love.thread.newChannel()
  self.frameremeshes = 0
  self.synctimer = 0

  self.player = player
  self.player:tag("player")

  self.world:insert(self.player)

  lg.setMeshCullMode("back")
end

function gameworld:onchunkinserted(chunk)
  local x, y, z = chunk.x, chunk.y, chunk.z
  self:requestremesh(chunk)
end

function gameworld:onchunkremoved(chunk) end
function gameworld:onentityinserted(entity) print(entity.id .. " added") end

function gameworld:onentityremoved(entity) print(entity.id .. " removed") end

function gameworld:update(dt)
  local world = self.world
  -- collect mouse inputs
  mouse.wasleft, mouse.wasright = mouse.left, mouse.right
  mouse.left, mouse.right = love.mouse.isDown(1), love.mouse.isDown(2)
  mouse.leftclick, mouse.rightclick = mouse.left and not mouse.wasleft, mouse.right and not mouse.wasright

  local lagdelay = 0.5
  -- handle place and break timeouts
  for key, places in pairs(self.placequeue) do
    if love.timer.getTime() - places.timestamp > lagdelay then
      self.world:tile(places.x, places.y, places.z, loex.tiles.air.id)
      self.placequeue[key] = nil
    end
  end

  for key, breaks in pairs(self.breakqueue) do
    if love.timer.getTime() - breaks.timestamp > lagdelay then
      self.world:tile(breaks.x, breaks.y, breaks.z, breaks.prev)
      self.breakqueue[key] = nil
    end
  end

  -- count how many threads are being used right now
  for _, thread in ipairs(threadpool) do
    local err = thread:getError()
    assert(not err, err)
  end

  -- listen for finished meshes on the thread channels
  while self.remeshchannel:peek() do
    local data = self.remeshchannel:pop()
    if not data then break end
    local c = self.world:chunk(loex.hash.spatial(data.cx, data.cy, data.cz))
    if c.model then c.model.mesh:release() end
    c.model = nil
    c.inremesh = false
    if data.count > 0 then
      c.model = g3d.newModel(data.count, texturepack)
      c.model.mesh:setVertices(data.data)
      c.model:setTranslation(data.cx * size, data.cy * size, data.cz * size)
    end
    threadusage = threadusage - 1 -- free up thread
  end

  -- remesh the chunks in the queue
  local remeshesquota = #self.remeshqueue
  local remeshes = 0
  local offi = 0

  while threadusage < #threadpool and #self.remeshqueue > 0 and remeshes < remeshesquota do
    local c = self.remeshqueue[1 + offi]
    remeshes = remeshes + 1

    for _, thread in ipairs(threadpool) do
      if not thread:isRunning() then
        -- send over the neighboring chunks to the thread
        -- so that voxels on the edges can face themselves properly
        local n1, n2, n3, n4, n5, n6 = world:neighbourhood(c.x, c.y, c.z)
        if not (n1 and n2 and n3 and n4 and n5 and n6) then
          offi = offi + 1
          break
        end

        n1, n2, n3, n4, n5, n6 = n1.data, n2.data, n3.data, n4.data, n5.data, n6.data
        thread:start(self.remeshchannel, c.x, c.y, c.z, c.data, size, loex.tiles.id, n1, n2, n3, n4, n5, n6)
        table.remove(self.remeshqueue, 1 + offi)
        threadusage = threadusage + 1 -- use up thread
        break
      end
    end
  end

  local keyboard = love.keyboard
  local speed, jumpforce, gravity = 5, 12, 42
  local dirx, diry, dirz = g3d.camera.getLookVector()
  local move = { x = 0, y = 0, z = 0 }
  local p = self.player

  if keyboard.isDown("w") then
    move.x = dirx
    move.y = diry
  elseif keyboard.isDown("s") then
    move.x = -dirx
    move.y = -diry
  end

  if keyboard.isDown("a") then
    move.x = -diry
    move.y = dirx
  elseif keyboard.isDown("d") then
    move.x = diry
    move.y = -dirx
  end

  p.vx, p.vy, _ = g3d.vectors.scalarMultiply(speed, g3d.vectors.normalize(move.x, move.y, move.z))
  p.vz = p.vz - gravity * dt

  local onground = moveandcollide(self.world, p, playerbox, dt)

  g3d.camera.position[1] = p.x
  g3d.camera.position[2] = p.y
  g3d.camera.position[3] = p.z + 0.7
  g3d.camera.lookInDirection()

  if onground and keyboard.isDown("space") then p.vz = p.vz + jumpforce end

  local syncinterval = 1 / 20
  self.synctimer = self.synctimer + dt
  if self.synctimer >= syncinterval then
    self.master:send(packets.move(p.x, p.y, p.z), CHANNEL_UPDATES, "unreliable")
    self.synctimer = 0
  end

  -- casts a ray from the camera five blocks in the look vector
  -- finds the first intersecting block
  cursor = nil
  do
    local dx, dy, dz = g3d.camera.getLookVector()
    local ox, oy, oz = g3d.camera.position[1], g3d.camera.position[2], g3d.camera.position[3]
    local step = 0.1
    for i = step, 5, step do
      local x, y, z = floor(ox + dx * i), floor(oy + dy * i), floor(oz + dz * i)
      local tile = world:tile(x, y, z)
      if tile > 0 then
        local li = i - step
        cursor = {}
        cursor.placex, cursor.placey, cursor.placez = floor(ox + dx * li), floor(oy + dy * li), floor(oz + dz * li)
        cursor.x, cursor.y, cursor.z = x, y, z
        break
      end
    end
  end

  local placetile = loex.tiles.bricks.id

  if mouse.leftclick and cursor then
    local x, y, z = cursor.x, cursor.y, cursor.z
    self.breakqueue[("%d/%d/%d"):format(x, y, z)] = {
      x = x,
      y = y,
      z = z,
      timestamp = love.timer.getTime(),
      prev = self.world:tile(x, y, z),
    }
    self.master:send(packets.breaktile(x, y, z), CHANNEL_EVENTS, "reliable")
    self.world:tile(x, y, z, loex.tiles.air.id)
  end

  -- right click to place blocks
  if mouse.rightclick and cursor then
    local x, y, z = cursor.placex, cursor.placey, cursor.placez
    local cube = { x = x + 0.5, y = y + 0.5, z = z + 0.5, w = 0.5, h = 0.5, d = 0.5 }
    local translatedplayerbox = lume.clone(playerbox)
    translatedplayerbox.x = translatedplayerbox.x + p.x
    translatedplayerbox.y = translatedplayerbox.y + p.y
    translatedplayerbox.z = translatedplayerbox.z + p.z
    if not loex.utils.intersectbb(cube, translatedplayerbox) then
      self.placequeue[("%d/%d/%d"):format(x, y, z)] = {
        x = x,
        y = y,
        z = z,
        timestamp = love.timer.getTime(),
        t = placetile,
      }
      self.master:send(packets.place(x, y, z, placetile), CHANNEL_EVENTS, "reliable")
      self.world:tile(x, y, z, placetile)
    end
  end
end

function gameworld:draw()
  lg.clear(lume.color("#4488ff"))

  lg.setColor(1, 1, 1)
  for _, chunk in pairs(self.world.chunks) do
    if chunk.model then chunk.model:draw() end
  end

  lg.setMeshCullMode("none")
  if cursor then
    lg.setColor(0, 0, 0)
    lg.setWireframe(true)
    cursormodel:setTranslation(cursor.x, cursor.y, cursor.z)
    cursormodel:draw()
    lg.setWireframe(false)
  end

  local camera = g3d.camera.position
  lg.setColor(1, 1, 1)
  for _, entity in pairs(self.world.entities) do
    if entity ~= self.player then
      playerobj:setTranslation(entity.x, entity.y, entity.z - 0.9)
      playerobj:setRotation(0, 0, math.atan2(entity.y - camera[2], entity.x - camera[1]))
      playerobj:setScale(0.1, 1, 0.6)
      playerobj:draw()
    end
  end

  lg.setMeshCullMode("back")
end

function gameworld:mousemoved(x, y, dx, dy) g3d.camera.firstPersonLook(dx, dy) end

function gameworld:ontilemodified(x, y, z, _)
  local spatial = loex.hash.spatial
  local chunk = self.world:chunk(spatial(floor(x / size), floor(y / size), floor(z / size)))
  assert(chunk)

  local tx, ty, tz = x % size, y % size, z % size
  local cx, cy, cz = chunk.x, chunk.y, chunk.z
  local world = self.world

  if tx >= size - 1 then self:requestremesh(world:chunk(spatial(cx + 1, cy, cz)), true) end
  if tx <= 0 then self:requestremesh(world:chunk(spatial(cx - 1, cy, cz)), true) end
  if ty >= size - 1 then self:requestremesh(world:chunk(spatial(cx, cy + 1, cz)), true) end
  if ty <= 0 then self:requestremesh(world:chunk(spatial(cx, cy - 1, cz)), true) end
  if tz >= size - 1 then self:requestremesh(world:chunk(spatial(cx, cy, cz + 1)), true) end
  if tz <= 0 then self:requestremesh(world:chunk(spatial(cx, cy, cz - 1)), true) end

  self:requestremesh(chunk, true)
end

function gameworld:requestremesh(c, priority)
  -- don't add a nil chunk or a chunk that's already in the queue
  local world = self.world
  if not c or c.inremesh then return end

  c.inremesh = true
  if priority then
    table.insert(self.remeshqueue, 1, c)
  else
    table.insert(self.remeshqueue, c)
  end
end

return gameworld
