local Player = loex.Entity:extend()
Player.type = "Player"

local obj, quad
if not IS_SERVER then
    obj = g3d.newModel("assets/player.obj", "assets/saul.png")
    quad = g3d.newModel("assets/quad.obj")
end


function Player:remoteSpawn(data)
    self.username = data.username
end

function Player:remoteExtras()
    return { username=self.username }
end

function Player:update()
    
end

function Player:getBox()
    return {x=self.x,y=self.y,z=self.z, w=0.3,h=0.9,d=0.3}
end

local g = love.graphics
function Player:draw()
    if self.usernameTag == nil then
        print(font:getHeight())
        local canvas = g.newCanvas(font:getWidth(self.username), font:getHeight())
        g.setCanvas(canvas)
        g.setFont(font)
        g.print(self.username, 0, 0)
        g.setCanvas()
        self.usernameTag = canvas
    end

    local unitPerPixel = 0.004

    g.setColor(1, 1, 1)
    local camera = g3d.camera.position
    if self ~= loex.World.singleton.player then
        obj:setTranslation(self.x, self.y, self.z-0.9)
        obj:setRotation(0, 0, math.atan2(self.y-camera[2], self.x-camera[1]))
        obj:setScale(0.1, 1, 0.6)
        obj:draw()

        quad:setScale(1, unitPerPixel*self.usernameTag:getWidth(), unitPerPixel*self.usernameTag:getHeight())
        quad:setTranslation(self.x, self.y, self.z + 1.9)
        quad:setRotation(0, 0, math.atan2(self.y-camera[2], self.x-camera[1]))
        quad.mesh:setTexture(self.usernameTag)
        quad:draw()
    end
end

return Player