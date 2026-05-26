local Player = require("core.player")
local Weapon = require("core.weapon")
local Map = require("core.map"
)local Camera = require("core.camera")
local Collision = require("core.collision")

local PlayerMoveAction = require("actions/player_move_action")
local PlayerShootAction = require("actions.player_shoot_action")
local PlayerReloadAction = require("actions.player_reload_action")

local Inventory = require("core.inventory")
local ItemPickup = require("core.item_pickup")
local Turret = require("core.turret")
local Boss = require("core.boss")

local EnemySpawner = require("systems.enemy_spawner")
local GameState = require("systems.game_state")
local WinCondition = require("systems.win_condition")
local LevelConfig = require("systems.level_config")
local Lighting = require("systems.lighting")

local HealthBar = require("ui.health_bar")
local HUD = require("ui.hud")
local PauseMenu = require("ui.pause_menu")
local GameOverScreen = require("ui.game_over_screen")
local WinScreen = require("ui.win_screen")

local AudioManager = require("systems.audio_manager")
local AudioConfig = require("systems.audio_config")

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
local pickupNotifications = {}
local boss
local lighting
local bossWarningActive = false
local bossWarningElapsed = 0
local bossWarningDuration = 3.0
local bossWarningFont
local defaultFont

local audioManager = nil
local audioConfig = nil

local function createPlayer(existingInventory)
    local pistol = Weapon.new({
        weaponId = "pistol",
        weaponName = "Pistol",
        damage = 15,
        clipSize = 12,
        reserveAmmo = 60,
        maxReserveAmmo = 90,
        fireRate = 0.5,
        reloadTime = 1.2
    })

    local rifle = Weapon.new({
        weaponId = "rifle",
        weaponName = "Rifle",
        damage = 25,
        clipSize = 30,
        reserveAmmo = 150,
        maxReserveAmmo = 150,
        fireRate = 0.35,
        reloadTime = 2.5
    })

    local inventory = existingInventory or Inventory.new()
    if not inventory:hasWeapon("pistol") then
        inventory:addWeapon("pistol", pistol)
    end

    local spawn = gameMap.playerSpawn or { x = 100, y = 100 }
    player = Player.new(spawn.x, spawn.y, inventory)
    
    _RIFLE_TEMPLATE = rifle

    if player.inventory:hasWeapon("rifle") then
        gameMap.rifleSpawn = nil
    end
end

local function spawnTurrets()
    local levelConfig = LevelConfig.getForLevel(winCondition.currentLevel)
    
    -- Only spawn turrets if allowed in this level
    if not levelConfig.allowTurrets then
        return
    end
    
    for _, spawn in ipairs(gameMap.turretSpawns or {}) do
        -- pass world dimensions so turrets can compute a proportional shoot range
        local worldW = gameMap.width * gameMap.tileSize
        local worldH = gameMap.height * gameMap.tileSize
        table.insert(turrets, Turret.new(spawn.x, spawn.y, worldW, worldH))
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

    local currentWeapon = player:getCurrentWeapon()
    local ammoType = "ammo_pistol"
    
    if currentWeapon and currentWeapon.weaponId == "rifle" then
        ammoType = "ammo_rifle"
    end

    table.insert(pickups, ItemPickup.new(x, y, ammoType, amount))
end

local function spawnMedkitAt(x, y, amount)
    if amount <= 0 then
        return
    end

    table.insert(pickups, ItemPickup.new(x, y, "medkit", amount))
end

local function addPickupNotification(text, x, y, itemType)
    -- Determina cor baseada no tipo de item
    local color = { r = 0.2, g = 0.8, b = 1 }  -- Padrão: Azul (munição)
    
    if itemType == "medkit" then
        color = { r = 0.2, g = 1, b = 0.4 }    -- Verde: HP
    elseif itemType == "ammo_rifle" then
        color = { r = 1, g = 0.6, b = 0.2 }    -- Laranja: Munição Rifle
    elseif itemType == "ammo_pistol" then
        color = { r = 0.2, g = 0.8, b = 1 }    -- Azul: Munição Pistola
    end

    table.insert(pickupNotifications, {
        text = text,
        x = x,
        y = y,
        elapsed = 0,
        visibleDuration = 0.8,
        fadeDuration = 0.5,
        lifetime = 1.3,
        alpha = 1,
        color = color,
        scale = 1,
        maxScale = 1.2,
        scaleSpeed = 3,
        floatHeight = 0
    })
