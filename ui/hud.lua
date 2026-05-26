local HUD = {}
HUD.__index = HUD

function HUD.draw(player, winCondition)
    if not player or not winCondition then
        return
    end

    local weapon = player:getCurrentWeapon()
    if not weapon then
        return
    end

    local x = 10
    local y = 10
    local width = 280
    local height = 150

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
        string.format("Kills: %d / %d", winCondition.killCount, winCondition:currentTarget()),
        x + 8,
        y + 28,
        width - 16,
        "left"
    )

    local weaponName = weapon.weaponName or "Unknown"
    love.graphics.printf(
        string.format("Weapon: %s", weaponName),
        x + 8,
        y + 50,
        width - 16,
        "left"
    )

    love.graphics.printf(
        string.format("Ammo: %d / %d", weapon.clipAmmo, weapon.clipSize),
        x + 8,
        y + 70,
        width - 16,
        "left"
    )

    love.graphics.printf(
        string.format("Reserve: %d / %d", weapon.reserveAmmo, weapon.maxReserveAmmo),
        x + 8,
        y + 90,
        width - 16,
        "left"
    )

    love.graphics.printf(
        "Press Q para trocar de arma",
        x + 8,
        y + 110,
        width - 16,
        "left"
    )

    if weapon.isReloading then
        love.graphics.printf(
            "Reloading...",
            x + 8,
            y + 130,
            width - 16,
            "left"
        )
    end
end

return HUD
