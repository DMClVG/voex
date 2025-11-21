local ffi = require("ffi")
local enet = require("enet")

local mocksocket = {}
mocksocket.__index = mocksocket

function mocksocket.new()
   local a, b = {}, {}
   a.other = b
   b.other = a
  a.enet = enet
  b.peerdatas = {}

  setmetatable(a, mocksocket)
  setmetatable(b, mocksocket)

  return a, b
end

function mocksocket.encode(t)
  local p
  if t.bin then
    local bin = t.bin
    t.bin = nil
    p = json.encode(t)
    p = p .. bin
  else
    p = json.encode(t)
  end
  return p
end


function mocksocket.decode(p)
  local t, idx = json.decode(p)
  if idx <= #p then t.bin = string.sub(p, idx, #p) end
  return t
end

function mocksocket:peerdata(peer) return self.peerdatas[peer:index()] end

function mocksocket:service()
  local event = self.enet:service()
  while event do
    local peerid = event.peer:index()

    local success, result = pcall(function()
      if event.type == "receive" then
        local packet = mocksocket.decode(event.data)
        self.onreceive:emit(event.peer, packet)
      elseif event.type == "connect" then
        self.peerdatas[peerid] = {}
        self.onconnect:emit(event.peer)
      elseif event.type == "disconnect" then
        self.ondisconnect:emit(event.peer)
        self.peerdatas[peerid] = nil
      end
    end)
    if not success then
      error(result) -- TODO: send error and disconnect peer
    end

    event = self.enet:service()
  end
end

function mocksocket:disconnect()

end

return mocksocket
