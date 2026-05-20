local Collision = {}

function Collision.checkAABB(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and
           ax + aw > bx and
           ay < by + bh and
           ay + ah > by
end

function Collision.checkCircleOverlap(x1, y1, r1, x2, y2, r2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy <= (r1 + r2) * (r1 + r2)
end

function Collision.checkCircleRectDistance(cx, cy, radius, rx, ry, rw, rh)
    -- Center of rect
    local rcx = rx + rw / 2
    local rcy = ry + rh / 2
    local dx = cx - rcx
    local dy = cy - rcy
    return dx * dx + dy * dy <= (radius + math.max(rw, rh) / 2) ^ 2
end

return Collision