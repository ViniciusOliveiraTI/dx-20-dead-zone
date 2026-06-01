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

function HealthBar.drawPlayerFrame(x, y, width, height, current, max)
    if not current or not max or max <= 0 then
        return
    end

    local ratio = math.max(0, math.min(1, current / max))
    local panelH = height + 32
    local barX = x + 14
    local barY = y + 28
    local barW = width - 28
    local barH = height
    local fillColor = {0.25, 0.9, 0.45}
    if ratio <= 0.3 then
        fillColor = {0.95, 0.18, 0.12}
    elseif ratio <= 0.6 then
        fillColor = {0.95, 0.68, 0.18}
    end

    love.graphics.setColor(0.015, 0.018, 0.022, 0.86)
    love.graphics.rectangle("fill", x, y, width, panelH, 7, 7)
    love.graphics.setColor(0.18, 0.22, 0.28, 0.95)
    love.graphics.rectangle("line", x, y, width, panelH, 7, 7)

    love.graphics.setColor(0.68, 0.74, 0.82, 1)
    love.graphics.print("VIDA", x + 14, y + 8)
    love.graphics.setColor(0.94, 0.96, 0.92, 1)
    love.graphics.printf(string.format("%d / %d", current, max), x, y + 8, width - 14, "right")

    love.graphics.setColor(0.045, 0.052, 0.065, 1)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)

    local fillW = math.max(0, barW * ratio)
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], 0.96)
    love.graphics.rectangle("fill", barX, barY, fillW, barH, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.16)
    love.graphics.rectangle("fill", barX, barY, fillW, math.max(2, barH * 0.35), 4, 4)

    love.graphics.setColor(0.14, 0.17, 0.21, 0.85)
    for i = 1, 9 do
        local tx = barX + i * (barW / 10)
        love.graphics.rectangle("fill", tx, barY, 2, barH)
    end

    love.graphics.setColor(0.26, 0.32, 0.38, 1)
    love.graphics.rectangle("line", barX, barY, barW, barH, 4, 4)

    love.graphics.setColor(1, 1, 1, 1)
end

return HealthBar
