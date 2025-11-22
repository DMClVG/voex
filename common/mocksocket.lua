local mocksocket = {}

local function new_socket()
  return {
      onconnect = signal.new(),
      onreceive = signal.new(),
      ondisconnect = signal.new(),
      peerdatas = {},
      peerdata = function(self, peer) return self.peerdatas[peer:index()] end
  }
end

function mocksocket.new_pair()
  local client, server = new_socket(), new_socket()
  local peer_server = mockpeer.new(client)
  local peer_client =  {}
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

function 

return mocksocket
