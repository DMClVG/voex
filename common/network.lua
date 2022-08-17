local Network = Object:extend()
local ffi = require "ffi"

function Network:new(enet)
    self.enet = enet
    self.users = {}
    self.peers = {}

    self.onPeerConnect = function(peer, user) end
    self.onPeerDisconnect = function(peer, user) end
    self.onPeerReceive = function(peer, user, data) end
end

function Network.host(port)
    local enet = enet.host_create(("localhost:%d"):format(port))
    enet:compress_with_range_coder()    
    return Network(enet)
end

function Network:broadcast(data, channel, mode, dest)
    local dest = dest or self.peers
    for _, peer in pairs(dest) do
        peer:send(data, channel, mode)
    end
end

function Network.connect(address)
    local enet = enet.host_create()
    enet:compress_with_range_coder()
    enet:connect(address)

    return Network(enet)
end

local function decodePacket(packet)
    local bytedata = love.data.newByteData(packet)
    local data = ffi.cast("uint8_t *", bytedata:getFFIPointer())

    assert(data[0] == 91) -- [
    local entry = {{}, {}}
    local entryi = 1
    local out = {}
    local headersize = nil

    for i=1,bytedata:getSize() do
        local char = string.char(data[i])
        if char == "]" then
            headersize = i + 1
            break
        elseif char == "=" then
            entryi = 2
        elseif char == ";" then
            out[table.concat(entry[1])] = table.concat(entry[2])
            entry = {{}, {}}
            entryi = 1
        else
            table.insert(entry[entryi], char)
        end
    end

    local binsize = bytedata:getSize() - headersize
    if binsize ~= 0 then
        out.bin = love.data.newDataView(bytedata, headersize, binsize)
    end

    return out
end

function Network:service()
    while true do
        local event = self.enet:service()
        if not event then
            break
        end

        local peer = event.peer
        local id = peer:connect_id()

        if event.type == "receive" then
            local packet = decodePacket(event.data)
            self.onPeerReceive(peer, self.users[id], packet)
        elseif event.type == "connect" then
            local user = { id=id }
            self.users[id] = user
            self.peers[id] = peer

            self.onPeerConnect(peer, user)
        elseif event.type == "disconnect" then
            self.onPeerDisconnect(peer, self.users[id])
            self.users[id] = nil
            self.peers[id] = nil
        end
    end
end


function Network:disconnect()
    for _, peer in pairs(self.peers) do
        peer:disconnect()
    end
end

return Network