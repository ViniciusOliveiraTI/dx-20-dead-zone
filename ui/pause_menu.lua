local MenuStyle = require("ui.menu_style")

local PauseMenu = {}
PauseMenu.__index = PauseMenu

local function makeButton(label, index)
    local x, y, w, h = MenuStyle.buttonRect(index, 2)
    return {
        label = label,
        x = x,
        y = y,
        width = w,
        height = h
    }
end

function PauseMenu.getButtons()
    return {
        resume = makeButton("RETOMAR", 1),
        restart = makeButton("REINICIAR", 2)
    }
end

function PauseMenu.draw()
    MenuStyle.drawBackdrop(0.92)
    MenuStyle.drawTitle("JOGO PAUSADO", {0.9, 0.9, 0.84, 1})

    local buttons = PauseMenu.getButtons()
    MenuStyle.drawButton(buttons.resume.label, buttons.resume, true)
    MenuStyle.drawButton(buttons.restart.label, buttons.restart, false)
end

return PauseMenu
