local JoinFailedScreen = {}
local g = love.graphics

local msg
function JoinFailedScreen:init(cause)
    g.setNewFont(20)
    msg = cause
end

function JoinFailedScreen:update(dt)

end

function JoinFailedScreen:draw()
    g.clear(1, 0, 0)
    local w, h = g.getWidth(), g.getHeight()

    w = w - g.getFont():getWidth(msg)
    h = h - g.getFont():getHeight()

    g.print(msg,w/2,h/2)
end

function JoinFailedScreen:mousemoved()

end

return JoinFailedScreen