end

local function updatePickupNotifications(dt)
    for i = #pickupNotifications, 1, -1 do
        local note = pickupNotifications[i]
        note.elapsed = note.elapsed + dt
        
        -- Animação de flutuação
        note.floatHeight = -20 * (note.elapsed / note.lifetime)

        -- Animação de escala (cresce rápido no início)
        if note.elapsed < 0.1 then
            note.scale = 1 + (note.elapsed / 0.1) * (note.maxScale - 1)
        else
            note.scale = note.maxScale
        end

        if note.elapsed >= note.lifetime then
            table.remove(pickupNotifications, i)
        else
            if note.elapsed > note.visibleDuration then
                note.alpha = 1 - ((note.elapsed - note.visibleDuration) / note.fadeDuration)
            else
                note.alpha = 1
            end
        end
    end
end

local function drawPickupNotifications()
    local font = defaultFont or love.graphics.getFont()
    love.graphics.setFont(font)

    for _, note in ipairs(pickupNotifications) do
        local textWidth = font:getWidth(note.text)
        local textHeight = font:getHeight()
        local padding = 12
        local boxWidth = textWidth + padding * 2
        local boxHeight = textHeight + padding * 1.5
        local cornerRadius = 6
        
        -- Posição com flutuação
        local drawX = note.x - boxWidth / 2
        local drawY = note.y + note.floatHeight - boxHeight / 2
        
        -- Aplicar escala (drawX e drawY ajustados para manter centro)
        local centerX = drawX + boxWidth / 2
        local centerY = drawY + boxHeight / 2
        
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.scale(note.scale)
        love.graphics.translate(-boxWidth / 2, -boxHeight / 2)
        
        -- Background com cor dinâmica e bordas arredondadas
        love.graphics.setColor(
            note.color.r * 0.3,
            note.color.g * 0.3,
            note.color.b * 0.3,
            note.alpha * 0.85
        )
        love.graphics.rectangle("fill", drawX, drawY, boxWidth, boxHeight, cornerRadius, cornerRadius)
        
        -- Borda brilhante
        love.graphics.setColor(
            note.color.r,
            note.color.g,
            note.color.b,
            note.alpha * 0.9
        )
        love.graphics.rectangle("line", drawX, drawY, boxWidth, boxHeight, cornerRadius, cornerRadius)
        
        -- Sombra interna no topo (efeito brilho)
        love.graphics.setColor(
            note.color.r * 0.6,
            note.color.g * 0.6,
            note.color.b * 0.6,
            note.alpha * 0.4
        )
        love.graphics.rectangle("fill", drawX + 2, drawY + 2, boxWidth - 4, 2)
        
        -- Texto com efeito de brilho (duplicado com offset)
        love.graphics.setColor(
            note.color.r,
            note.color.g,
            note.color.b,
            note.alpha * 0.3
        )
        love.graphics.print(
            note.text,
            drawX - textWidth / 2 + padding + 1,
            drawY + padding + 1
        )
        
        -- Texto principal
        love.graphics.setColor(1, 1, 1, note.alpha)
        love.graphics.print(
            note.text,
            drawX - textWidth / 2 + padding,
            drawY + padding
        )
        
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawRiflePrompt()
    if not gameMap or not gameMap.rifleSpawn or not player or player.inventory:hasWeapon("rifle") then
        return
    end

    local px = player.x + player.width / 2
    local py = player.y + player.height / 2
    local rx = gameMap.rifleSpawn.x + gameMap.tileSize / 2
    local ry = gameMap.rifleSpawn.y + gameMap.tileSize / 2
    local dist = math.sqrt((px - rx) ^ 2 + (py - ry) ^ 2)
    local maxDist = 220
    if dist > maxDist then
        return
    end

    local t = math.max(0, 1 - dist / maxDist)
    local alpha = 0.35 + 0.65 * t
    local scale = 0.9 + 0.3 * t
    local yOffset = -12 * (1 - t)
    local font = defaultFont or love.graphics.getFont()
    love.graphics.setFont(font)
    local text = "Pressione E para pegar o Rifle"
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()
    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() * 0.18 + yOffset

    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle(
        "fill",
        centerX - (textWidth * scale) / 2 - 12,
        centerY - (textHeight * scale) / 2 - 10,
        textWidth * scale + 24,
        textHeight * scale + 20,
        10,
        10
    )

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, centerX - (textWidth * scale) / 2, centerY - (textHeight * scale) / 2, 0, scale, scale)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPlayerHealthBar()
    if not player then
        return
    end

    local font = defaultFont or love.graphics.getFont()
    love.graphics.setFont(font)
    local label = string.format("HP: %d / %d", player.health, player.maxHealth)
    local labelWidth = font:getWidth(label)
    local barWidth = 120
    local barHeight = 10
    local padding = 25
    local totalWidth = barWidth + 12 + labelWidth
    local x = love.graphics.getWidth() - totalWidth - padding
    local y = padding

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x - 8, y - 8, totalWidth + 16, barHeight + 16, 10, 10)

    HealthBar.draw(x, y, barWidth, barHeight, player.health, player.maxHealth, "horizontal", true)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(label, x + barWidth + 12, y + barHeight / 2 - font:getHeight() / 2)
