-- @module titlescreen

local titlescreen = {}
titlescreen.__index = titlescreen

local lg = love.graphics
local signal = require("common.signal")

function titlescreen.init(app)
    local self = {}

    self.signals = {
      app.ondraw:catch(titlescreen.draw, self),
      app.onkeypressed:catch(titlescreen.keypressed, self)
    }
    
    setmetatable(self, titlescreen)
end

function titlescreen:start_game(app)
  for _, signal in ipairs(self.signals) do
    signal:destroy()
  end
  local socket_client = {
    onconnect = signal.new(),
    onreceive = signal.new(),
    ondisconnect = signal.new(),
    peerdata = {}
  }
  local socket_server = {
    onconnect = signal.new(),
    onreceive = signal.new(),
    ondisconnect = signal.new(),
    peerdata = {}
  }
  local peer_client = {}
  local peer_server = {}
  function peer_client:index() return 1 end
  function peer_server:index() return 1 end
  
  function peer_client:send(packet)
    socket_server.onreceive:emit(socket_server, peer_server, packet)
  end
  function peer_server:send(packet)
    socket_client.onreceive:emit(socket_client, peer_client, packet)
  end
  
  require("client.screens.gamescreen").init(app, peer_client)
  require("server").init(app, socket_server)
  socket_server.onconnect:emit(socket_server, peer_server)
end

function titlescreen:draw(app)
  local w, h = lg.getDimensions()
  local font = lg.getFont()
  local title = "Voex"
  lg.print(title, (w - font:getWidth(title))/2, h / 2 - 200)
  local prompt = "Press space to start"
  lg.print(prompt, (w - font:getWidth(prompt))/2, h / 2)
end

function titlescreen:keypressed(app, key)
  if key == "space" then
    self:start_game(app)
  end
end


return titlescreen
