local MenuStyle = {}

local titleFont
local subtitleFont
local buttonFont

local function ensureFonts()
    titleFont = titleFont or love.graphics.newFont(46)
    subtitleFont = subtitleFont or love.graphics.newFont(18)
    buttonFont = buttonFont or love.graphics.newFont(22)
end

function MenuStyle.buttonRect(index, count)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local buttonW, buttonH = 300, 46
    local gap = 14
    local totalH = count * buttonH + (count - 1) * gap
    local startY = h * 0.61 - totalH / 2
    return w / 2 - buttonW / 2, startY + (index - 1) * (buttonH + gap), buttonW, buttonH
end

function MenuStyle.drawBackdrop(alpha)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    alpha = alpha or 1

    love.graphics.setColor(0.006, 0.008, 0.01, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.07, 0.075, 0.08, 0.55 * alpha)
    love.graphics.rectangle("fill", 0, 0, w, h * 0.58)

    love.graphics.setColor(0.13, 0.01, 0.01, 0.42 * alpha)
    love.graphics.rectangle("fill", 0, h * 0.58, w, h * 0.42)

    love.graphics.setColor(0.5, 0.02, 0.015, 0.75 * alpha)
    love.graphics.rectangle("fill", w * 0.25, h * 0.57, w * 0.5, 2)

    love.graphics.setColor(1, 0.12, 0.04, 0.65 * alpha)
    for i = 1, 12 do
        local x = ((i * 97) % math.max(w, 1))
        local y = h * 0.35 + ((i * 53) % math.max(h * 0.6, 1))
        love.graphics.line(x, y, x + 12, y - 22)
    end
end

function MenuStyle.drawTitle(statusText, statusColor)
    ensureFonts()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local oldFont = love.graphics.getFont()

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.02, 0.02, 0.02, 0.85)
    love.graphics.printf("DX-20: Dead Zone", 3, h * 0.18 + 3, w, "center")
    love.graphics.setColor(0.92, 0.92, 0.86, 1)
    love.graphics.printf("DX-20: Dead Zone", 0, h * 0.18, w, "center")

    love.graphics.setColor(0.78, 0.04, 0.035, 1)
    love.graphics.rectangle("fill", w / 2 - 205, h * 0.18 + 55, 410, 3)

    love.graphics.setFont(subtitleFont)
    if statusText then
        local color = statusColor or {0.78, 0.04, 0.035, 1}
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        love.graphics.printf(statusText, 0, h * 0.18 + 76, w, "center")
    end

    love.graphics.setFont(oldFont)
end

function MenuStyle.drawButton(label, rect, selected)
    ensureFonts()
    local oldFont = love.graphics.getFont()
    local x, y, w, h = rect.x, rect.y, rect.width, rect.height

    if selected then
        love.graphics.setColor(0.72, 0.02, 0.02, 0.96)
    else
        love.graphics.setColor(0.07, 0.07, 0.065, 0.92)
    end
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)

    love.graphics.setColor(0.5, 0.02, 0.02, 0.9)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)

    love.graphics.setFont(buttonFont)
    love.graphics.setColor(0.95, 0.95, 0.9, 1)
    love.graphics.printf(label, x, y + 11, w, "center")

    love.graphics.setFont(oldFont)
end

return MenuStyle
