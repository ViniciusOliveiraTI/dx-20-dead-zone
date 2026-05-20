local PauseMenu = {}
PauseMenu.__index = PauseMenu

function PauseMenu.draw()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(
        "Paused\nPress ESC to resume",
        0,
        love.graphics.getHeight() * 0.45,
        love.graphics.getWidth(),
        "center"
    )
end

return PauseMenu
