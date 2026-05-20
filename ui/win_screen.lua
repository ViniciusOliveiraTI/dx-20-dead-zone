local WinScreen = {}
WinScreen.__index = WinScreen

function WinScreen.draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(
        "You Win!\nPress R to Restart",
        0,
        love.graphics.getHeight() * 0.45,
        love.graphics.getWidth(),
        "center"
    )
end

return WinScreen
