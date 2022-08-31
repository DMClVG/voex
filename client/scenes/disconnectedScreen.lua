local DisconnectedScreen = {}
local g = love.graphics

function DisconnectedScreen:update(dt)

end

function DisconnectedScreen:draw()
    local msg = "Disconnected :("
    g.clear(1, 0, 0)
    local w, h = g.getWidth(), g.getHeight()

    w = w - g.getFont():getWidth(msg)
    h = h - g.getFont():getHeight()

    g.print(msg,w/2,h/2)
end

function DisconnectedScreen:mousemoved()

end

return DisconnectedScreen