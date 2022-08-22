local Player = loex.Entity:extend()
Player.type = "Player"

local obj
if not IS_SERVER then
    obj = g3d.newModel("assets/player.obj", "assets/saul.png")
end

function Player:update()
    
end

function Player:getBox()
    return {x=self.x,y=self.y,z=self.z, w=0.3,h=0.9,d=0.3}
end

local g = love.graphics
function Player:draw()
    g.setColor(1, 1, 1)
    local camera = g3d.camera.position
    if self ~= loex.World.singleton.player then
        obj:setScale(0.1, 1, 0.6)
        obj:setTranslation(self.x, self.y, self.z-0.9)
        obj:setRotation(0, 0, math.atan2(self.y-camera[2], self.x-camera[1]))
        obj:draw()
    end
end

return Player