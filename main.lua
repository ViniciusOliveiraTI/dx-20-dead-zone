local Player = require("core.player")
local Weapon = require("core.weapon")
local Map = require("core.map")local Camera = require("core.camera")local Collision = require("core.collision")

local PlayerMoveAction = require("actions/player_move_action")
local PlayerShootAction = require("actions.player_shoot_action")
local PlayerReloadAction = require("actions.player_reload_action")

local AmmoPickup = require("core.ammo_pickup")
local Turret = require("core.turret")
local Boss = require("core.boss")
local HealthPickup = require("core.health_pickup")

local EnemySpawner = require("systems.enemy_spawner")
local GameState = require("systems.game_state")
local WinCondition = require("systems.win_condition")
local Lighting = require("systems.lighting")

local HealthBar = require("ui.health_bar")
local HUD = require("ui.hud")
local PauseMenu = require("ui.pause_menu")
local GameOverScreen = require("ui.game_over_screen")
local WinScreen = require("ui.win_screen")

local gameState
local winCondition
local spawner
local gameMap
local camera
local player
local moveAction
local shootAction
local reloadAction
local projectiles = {}
local zombies = {}
local turrets = {}
local pickups = {}
local healthPickups = {}
local boss
local lighting
local bossWarningActive = false
local bossWarningElapsed = 0
local bossWarningDuration = 3.0
local bossWarningFont

local function createPlayer()
    local pistol = Weapon.new({
        clipSize = 12,
        reserveAmmo = 60,
        maxReserveAmmo = 90,
        fireRate = 0.5,
        reloadTime = 1.2
    })

    local spawn = gameMap.playerSpawn or { x = 100, y = 100 }
    player = Player.new(spawn.x, spawn.y, pistol)
end

local function spawnTurrets()
    for _, spawn in ipairs(gameMap.turretSpawns or {}) do
        table.insert(turrets, Turret.new(spawn.x, spawn.y))
    end
end

local function spawnBoss()
    local bossPosition = gameMap.bossSpawn or { x = math.max(0, gameMap.width * gameMap.tileSize / 2 - 32), y = math.max(0, gameMap.height * gameMap.tileSize / 2 - 40) }
    boss = Boss.new(bossPosition.x, bossPosition.y)
    winCondition:markBossSpawned()
    -- Clear all remaining zombies and disable spawner for boss fight
    zombies = {}
    spawner = nil
    -- trigger boss warning overlay
    bossWarningActive = true
    bossWarningElapsed = 0
end

local function spawnAmmoAt(x, y, amount)
    if amount <= 0 then
        return
    end

    table.insert(pickups, AmmoPickup.new(x, y, amount))
end

local function spawnHealthPickup(x, y, amount)
    if amount <= 0 then
        return
    end

    table.insert(healthPickups, HealthPickup.new(x, y, amount))
end

local function resetGame(resetProgress)
    if resetProgress then
        winCondition:reset()
    end

    projectiles = {}
    zombies = {}
    turrets = {}
    pickups = {}
    healthPickups = {}
    boss = nil

    gameMap = Map.new(32)
    gameMap:loadFromFile(winCondition:currentMapPath())

    createPlayer()
    camera = Camera.new(love.graphics.getWidth(), love.graphics.getHeight())
    camera:setWorldSize(gameMap.width * gameMap.tileSize, gameMap.height * gameMap.tileSize)

    moveAction = PlayerMoveAction.new(player)
    shootAction = PlayerShootAction.new(player, projectiles, camera)
    reloadAction = PlayerReloadAction.new(player)

    spawner = EnemySpawner.new(gameMap, zombies)
    spawnTurrets()

    lighting = Lighting.new(love.graphics.getWidth(), love.graphics.getHeight())
    bossWarningFont = love.graphics.newFont(24)

    gameState:set(GameState.states.playing)
end

function love.load()
    love.window.setMode(800, 600)

    gameState = GameState.new()
    winCondition = WinCondition.new()

    resetGame(true)
end

