local HUD = {}
HUD.__index = HUD

local palette = {
    panel = {0.015, 0.018, 0.022, 0.84},
    panelStrong = {0.025, 0.03, 0.038, 0.95},
    stroke = {0.18, 0.22, 0.28, 0.95},
    text = {0.92, 0.95, 0.92, 1},
    muted = {0.58, 0.66, 0.72, 1},
    red = {0.92, 0.12, 0.1},
    cyan = {0.18, 0.75, 0.95},
    amber = {0.95, 0.68, 0.18}
}

local function setColor(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

local function drawPanel(x, y, w, h)
    setColor(palette.panel)
    love.graphics.rectangle("fill", x, y, w, h, 7, 7)
    setColor(palette.stroke)
    love.graphics.rectangle("line", x, y, w, h, 7, 7)
end

local function drawValueBlock(label, value, x, y, w, accent)
    setColor(palette.panelStrong)
    love.graphics.rectangle("fill", x, y, w, 42, 6, 6)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    love.graphics.rectangle("fill", x, y, 4, 42, 6, 6)

    setColor(palette.muted)
    love.graphics.print(label, x + 11, y + 6)
    setColor(palette.text)
    love.graphics.print(value, x + 11, y + 22)
end

local function drawAmmoBar(x, y, w, h, current, max)
    local ratio = 0
    if max and max > 0 then
        ratio = math.max(0, math.min(1, current / max))
    end

    setColor(palette.panelStrong)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    setColor(palette.amber, 0.95)
    love.graphics.rectangle("fill", x, y, w * ratio, h, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.14)
    love.graphics.rectangle("fill", x, y, w * ratio, math.max(2, h * 0.35), 4, 4)
    setColor(palette.stroke)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
end

function HUD.draw(player, winCondition)
    if not player or not winCondition then
        return
    end

    local weapon = player:getCurrentWeapon()
    if not weapon then
        return
    end

    local x, y = 14, 14
    local width, height = 330, 150
    drawPanel(x, y, width, height)

    love.graphics.setColor(0.92, 0.95, 0.92, 1)
    love.graphics.print(string.format("NIVEL %d/%d", winCondition.currentLevel, #winCondition.levels), x + 14, y + 12)
    setColor(palette.muted)
    love.graphics.printf(weapon.weaponName or "Arma", x + 14, y + 12, width - 28, "right")

    drawValueBlock(
        "ABATES",
        string.format("%d / %d", winCondition.killCount, winCondition:currentTarget()),
        x + 14,
        y + 40,
        145,
        palette.red
    )

    drawValueBlock(
        "FRAGMENTOS",
        string.format("%d / %d", winCondition.fragmentCount, winCondition:currentFragmentTarget()),
        x + 171,
        y + 40,
        145,
        palette.cyan
    )

    setColor(palette.muted)
    love.graphics.print("MUNICAO", x + 14, y + 96)
    setColor(palette.text)
    love.graphics.printf(string.format("%d / %d", weapon.clipAmmo, weapon.clipSize), x + 14, y + 96, width - 28, "right")
    drawAmmoBar(x + 14, y + 116, 210, 14, weapon.clipAmmo, weapon.clipSize)

    setColor(palette.muted)
    love.graphics.print(string.format("RESERVA %d/%d", weapon.reserveAmmo, weapon.maxReserveAmmo), x + 236, y + 114)

    if weapon.isReloading then
        love.graphics.setColor(0.95, 0.18, 0.12, 1)
        love.graphics.print("RELOAD", x + 236, y + 132)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return HUD
