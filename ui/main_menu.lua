local MenuStyle = require("ui.menu_style")

local MainMenu = {}
MainMenu.__index = MainMenu

function MainMenu.getStartButton()
    local x, y, w, h = MenuStyle.buttonRect(1, 1)
    return { x = x, y = y, width = w, height = h }
end

function MainMenu.draw()
    local button = MainMenu.getStartButton()

    MenuStyle.drawBackdrop(1)
    MenuStyle.drawTitle("O FIM ESTÁ PRÓXIMO", {0.78, 0.04, 0.035, 1})
    MenuStyle.drawButton("INICIAR NOVO JOGO", button, true)
end

return MainMenu