end

-- ============================================
-- Função de Inicialização de Áudio
-- ============================================
local function initializeAudio()
    -- Carregar configurações salvas
    audioConfig = AudioConfig.load()
    
    -- Criar gerenciador de áudio
    audioManager = AudioManager.new({
        musicVolume = audioConfig.musicVolume,
        sfxVolume = audioConfig.sfxVolume,
        loopMusic = true
    })
    
    -- Carregar música de fundo
    -- IMPORTANTE: Substitua o caminho abaixo pelo seu arquivo de música
    -- Formatos recomendados: OGG, MP3, WAV
    -- MP4 pode ter problemas em algumas plataformas
    local musicPath = "assets/music/background.mp3"  -- AJUSTE ESTE CAMINHO
    
    if love.filesystem.getInfo(musicPath) then
        audioManager:loadMusic(musicPath, true)  -- true = tocar automaticamente
    else
        print("[AVISO] Arquivo de música não encontrado: " .. musicPath)
        print("[AVISO] Caminho relativo: " .. love.filesystem.getWorkingDirectory() .. "/" .. musicPath)
    end
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

    local currentInventory = nil
    if not resetProgress and player then
        currentInventory = player.inventory
    end
    createPlayer(currentInventory)
    camera = Camera.new(love.graphics.getWidth(), love.graphics.getHeight())
    camera:setWorldSize(gameMap.width * gameMap.tileSize, gameMap.height * gameMap.tileSize)

    moveAction = PlayerMoveAction.new(player)
    shootAction = PlayerShootAction.new(player, projectiles, camera)
    reloadAction = PlayerReloadAction.new(player)

    local levelConfig = LevelConfig.getForLevel(winCondition.currentLevel)
    spawner = EnemySpawner.new(gameMap, zombies, levelConfig)
    spawnTurrets()

    lighting = Lighting.new(love.graphics.getWidth(), love.graphics.getHeight())
    defaultFont = love.graphics.getFont()
    bossWarningFont = love.graphics.newFont(24)

    gameState:set(GameState.states.playing)
end

function love.load()
    love.window.setMode(800, 600)

    gameState = GameState.new()
    winCondition = WinCondition.new()

    -- ============================================
    -- INICIALIZAR ÁUDIO
    -- ============================================
    initializeAudio()

    resetGame(true)
end

