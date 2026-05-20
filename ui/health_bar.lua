local HealthBar = {}
HealthBar.__index = HealthBar

function HealthBar.draw(x, y, width, height, current, max)
    if not current or not max or max <= 0 then
        return
    end

    local ratio = math.max(current / max, 0)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, width, height)

    love.graphics.setColor(0.9, 0.1, 0.1)
    love.graphics.rectangle(
        "fill",
        x + 1,
        y + 1,
        (width - 2) * ratio,
        height - 2
    )

    love.graphics.setColor(1, 1, 1)
end

return HealthBar