GameWorld = loex.World:extend()
local Chunk = loex.Chunk
local size = Chunk.size

local threadpool = {}
local threadusage = 0
-- load up some threads so that chunk meshing won't block the main thread
for i=1, 8 do
    threadpool[i] = love.thread.newThread "scenes/chunkremesh.lua"
end
local threadchannels = {}

local texturepack = lg.newImage "assets/texturepack.png"
local wasLeftDown, wasRightDown, rightDown, leftDown

local renderDistance = 5

-- create the mesh for the block cursor
local blockCursor, blockCursorVisible
do
    local a = -0.005
    local b = 1.005
    blockCursor = g3d.newModel{
        {a,a,a}, {b,a,a}, {b,a,a},
        {a,a,a}, {a,a,b}, {a,a,b},
        {b,a,b}, {a,a,b}, {a,a,b},
        {b,a,b}, {b,a,a}, {b,a,a},

        {a,b,a}, {b,b,a}, {b,b,a},
        {a,b,a}, {a,b,b}, {a,b,b},
        {b,b,b}, {a,b,b}, {a,b,b},
        {b,b,b}, {b,b,a}, {b,b,a},

        {a,a,a}, {a,b,a}, {a,b,a},
        {b,a,a}, {b,b,a}, {b,b,a},
        {a,a,b}, {a,b,b}, {a,b,b},
        {b,a,b}, {b,b,b}, {b,b,b},
    }
end


function GameWorld:new(playerEntity)
    GameWorld.super.new(self)
    
    self.placeQueue = {}
    self.breakQueue = {}
    self.remeshQueue = {}
    self.chunkCreationsThisFrame = 0
    self.updatedThisFrame = false

    self.player = playerEntity

    self:addEntity(playerEntity)

    lg.setMeshCullMode("back")
end

local function updateChunk(self, x, y, z)
    x = x + math.floor(g3d.camera.position[1]/size)
    y = y + math.floor(g3d.camera.position[2]/size)
    z = z + math.floor(g3d.camera.position[3]/size)
    local chunk = self:getChunk(x, y, z)
    if chunk then
        chunk.frames = 0
    end
end

function GameWorld:onChunkAdded(chunk)
    local x, y, z = chunk.cx, chunk.cy, chunk.cz
    self.chunkCreationsThisFrame = self.chunkCreationsThisFrame + 1

    self:requestRemesh(chunk)

    -- this chunk was just created, so update all the chunks around it
    self:requestRemesh(self:getChunk(x+1,y,z))
    self:requestRemesh(self:getChunk(x-1,y,z))
    self:requestRemesh(self:getChunk(x,y+1,z))
    self:requestRemesh(self:getChunk(x,y-1,z))
    self:requestRemesh(self:getChunk(x,y,z+1))
    self:requestRemesh(self:getChunk(x,y,z-1))
end

function GameWorld:onEntityAdded(entity)
    print(entity.type .. " ".. entity.id .. " added")
end

function GameWorld:onEntityRemoved(entity)
    print(entity.type .. " ".. entity.id .. " removed")
end


