local Utils = {}

function Utils.iterBoxFloored(box)
    local x, y, z = math.floor(box.x-box.w), math.floor(box.y-box.d), math.floor(box.z-box.h)
    local a, b, c = math.floor(box.x+box.w), math.floor(box.y+box.d), math.floor(box.z+box.h)
    assert(x <= a and y <= b and z <= c, "negative box dimensions!")
    local i, j, k = x-1, y, z
    return function()
        i = i + 1
        if i > a then
            i = x
            j = j + 1
            if j > b then
                j = y
                k = k + 1
                if k > c then
                    return nil
                end
            end
        end
        return i, j, k
    end
end

function Utils.intersectBoxAndBox(a, b)
    return  a.x + a.w > b.x - b.w and a.x - a.w < b.x + b.w and
            a.y + a.d > b.y - b.d and a.y - a.d < b.y + b.d and
            a.z + a.h > b.z - b.h and a.z - a.h < b.z + b.h
end

function Utils.expand(box, ex, ey, ez)
    local hex, hey, hez = ex/2, ey/2, ez/2
    box.x = box.x + hex
    box.y = box.y + hey
    box.z = box.z + hez

    box.w = box.w + math.abs(hex)
    box.d = box.d + math.abs(hey)
    box.h = box.h + math.abs(hez)
    return box
end

return Utils