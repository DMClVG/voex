local client = {}

g3d = require("client/lib/g3d")

function client.init(app)
  local font = love.graphics.newFont(23)
  love.graphics.setFont(font)

  require("client.screens.titlescreen").init(app)
end

return client
