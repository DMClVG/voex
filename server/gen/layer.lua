local layer = {}
local floor, insert = math.floor, table.insert
local spatialhash = loex.hash.spatial

function layer.new(w, h)
  local new = {}
  setmetatable(new, { __index = layer })
  new.w, new.h = w, h
  return new
end

function layer:sample(state, regions, pred)
  local hunks = state[self]

  local res = {}
  for r = 1, #regions, 4 do
    local x = regions[r]
    local y = regions[r + 1]
    local w = regions[r + 2]
    local h = regions[r + 3]
    for i = floor(x / self.w), floor((x + w - 1) / self.w) do
      for j = floor(y / self.h), floor((y + h - 1) / self.h) do
        if not pred or pred(i, j) then
          local hash = spatialhash(i, j)
          if not hunks[hash] then
            hunks[hash] = true
            insert(res, i * self.w)
            insert(res, j * self.h)
            insert(res, self.w)
            insert(res, self.h)
          end
        end
      end
    end
  end
  return res
end

return layer
