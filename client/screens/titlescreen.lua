-- @module titlescreen

local titlescreen = {}
titlescreen.__index = titlescreen

local lg = love.graphics

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
  local a, b = require("common.mocksocket").new()
  require("client.screens.gamescreen").init(app, b)
  require("server").init(app, a)
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
