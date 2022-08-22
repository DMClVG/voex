local JoinScreen = {}
local g = love.graphics

function JoinScreen:init()
    g.setNewFont(20)
end

function JoinScreen:update(dt)

end

function JoinScreen:draw()
    local w, h = g.getWidth(), g.getHeight()

    local msg = "Joining"

    for i=1,math.floor(love.timer.getTime()) % 4 do
        msg = msg .. "."
    end

    w = w - g.getFont():getWidth(msg)
    h = h - g.getFont():getHeight()

    g.print(msg,w/2,h/2)
end

function JoinScreen:mousemoved()

end

return JoinScreen