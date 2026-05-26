local HealthBar = {}
HealthBar.__index = HealthBar

function HealthBar.draw(x, y, width, height, current, max, orientation, reverse)
    if not current or not max or max <= 0 then
        return
    end

    local ratio = math.max(current / max, 0)
    orientation = orientation or "horizontal"
    reverse = reverse or false

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", x, y, width, height)

    love.graphics.setColor(0.9, 0.1, 0.1)

    if orientation == "vertical" then
        local fillHeight = (height - 2) * ratio
        local fillY = y + 1
        if reverse then
            fillY = y + 1 + (height - 2 - fillHeight)
        end
        love.graphics.rectangle(
            "fill",
            x + 1,
            fillY,
            width - 2,
            fillHeight
        )
    else
        local fillWidth = (width - 2) * ratio
        local fillX = x + 1
        if reverse then
            fillX = x + 1 + (width - 2 - fillWidth)
        end
        love.graphics.rectangle(
            "fill",
            fillX,
            y + 1,
            fillWidth,
            height - 2
        )
    end

    love.graphics.setColor(1, 1, 1)
end

return HealthBar