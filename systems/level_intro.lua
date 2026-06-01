local LevelIntro = {}
LevelIntro.__index = LevelIntro

function LevelIntro.new()
    local self = setmetatable({}, LevelIntro)
    self.active = false
    self.elapsed = 0
    self.duration = 5
    self.title = ""
    self.description = ""
    self.titleFont = love.graphics.newFont(30)
    self.descriptionFont = love.graphics.newFont(15)
    return self
end

function LevelIntro:show(title, description)
    self.active = true
    self.elapsed = 0
    self.title = title or ""
    self.description = description or ""
end

function LevelIntro:update(dt)
    if not self.active then
        return
    end

    self.elapsed = self.elapsed + dt
    if self.elapsed >= self.duration then
        self.active = false
    end
end

local function alphaCurve(t)
    if t < 0.32 then
        return t / 0.32
    elseif t > 0.72 then
        return 1 - ((t - 0.72) / 0.28)
    end

    return 1
end

function LevelIntro:draw()
    if not self.active then
        return
    end

    local t = math.min(1, self.elapsed / self.duration)
    local alpha = math.max(0, math.min(1, alphaCurve(t)))
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local centerY = sh * 0.44
    local panelW = math.min(sw - 72, 560)
    local panelH = 118
    local panelX = (sw - panelW) / 2
    local panelY = centerY - panelH / 2
    local oldFont = love.graphics.getFont()

    love.graphics.setColor(0, 0, 0, 0.22 * alpha)
    love.graphics.rectangle("fill", 0, centerY - 90, sw, 180)

    love.graphics.setColor(0.03, 0.035, 0.04, 0.68 * alpha)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)

    love.graphics.setColor(0.82, 0.9, 1, 0.22 * alpha)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)

    love.graphics.setColor(0.78, 0.08, 0.06, 0.9 * alpha)
    love.graphics.rectangle("fill", panelX + 34, panelY + 24, panelW - 68, 2)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(0.96, 0.96, 0.92, alpha)
    love.graphics.printf(self.title, panelX + 24, panelY + 36, panelW - 48, "center")

    love.graphics.setFont(self.descriptionFont)
    love.graphics.setColor(0.72, 0.78, 0.78, 0.92 * alpha)
    love.graphics.printf(self.description, panelX + 34, panelY + 78, panelW - 68, "center")

    love.graphics.setFont(oldFont)
    love.graphics.setColor(1, 1, 1, 1)
end

return LevelIntro
