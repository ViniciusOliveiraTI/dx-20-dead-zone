local GameOverScreen = {}
GameOverScreen.__index = GameOverScreen

function GameOverScreen.draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(
        "Game Over\nPress R to Restart",
        0,
        love.graphics.getHeight() * 0.45,
        love.graphics.getWidth(),
        "center"
    )
end

return GameOverScreen