function love.update(dt)
    if not gameState:canUpdate() then
        return
    end

    if audioManager then
        audioManager:update(dt)
    end

    moveAction:execute(dt, gameMap, gameState)
    camera:update(player)
    shootAction:execute(gameState)
    reloadAction:execute(gameState)
    player:update(dt, camera)
    updatePickupNotifications(dt)

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
                        -- Medkit drop: 20% chance to drop a medkit item from a killed monster
                        if love.math.random() < 0.2 then
                            local healAmount = love.math.random(1, 5)
                            spawnMedkitAt(z.x + z.width / 2, z.y + z.height / 2, healAmount)
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
            local notificationText
            local notifyX = pickup.centerX or (pickup.x + pickup.width / 2)
            local notifyY = pickup.centerY or (pickup.y + pickup.height / 2)

            -- Handle ItemPickup (has itemType)
            if pickup.itemType then
                if pickup.itemType == "ammo_pistol" then
                    player.inventory:addAmmoToWeapon("pistol", pickup.amount)
                    notificationText = "+" .. tostring(pickup.amount)
                elseif pickup.itemType == "ammo_rifle" then
                    player.inventory:addAmmoToWeapon("rifle", pickup.amount)
                    notificationText = "+" .. tostring(pickup.amount)
                elseif pickup.itemType == "medkit" then
                    player:takeDamage(-pickup.amount)  -- Negative damage = heal
                    notificationText = "+" .. tostring(pickup.amount) .. " HP"
                end
            else
                -- Handle old AmmoPickup (no itemType)
                player:pickupAmmo(pickup.amount)
                notificationText = "+" .. tostring(pickup.amount)
            end

            if notificationText then
                addPickupNotification(notificationText, notifyX, notifyY, pickup.itemType)
            end

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
            z.maxHealth,
            "vertical",
            true
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
                t.maxHealth,
                "vertical",
                true
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
                boss.maxHealth,
                "vertical",
                true
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

    for _, p in ipairs(projectiles) do
        p:draw()
    end

    drawPickupNotifications()

    love.graphics.pop()

    -- Lighting overlay (screen-space): darken scene except around player
    if lighting and player and camera then
        local sx, sy = camera:toScreen(player.x + player.width / 2, player.y + player.height / 2)
        lighting:draw(sx, sy, 150)
    end

    HUD.draw(player, winCondition)
    drawPlayerHealthBar()
    drawRiflePrompt()

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
        love.graphics.printf("FALHA DE CONTENÇÃO. ELE ESTÁ VINDO", 0, love.graphics.getHeight() / 2 - 24, love.graphics.getWidth(), "center")
        love.graphics.setFont(defaultFont)
        love.graphics.setColor(1,1,1,1)
    end
end

function love.keypressed(key)
    if key == "escape" then
        gameState:togglePause()
        
        if audioManager then
            audioManager:toggleMusicPause()
        end
        
    elseif key == "r" then
        local weapon = player and player:getCurrentWeapon()
        if weapon then
            weapon:reload()
        end
    elseif key == "q" then
        player:switchWeapon()
    elseif key == "e" then
        -- Try to pick up rifle if available
        if gameMap.rifleSpawn and not player.inventory:hasWeapon("rifle") then
            local px = player.x + player.width / 2
            local py = player.y + player.height / 2
            local rx = gameMap.rifleSpawn.x + gameMap.tileSize / 2
            local ry = gameMap.rifleSpawn.y + gameMap.tileSize / 2
            local distance = math.sqrt((px - rx) ^ 2 + (py - ry) ^ 2)
            
            if distance < 80 then  -- Pickup range of 80 pixels
                player.inventory:addWeapon("rifle", _RIFLE_TEMPLATE)
                gameMap.rifleSpawn = nil
                print("[Game] Picked up Rifle!")
            end
        end
    end
    
    if key == "+" or key == "=" then
        if audioManager then
            audioManager:increaseMusicVolume(0.1)
        end
    elseif key == "-" or key == "_" then
        if audioManager then
            audioManager:decreaseMusicVolume(0.1)
        end
    end
    
    -- Debug: Mostrar informações de áudio
    if key == "f12" then
        if audioManager then
            print(string.format("Música: %.0f%% | Efeitos: %.0f%% | Tocando: %s",
                audioManager:getMusicVolume() * 100,
                audioManager:getSFXVolume() * 100,
                audioManager:isMusicPlaying() and "Sim" or "Não"
            ))
        end
    end
end

function love.quit()
    if audioManager then
        audioManager:destroy()
        
        if audioConfig then
            audioConfig.musicVolume = audioManager:getMusicVolume()
            audioConfig.sfxVolume = audioManager:getSFXVolume()
            AudioConfig.save(audioConfig)
        end
    end
end