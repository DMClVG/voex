local mockpeer = {}
mockpeer.__index = mockpeer

function mockpeer.new(other_socket, other_peer)
  local self = {
    other_socket = b,
    
  }
  return setmetatable(self, mockpeer)
end

function mockpeer:send(packet)
  self.other_socket.onreceive:emit(self.other_socket, self.other_peer, packet)
end

return mockpeer
