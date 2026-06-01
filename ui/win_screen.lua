local MenuStyle = require("ui.menu_style")

local WinScreen = {}
WinScreen.__index = WinScreen

function WinScreen.getRestartButton()
    local x, y, w, h = MenuStyle.buttonRect(1, 1)
    return { x = x, y = y, width = w, height = h }
end

function WinScreen.draw()
    local button = WinScreen.getRestartButton()

    MenuStyle.drawBackdrop(0.95)
    MenuStyle.drawTitle("AMOSTRA DX RECUPERADA", {0.26, 1, 0.42, 1})
    MenuStyle.drawButton("REINICIAR JOGO", button, true)
end

return WinScreen