local netTimer = 0
function GameWorld:onUpdated(dt)

    -- collect mouse inputs
    wasLeftDown, wasRightDown = leftDown, rightDown
    leftDown, rightDown = love.mouse.isDown(1), love.mouse.isDown(2)
    leftClick, rightClick = leftDown and not wasLeftDown, rightDown and not wasRightDown

    self.updatedThisFrame = true

    for key, places in pairs(self.placeQueue) do
        if love.timer.getTime() - places.timeStamp > 0.5 then
            self:setBlockAndRemesh(places.x, places.y, places.z, 0)
            self.placeQueue[key] = nil
        end
    end

    for key, breaks in pairs(self.breakQueue) do
        if love.timer.getTime() - breaks.timeStamp > 0.5 then
            self:setBlockAndRemesh(breaks.x, breaks.y, breaks.z, breaks.prev)
            self.breakQueue[key] = nil
        end
    end

    -- -- generate a "bubble" of loaded chunks around the camera
    -- local bubbleWidth = renderDistance
    -- local bubbleHeight = math.floor(renderDistance * 0.75)
    -- local creationLimit = 1
    -- self.chunkCreationsThisFrame = 0
    -- for r=0, bubbleWidth do
    --     for a=0, math.pi*2, math.pi*2/(8*r) do
    --         local h = math.floor(math.cos(r*(math.pi/2)/bubbleWidth)*bubbleHeight + 0.5)
    --         for y=0, h do
    --             local x, z = math.floor(math.cos(a)*r + 0.5), math.floor(math.sin(a)*r + 0.5)
    --             if y ~= 0 then
    --                 updateChunk(self, x, -y, z)
    --             end
    --             updateChunk(self, x, y, z)
    --             if self.chunkCreationsThisFrame >= creationLimit then break end
    --         end
    --     end
    -- end

    -- count how many threads are being used right now
    for _, thread in ipairs(threadpool) do
        local err = thread:getError()
        assert(not err, err)
    end

    -- listen for finished meshes on the thread channels
    for channel, chunk in pairs(threadchannels) do
        local data = love.thread.getChannel(channel):pop()
        if data then
            threadchannels[channel] = nil
            if chunk.model then chunk.model.mesh:release() end
            chunk.model = nil
            chunk.inRemeshQueue = false
            if data.count > 0 then
                chunk.model = g3d.newModel(data.count, texturepack)
                chunk.model.mesh:setVertices(data.data)
                chunk.model:setTranslation(chunk.x, chunk.y, chunk.z)
            end
            threadusage = threadusage - 1 -- free up thread
        end
    end

    -- remesh the chunks in the queue
    --[[NOTE: if this happens multiple times in a frame, weird things can happen? idk why 
        NOTE(DMClVG): This was because chunks inside this loop that couldn't find a thread (due to the fact that threadusage was only recalculated every frame, and not on every started thread),
        weren't reinserted after being removed from the queue and were effectively lost ]]
    local remeshesThisFrame = #self.remeshQueue
    local remeshes = 0
    while threadusage < #threadpool and #self.remeshQueue > 0 and remeshes < remeshesThisFrame do
        local chunk = self.remeshQueue[1]
        remeshes = remeshes + 1

        if chunk and not chunk.dead then
            for _, thread in ipairs(threadpool) do
                if not thread:isRunning() then
                    table.remove(self.remeshQueue, 1)
                                        
                    -- send over the neighboring chunks to the thread
                    -- so that voxels on the edges can face themselves properly
                    local x, y, z = chunk.cx, chunk.cy, chunk.cz
                    local neighbor, n1, n2, n3, n4, n5, n6
                    neighbor = self:getChunk(x+1,y,z)
                    if neighbor then n1 = neighbor.data else table.insert(self.remeshQueue, chunk) break end
                    neighbor = self:getChunk(x-1,y,z)
                    if neighbor then n2 = neighbor.data else table.insert(self.remeshQueue, chunk) break end
                    neighbor = self:getChunk(x,y+1,z)
                    if neighbor then n3 = neighbor.data else table.insert(self.remeshQueue, chunk) break end
                    neighbor = self:getChunk(x,y-1,z)
                    if neighbor then n4 = neighbor.data else table.insert(self.remeshQueue, chunk) break end
                    neighbor = self:getChunk(x,y,z+1)
                    if neighbor then n5 = neighbor.data else table.insert(self.remeshQueue, chunk) break end
                    neighbor = self:getChunk(x,y,z-1)
                    if neighbor then n6 = neighbor.data else table.insert(self.remeshQueue, chunk) break end

                    thread:start(chunk.hash, chunk.data, chunk.size, common.Tiles.tiles, common.Tiles.tids, n1, n2, n3, n4, n5, n6)
                    threadchannels[chunk.hash] = chunk
                    threadusage = threadusage + 1 -- use up thread
                    break
                end
            end
        else
            table.remove(self.remeshQueue, 1)
        end
    end

    -- left click to destroy blocks
    -- casts a ray from the camera five blocks in the look vector
    -- finds the first intersecting block
    local vx, vy, vz = g3d.camera.getLookVector()
    local x, y, z = g3d.camera.position[1], g3d.camera.position[2], g3d.camera.position[3]
    local step = 0.1
    local floor = math.floor
    local buildx, buildy, buildz
    blockCursorVisible = false
    for i=step, 5, step do
        local bx, by, bz = floor(x + vx*i), floor(y + vy*i), floor(z + vz*i)
        local chunk = self:getChunkFromWorld(bx, by, bz)
        if chunk then
            local lx, ly, lz = bx%size, by%size, bz%size
            local tile = chunk:getBlock(lx,ly,lz)
            if tile ~= 0 then
                blockCursor:setTranslation(bx, by, bz)
                blockCursorVisible = true

                -- store the last position the ray was at
                -- as the position for building a block
                local li = i - step
                buildx, buildy, buildz = floor(x + vx*li), floor(y + vy*li), floor(z + vz*li)

                if leftClick then
                    self.breakQueue[("%d/%d/%d"):format(bx, by, bz)] = { x=bx,y=by,z=bz,timeStamp=love.timer.getTime(), prev=tile }
                    net.master:send(packets.Break(bx, by, bz), CHANNEL_EVENTS, "reliable")
                    self:setBlockAndRemesh(bx, by, bz, 0, true)
                end

                break
            end
        end
    end

    local p = self.player
    local pbox = p:getBox()
    local placedBlock = common.Tiles.bricks.id

    -- right click to place blocks
    if rightClick and buildx then
        local cube = {x=buildx+0.5, y=buildy+0.5, z=buildz+0.5, w=0.5, h=0.5, d=0.5}
        local collided = false
        for _, e in pairs(self:query(loex.entities.Player)) do
            if loex.Utils.intersectBoxAndBox(cube, e:getBox()) then
                collided = true
                break
            end
        end

        if not collided then
            local chunk = self:getChunkFromWorld(buildx, buildy, buildz)
            if chunk then
                self.placeQueue[("%d/%d/%d"):format(buildx, buildy, buildz)] = { x=buildx,y=buildy,z=buildz,timeStamp=love.timer.getTime(),placed=placedBlock }
                net.master:send(packets.Place(buildx, buildy, buildz, placedBlock), CHANNEL_EVENTS, "reliable")
                self:setBlockAndRemesh(buildx, buildy, buildz, placedBlock)
            end
        end
    end


    local speed, jumpForce = 5, 12
    local dirx, diry, dirz = g3d.camera.getLookVector()
    local move = {x=0,y=0,z=0}

    if love.keyboard.isDown("w") then
        move.x = dirx
        move.y = diry
    elseif love.keyboard.isDown("s") then
        move.x = -dirx
        move.y = -diry
    end
    
    if love.keyboard.isDown("a") then
        move.x = -diry
        move.y = dirx
    elseif love.keyboard.isDown("d") then
        move.x = diry
        move.y = -dirx
    end
    

    local mvx, mvy, _ = g3d.vectors.scalarMultiply(speed, g3d.vectors.normalize(move.x, move.y, move.z))
    p.vx = mvx
    p.vy = mvy
    p.vz = p.vz - Physics.WORLD_G * dt

    local nv, touchedGround = advanceBoxInWorld(self, pbox, {x=p.vx,y=p.vy,z=p.vz}, dt)
    p.vx = nv.x
    p.vy = nv.y
    p.vz = nv.z
    p.x = pbox.x
    p.y = pbox.y
    p.z = pbox.z

    g3d.camera.position[1] = p.x
    g3d.camera.position[2] = p.y
    g3d.camera.position[3] = p.z + 0.7
    g3d.camera.lookInDirection()

    if touchedGround and love.keyboard.isDown("space") then
        p.vz = p.vz + jumpForce
    end

    local netInterval = 1/20
    if netTimer >= netInterval then
        if p.syncX == nil or p.syncX ~= p.x or p.syncY ~= p.y or p.syncZ ~= p.z then
            p.syncX = p.x
            p.syncY = p.y
            p.syncZ = p.z
            net.master:send(packets.Move(p.x, p.y, p.z), CHANNEL_UPDATES, "unreliable")
        end
        netTimer = 0
    end
    netTimer = netTimer + dt
end

function GameWorld:mousemoved(x, y, dx, dy)
    g3d.camera.firstPersonLook(dx, dy)
end

function GameWorld:draw()
    lg.clear(lume.color "#4488ff")

    lg.setColor(1,1,1)
    for _, chunk in pairs(self.chunks) do
        chunk:draw()

        if self.updatedThisFrame then
            chunk.frames = chunk.frames + 1
            -- if chunk.frames > 100 then chunk:destroy() end
        end
    end

    self.updatedThisFrame = false

    lg.setMeshCullMode("none")
    if blockCursorVisible then
        lg.setColor(0,0,0)
        lg.setWireframe(true)
        blockCursor:draw()
        lg.setWireframe(false)
    end
    
    lg.setColor(1,1,1)
    for _, entity in pairs(self.entities) do
        entity:draw()
    end
    
    lg.setMeshCullMode("back")
end

function GameWorld:setBlockAndRemesh(x, y, z, t, neighboursFirst)
    local chunk = self:getChunkFromWorld(x, y, z)
    assert(chunk)

    local size = chunk.size
    local lx, ly, lz = x%size, y%size, z%size
    local cx, cy, cz = chunk.cx, chunk.cy, chunk.cz
    chunk:setBlock(lx, ly, lz, t)

    if neighboursFirst then
        self:requestRemesh(chunk, true)
    end
    if lx >= size-1 then self:requestRemesh(self:getChunk(cx+1,cy,cz), true) end
    if lx <= 0      then self:requestRemesh(self:getChunk(cx-1,cy,cz), true) end
    if ly >= size-1 then self:requestRemesh(self:getChunk(cx,cy+1,cz), true) end
    if ly <= 0      then self:requestRemesh(self:getChunk(cx,cy-1,cz), true) end
    if lz >= size-1 then self:requestRemesh(self:getChunk(cx,cy,cz+1), true) end
    if lz <= 0      then self:requestRemesh(self:getChunk(cx,cy,cz-1), true) end
    if not neighboursFirst then
        self:requestRemesh(chunk, true)
    end
end

function GameWorld:requestRemesh(chunk, first)
    -- don't add a nil chunk or a chunk that's already in the queue
    if not chunk or chunk.inRemeshQueue then return end
    local x, y, z = chunk.cx, chunk.cy, chunk.cz

    -- check if has neighboring chunks
    if not self:getChunk(x+1,y,z) then return end
    if not self:getChunk(x-1,y,z) then return end
    if not self:getChunk(x,y+1,z) then return end
    if not self:getChunk(x,y-1,z) then return end
    if not self:getChunk(x,y,z+1) then return end
    if not self:getChunk(x,y,z-1) then return end

    chunk.inRemeshQueue = true
    if first then
        table.insert(self.remeshQueue, 1, chunk)
    else
        table.insert(self.remeshQueue, chunk)
    end
end