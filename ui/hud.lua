local HUD = {}
HUD.__index = HUD

function HUD.draw(player, weapon, winCondition)
    if not weapon or not winCondition then
        return
    end

    local x = 10
    local y = 10
    local width = 260
    local height = 108

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x, y, width, height, 6, 6)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(
        string.format("Level %d / %d", winCondition.currentLevel, #winCondition.levels),
        x + 8,
        y + 6,
        width - 16,
        "left"
    )

    love.graphics.printf(
        string.format("Health: %d / %d", player.health, player.maxHealth),
        x + 8,
        y + 24,
        width - 16,
        "left"
    )

    love.graphics.printf(
        string.format("Kills: %d / %d", winCondition.killCount, winCondition:currentTarget()),
        x + 8,
        y + 42,
        width - 16,
        "left"
    )

    love.graphics.printf(
        string.format("Ammo: %d / %d", weapon.clipAmmo, weapon.clipSize),
        x + 8,
        y + 60,
        width - 16,
        "left"
    )

    love.graphics.printf(
        string.format("Reserve: %d / %d", weapon.reserveAmmo, weapon.maxReserveAmmo),
        x + 8,
        y + 78,
        width - 16,
        "left"
    )

    if weapon.isReloading then
        love.graphics.printf(
            "Reloading...",
            x + 8,
            y + 96,
            width - 16,
            "left"
        )
    end
end

return HUD
