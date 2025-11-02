local client = {}

function client.init(game, socket, username)
  game.gravity = 42 -- TODO

  game.socket = socket
  game.username = username

  local font = love.graphics.newFont(23)
  love.graphics.setFont(font)

  require("screens.joinscreen").init(game)
end

return client
