local ffi = require "ffi"
local enet = require "enet"

local socket = {}
socket.__index = socket

local CHANNEL_COUNT = 5

function socket.new(enet)
    local new = {}
    new.enet = enet
    new.peers = {}

    new.onconnect = loex.signal.new()
    new.ondisconnect = loex.signal.new()
    new.onreceive = loex.signal.new()

    setmetatable(new, socket)

    return new
end

function socket.host(port, max_peers)
    local enet, err = enet.host_create(("localhost:%d"):format(port), max_peers, CHANNEL_COUNT)
    if not enet then
        error(err)
    end
    enet:compress_with_range_coder()
    return socket.new(enet)
end

function socket.connect(address)
    local enet, err = enet.host_create(nil, 1)
    if not enet then
      error(err)
    end
    enet:compress_with_range_coder()
    enet:connect(address, CHANNEL_COUNT)
    return socket.new(enet)
end

-- function socket:broadcast(data, channel, mode, dest)
--     local dest = dest or self.peers
--     for _, peer in pairs(dest) do
--         peer:send(data, channel, mode)
--     end
-- end

local function decode(packet)
    local bytedata = love.data.newByteData(packet)
    local data = ffi.cast("uint8_t *", bytedata:getFFIPointer())

    assert(data[0] == 91) -- [
    local entry = { {}, {} }
    local entryi = 1
    local out = {}
    local headersize = nil

    for i = 1, bytedata:getSize() do
        local char = string.char(data[i])
        if char == "]" then
            headersize = i + 1
            break
        elseif char == "=" then
            entryi = 2
        elseif char == ";" then
            out[table.concat(entry[1])] = table.concat(entry[2])
            entry = { {}, {} }
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

function socket:service()
    local event = self.enet:service()
    while event do
        local peerid = event.peer:index()

        local success, result = pcall(function()
            if event.type == "receive" then
                local packet = decode(event.data)
                self.onreceive:emit(self.peers[peerid], packet)
            elseif event.type == "connect" then
                local peer = {}
                setmetatable(peer, { __index = event.peer })
                self.metadata[peerid] = peer
                self.onconnect:emit(peer)
            elseif event.type == "disconnect" then
                self.ondisconnect:emit(self.peers[peerid])
                self.metadata[peerid] = nil
            end
        end)
        if not success then
            error(result) -- TODO: send error and disconnect peer
        end

        event = self.enet:service()
    end
end

function socket:disconnect()
    for _, peer in pairs(self.peers) do
        peer:disconnect()
    end
    self.enet:flush()
end

return socket
