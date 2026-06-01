local MenuStyle = require("ui.menu_style")

local GameOverScreen = {}
GameOverScreen.__index = GameOverScreen

function GameOverScreen.getRestartButton()
    local x, y, w, h = MenuStyle.buttonRect(1, 1)
    return { x = x, y = y, width = w, height = h }
end

function GameOverScreen.draw()
    local button = GameOverScreen.getRestartButton()

    MenuStyle.drawBackdrop(0.95)
    MenuStyle.drawTitle("VOCE MORREU", {0.95, 0.08, 0.05, 1})
    MenuStyle.drawButton("REINICIAR JOGO", button, true)
end

return GameOverScreen
