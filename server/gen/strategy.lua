local strategy = {}

local function append(a, b)
  for i = 1, #b do
    a[#a + 1] = b[i]
  end
  return a
end

function strategy.new(opts)
  local new = {}
  new.layers = opts.layers
  new.deps = opts.deps or {}
  for _, layer in ipairs(new.layers) do
    if not new.deps[layer] then new.deps[layer] = {} end
  end
  setmetatable(new, { __index = strategy })
  return new
end

function strategy:sample(state, x, y, w, h)
  local res = {}

  for _, layer in ipairs(self.layers) do
    local segments = layer:sample(state, x, y, w, h)
    append(res, segments)
    for _, dep in ipairs(self.deps[layer]) do
      for _, s in ipairs(segments) do
        append(res, dep:sample(state, s[2] * layer.w, s[3] * layer.h, layer.w, layer.h))
      end
    end
  end

  return res
end

return strategy
