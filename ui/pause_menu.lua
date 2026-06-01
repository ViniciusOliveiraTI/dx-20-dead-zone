local MenuStyle = require("ui.menu_style")

local PauseMenu = {}
PauseMenu.__index = PauseMenu

local function makeButton(label, index)
    local x, y, w, h = MenuStyle.buttonRect(index, 4)
    return {
        label = label,
        x = x,
        y = y,
        width = w,
        height = h
    }
end

local function makeSlider(id, label, value, index)
    local width = 360
    local height = 28
    local x = (love.graphics.getWidth() - width) / 2
    local y = love.graphics.getHeight() / 2 - 38 + (index - 1) * 58

    return {
        id = id,
        label = label,
        value = value or 0,
        x = x,
        y = y,
        width = width,
        height = height
    }
end

function PauseMenu.getButtons()
    return {
        resume = makeButton("RETOMAR", 3),
        restart = makeButton("REINICIAR", 4)
    }
end

function PauseMenu.getSliders(audioManager)
    local musicVolume = audioManager and audioManager:getMusicVolume() or 0
    local sfxVolume = audioManager and audioManager:getSFXVolume() or 0

    return {
        music = makeSlider("music", "MUSICA", musicVolume, 1),
        sfx = makeSlider("sfx", "EFEITOS", sfxVolume, 2)
    }
end

local function drawSlider(slider)
    local value = math.max(0, math.min(1, slider.value or 0))
    local fillW = slider.width * value
    local knobX = slider.x + fillW

    love.graphics.setColor(0.02, 0.025, 0.03, 0.84)
    love.graphics.rectangle("fill", slider.x - 18, slider.y - 18, slider.width + 36, 62, 8, 8)

    love.graphics.setColor(0.78, 0.82, 0.78, 0.86)
    love.graphics.printf(slider.label, slider.x, slider.y - 12, 120, "left")
    love.graphics.printf(string.format("%d%%", value * 100), slider.x + slider.width - 80, slider.y - 12, 80, "right")

    love.graphics.setColor(0.18, 0.19, 0.19, 1)
    love.graphics.rectangle("fill", slider.x, slider.y + 16, slider.width, 6, 3, 3)

    love.graphics.setColor(0.78, 0.08, 0.06, 1)
    love.graphics.rectangle("fill", slider.x, slider.y + 16, fillW, 6, 3, 3)

    love.graphics.setColor(0.96, 0.96, 0.92, 1)
    love.graphics.circle("fill", knobX, slider.y + 19, 10)
    love.graphics.setColor(0.78, 0.08, 0.06, 1)
    love.graphics.circle("line", knobX, slider.y + 19, 10)
end

function PauseMenu.sliderValueAt(slider, x)
    return math.max(0, math.min(1, (x - slider.x) / slider.width))
end

function PauseMenu.pointInSlider(x, y, slider)
    return slider
        and x >= slider.x - 18
        and x <= slider.x + slider.width + 18
        and y >= slider.y - 18
        and y <= slider.y + 44
end

function PauseMenu.draw(audioManager)
    MenuStyle.drawBackdrop(0.92)
    MenuStyle.drawTitle("JOGO PAUSADO", {0.9, 0.9, 0.84, 1})

    local sliders = PauseMenu.getSliders(audioManager)
    drawSlider(sliders.music)
    drawSlider(sliders.sfx)

    local buttons = PauseMenu.getButtons()
    MenuStyle.drawButton(buttons.resume.label, buttons.resume, true)
    MenuStyle.drawButton(buttons.restart.label, buttons.restart, false)
end

return PauseMenu