function love.update(dt)
    if not gameState:canUpdate() then
        return
    end

    moveAction:execute(dt, gameMap, gameState)
    camera:update(player)
    shootAction:execute(gameState)
    reloadAction:execute(gameState)
    player:update(dt, camera)

    for i = #projectiles, 1, -1 do
        local p = projectiles[i]
        p:update(dt)

        local removed = false
        local hit = false

        if p.fromEnemy then
            if Collision.checkAABB(
                p.x - p.radius,
                p.y - p.radius,
                p.radius * 2,
                p.radius * 2,
                player.x,
                player.y,
                player.width,
                player.height
            ) then
                player:takeDamage(p.damage)
                removed = true
            end
        else
            for j = #zombies, 1, -1 do
                local z = zombies[j]
                if z.alive and Collision.checkAABB(
                    p.x - p.radius,
                    p.y - p.radius,
                    p.radius * 2,
                    p.radius * 2,
                    z.x,
                    z.y,
                    z.width,
                    z.height
                ) then
                    if z:takeDamage(p.damage) then
                        winCondition:registerKill()
                        spawnAmmoAt(z.x + z.width / 2, z.y + z.height / 2, love.math.random(0, 6))
                        -- Potion drop: 20% chance to drop healing potion (1-5 HP)
                        if love.math.random() < 0.2 then
                            local healAmount = love.math.random(1, 5)
                            spawnHealthPickup(z.x + z.width / 2, z.y + z.height / 2, healAmount)
                        end
                    end
                    removed = true
                    hit = true
                    break
                end
            end

            if not removed then
                for j = #turrets, 1, -1 do
                    local t = turrets[j]
                    if t.alive and Collision.checkAABB(
                        p.x - p.radius,
                        p.y - p.radius,
                        p.radius * 2,
                        p.radius * 2,
                        t.x,
                        t.y,
                        t.width,
                        t.height
                    ) then
                        if t:takeDamage(p.damage) then
                            winCondition:registerKill()
                            spawnAmmoAt(t.x + t.width / 2, t.y + t.height / 2, love.math.random(0, 6))
                        end
                        removed = true
                        break
                    end
                end
            end

            if not removed and boss and boss.alive and Collision.checkAABB(
                p.x - p.radius,
                p.y - p.radius,
                p.radius * 2,
                p.radius * 2,
                boss.x,
                boss.y,
                boss.width,
                boss.height
            ) then
                if boss:takeDamage(p.damage) then
                    spawnAmmoAt(boss.x + boss.width / 2, boss.y + boss.height / 2, love.math.random(0, 6))
                end
                removed = true
            end
        end

        if not removed and gameMap:collidesWithRect(
            p.x - p.radius,
            p.y - p.radius,
            p.radius * 2,
            p.radius * 2
        ) then
            removed = true
        end

        if removed then
            table.remove(projectiles, i)
        end
    end

    for i = #pickups, 1, -1 do
        local pickup = pickups[i]
        if Collision.checkAABB(
            pickup.x,
            pickup.y,
            pickup.width,
            pickup.height,
            player.x,
            player.y,
            player.width,
            player.height
        ) then
            player:pickupAmmo(pickup.amount)
            table.remove(pickups, i)
        end
    end

    for i = #healthPickups, 1, -1 do
        local pickup = healthPickups[i]
        if Collision.checkAABB(
            pickup.x,
            pickup.y,
            pickup.width,
            pickup.height,
            player.x,
            player.y,
            player.width,
            player.height
        ) then
            player:takeDamage(-pickup.amount)  -- Negative damage = heal
            table.remove(healthPickups, i)
        end
    end

    for i = #zombies, 1, -1 do
        local z = zombies[i]
        z:update(dt, player, gameMap)

        if z:shouldRemove() then
            table.remove(zombies, i)
        end
    end

    for i = #turrets, 1, -1 do
        local t = turrets[i]
        t:update(dt, player, projectiles)
        if t:shouldRemove() then
            table.remove(turrets, i)
        end
    end

    if boss and (boss.alive or boss.dying) then
        boss:update(dt, player, gameMap, projectiles)
        if boss:shouldRemove() then
            boss = nil
            winCondition:markBossDefeated()
        end
    end

    if spawner then
        spawner:update(dt, gameState, winCondition)
    end

    if not player:isAlive() then
        gameState:set(GameState.states.game_over)
        return
    end

    if winCondition:isFinalLevel() and winCondition:shouldSpawnBoss() and not boss then
        spawnBoss()
    end

    -- Boss warning timer update
    if bossWarningActive then
        bossWarningElapsed = bossWarningElapsed + dt
        if bossWarningElapsed >= bossWarningDuration then
            bossWarningActive = false
        end
    end

    if not winCondition:isFinalLevel() and winCondition:isLevelComplete() then
        winCondition:advanceLevel()
        resetGame(false)
        return
    end

    if winCondition:isLevelComplete() and winCondition:isFinalLevel() then
        gameState:set(GameState.states.victory)
        return
    end
end

function love.draw()
    love.graphics.push()
    camera:apply()

    gameMap:draw()

    for _, pickup in ipairs(pickups) do
        pickup:draw()
    end

    for _, healthPickup in ipairs(healthPickups) do
        healthPickup:draw()
    end

    for _, z in ipairs(zombies) do
        z:draw()
        HealthBar.draw(
            z.x + z.width + 3,
            z.y,
            5,
            z.height,
            z.health,
            z.maxHealth
        )
    end

    for _, t in ipairs(turrets) do
        t:draw()
        if t.alive then
            HealthBar.draw(
                t.x + t.width + 3,
                t.y,
                5,
                t.height,
                t.health,
                t.maxHealth
            )
        end
    end

    if boss then
        boss:draw()
        if boss.alive then
            HealthBar.draw(
                boss.x + boss.width + 3,
                boss.y,
                6,
                boss.height,
                boss.health,
                boss.maxHealth
            )
        end
    end

    if player and player.draw then
        player:draw()
    else
        love.graphics.rectangle(
            "fill",
            player.x,
            player.y,
            player.width,
            player.height
        )
    end

    HealthBar.draw(
        player.x + player.width + 4,
        player.y,
        6,
        player.height,
        player.health,
        player.maxHealth
    )

    for _, p in ipairs(projectiles) do
        p:draw()
    end

    love.graphics.pop()

    -- Lighting overlay (screen-space): darken scene except around player
    if lighting and player and camera then
        local sx, sy = camera:toScreen(player.x + player.width / 2, player.y + player.height / 2)
        lighting:draw(sx, sy, 160)
    end

    HUD.draw(player, player.weapon, winCondition)

    if gameState:isPaused() then
        PauseMenu.draw()
    elseif gameState:isGameOver() then
        GameOverScreen.draw()
    elseif gameState:isVictory() then
        WinScreen.draw()
    end

    -- Boss spawn warning (screen-space overlay)
    if bossWarningActive then
        local alpha = 1 - (bossWarningElapsed / bossWarningDuration)
        love.graphics.setFont(bossWarningFont)
        love.graphics.setColor(1, 0.1, 0.1, alpha)
        love.graphics.printf("BOSS INCOMING", 0, love.graphics.getHeight() / 2 - 24, love.graphics.getWidth(), "center")
        love.graphics.setColor(1,1,1,1)
    end
end

function love.keypressed(key)
    if key == "escape" then
        gameState:togglePause()
    elseif key == "r" then
        local resetAll = gameState:isGameOver() or gameState:isVictory()
        resetGame(resetAll)
    end
end
