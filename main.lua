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
local FragmentPickup = require("core.fragment_pickup")
local DXSamplePickup = require("core.dx_sample_pickup")
local Turret = require("core.turret")
local Boss = require("core.boss")
local Zombie = require("core.zombie")

local EnemySpawner = require("systems.enemy_spawner")
local GameState = require("systems.game_state")
local WinCondition = require("systems.win_condition")
local LevelConfig = require("systems.level_config")
local Lighting = require("systems.lighting")
local Cutscene = require("systems.cutscene")
local LevelIntro = require("systems.level_intro")
local ZombieTypes = require("core.zombie_types")

local HealthBar = require("ui.health_bar")
local HUD = require("ui.hud")
local MainMenu = require("ui.main_menu")
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
local fragments = {}
local dxSample = nil
local pickupNotifications = {}
local boss
local lighting
local bossWarningActive = false
local bossWarningElapsed = 0
local bossWarningDuration = 4.2
local bossWarningFont
local bossWarningSmallFont
local bossRedAlertTimer = 0
local bossRedAlertDuration = 7.5
local defaultFont
local previousPlayerHealth = nil
local damageFlashTimer = 0
local damageFlashDuration = 0.45
local screenShakeTimer = 0
local screenShakeDuration = 0.22
local screenShakeIntensity = 6
local cutscene
local levelIntro
local victoryCutsceneStarted = false

local audioManager = nil
local audioConfig = nil
local draggingAudioSlider = nil
local zombieRoarTimer = 0
local zombieRoarNextTime = love.math.random(6, 12)
local currentMusicTrack = nil

local MUSIC_TRACKS = {
    stopped = "assets/music/stoped_game_state.ogg",
    gameplay = "assets/music/background.ogg",
    boss = "assets/music/end_game.ogg"
}

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
        table.insert(turrets, Turret.new(spawn.x, spawn.y, worldW, worldH, audioManager, levelConfig.turretRange))
    end
end

local function playMusicTrack(trackName)
    if not audioManager then
        return
    end

    if currentMusicTrack == trackName then
        audioManager:setSoundEffectsSuppressed(trackName == "stopped")
        audioManager:resumeMusic()
        return
    end

    local path = MUSIC_TRACKS[trackName]
    if not path then
        return
    end

    if audioManager:loadMusic(path, true) then
        currentMusicTrack = trackName
        audioManager:setSoundEffectsSuppressed(trackName == "stopped")
    end
end

local function playGameplayMusic()
    if winCondition and winCondition.bossSpawned then
        playMusicTrack("boss")
    else
        playMusicTrack("gameplay")
    end
end

local function spawnBoss()
    local bossPosition = gameMap.bossSpawn or { x = math.max(0, gameMap.width * gameMap.tileSize / 2 - 32), y = math.max(0, gameMap.height * gameMap.tileSize / 2 - 40) }
    boss = Boss.new(bossPosition.x, bossPosition.y, audioManager)
    if audioManager then
        audioManager:playSoundEffect("alarm")
        audioManager:playSoundEffect("door_explosion")
        audioManager:playSoundEffect("boss_appear")
    end
    playMusicTrack("boss")
    winCondition:markBossSpawned()
    -- Clear all remaining zombies and disable spawner for boss fight
    zombies = {}
    spawner = nil
    -- trigger boss warning overlay
    bossWarningActive = true
    bossWarningElapsed = 0
    bossRedAlertTimer = bossRedAlertDuration
end

local function spawnBossMinions()
    if not boss or not boss.alive or boss.dying or not gameMap then
        return
    end

    local activeBossMinions = 0
    for _, zombie in ipairs(zombies) do
        if zombie.spawnedByBoss and (zombie.alive or zombie.dying) then
            activeBossMinions = activeBossMinions + 1
        end
    end

    local availableSlots = 5 - activeBossMinions
    if availableSlots <= 0 then
        return
    end

    local typeNames = { "normal", "fast", "brute" }
    local amount = math.min(love.math.random(2, 5), availableSlots)
    local cx = boss.x + boss.width / 2
    local cy = boss.y + boss.height / 2
    local spawned = 0

    for i = 1, amount do
        local typeName = typeNames[love.math.random(1, #typeNames)]
        local zType = ZombieTypes[typeName]

        for attempt = 1, 14 do
            local angle = love.math.random() * math.pi * 2
            local distance = love.math.random(78, 142)
            local x = cx + math.cos(angle) * distance - 12
            local y = cy + math.sin(angle) * distance - 15

            if not gameMap:collidesWithRect(x, y, 24, 30) then
                local minion = Zombie.new(x, y, typeName, zType)
                minion.spawnedByBoss = true
                table.insert(zombies, minion)
                spawned = spawned + 1
                break
            end
        end
    end

    if spawned > 0 and audioManager then
        audioManager:playRandomSoundEffect("zombie_roar", 0.28)
    end
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

local function spawnFragments()
    fragments = {}
    for _, spawn in ipairs(gameMap.fragmentSpawns or {}) do
        table.insert(fragments, FragmentPickup.new(spawn.x, spawn.y))
    end
end

local function spawnDXSampleAt(x, y)
    dxSample = DXSamplePickup.new(x, y)
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
    elseif itemType == "fragment" then
        color = { r = 0.4, g = 0.95, b = 1 }    -- Ciano: Fragmento
    elseif itemType == "dx_sample" then
        color = { r = 0.2, g = 1, b = 0.35 }    -- Verde: Amostra DX
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

local function drawDXSamplePrompt()
    if not dxSample or not player then
        return
    end

    local px = player.x + player.width / 2
    local py = player.y + player.height / 2
    local dist = math.sqrt((px - dxSample.centerX) ^ 2 + (py - dxSample.centerY) ^ 2)
    if dist > 120 then
        return
    end

    local font = defaultFont or love.graphics.getFont()
    love.graphics.setFont(font)
    local text = "Pressione E para coletar a Amostra DX"
    local textWidth = font:getWidth(text)
    local x = love.graphics.getWidth() / 2 - textWidth / 2 - 14
    local y = love.graphics.getHeight() * 0.24

    love.graphics.setColor(0.02, 0.12, 0.06, 0.75)
    love.graphics.rectangle("fill", x, y, textWidth + 28, 34, 8, 8)
    love.graphics.setColor(0.2, 1, 0.4, 0.9)
    love.graphics.rectangle("line", x, y, textWidth + 28, 34, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(text, x + 14, y + 8)
end

local function drawCollectibleLights()
    if not lighting or not camera then
        return
    end

    for _, fragment in ipairs(fragments) do
        local sx, sy = camera:toScreen(fragment.centerX, fragment.centerY)
        lighting:drawCircularGlow(sx, sy, 52, {0.15, 0.65, 1}, 0.75)
    end

    if dxSample then
        local sx, sy = camera:toScreen(dxSample.centerX, dxSample.centerY)
        lighting:drawCircularGlow(sx, sy, 68, {0.15, 1, 0.35}, 0.9)
    end
end

local function updateZombieRoars(dt)
    if not audioManager or #zombies == 0 then
        return
    end

    zombieRoarTimer = zombieRoarTimer + dt
    if zombieRoarTimer >= zombieRoarNextTime then
        audioManager:playRandomSoundEffect("zombie_roar")
        zombieRoarTimer = 0
        zombieRoarNextTime = love.math.random(8, 14)
    end
end

local function drawPlayerHealthBar()
    if not player then
        return
    end

    local width = 270
    local height = 20
    local x = love.graphics.getWidth() - width - 24
    local y = 20
    HealthBar.drawPlayerFrame(x, y, width, height, player.health, player.maxHealth)
end

local function triggerDamageFeedback()
    damageFlashTimer = damageFlashDuration
    screenShakeTimer = screenShakeDuration
end

local function updateDamageFeedback(dt)
    damageFlashTimer = math.max(0, damageFlashTimer - dt)
    screenShakeTimer = math.max(0, screenShakeTimer - dt)
end

local function applyScreenShake()
    if screenShakeTimer <= 0 then
        return
    end

    local ratio = screenShakeTimer / screenShakeDuration
    local amount = screenShakeIntensity * ratio
    love.graphics.translate(
        love.math.random(-amount, amount),
        love.math.random(-amount, amount)
    )
end

local function drawDamageOverlay()
    if damageFlashTimer <= 0 then
        return
    end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local t = damageFlashTimer / damageFlashDuration
    local maxAlpha = 0.34 * t

    for i = 1, 10 do
        local p = i / 10
        local a = maxAlpha * (1 - p) ^ 1.4
        local insetX = w * 0.035 * i
        local insetY = h * 0.035 * i

        love.graphics.setColor(0.85, 0.02, 0.02, a)
        love.graphics.rectangle("fill", 0, 0, w, insetY)
        love.graphics.rectangle("fill", 0, h - insetY, w, insetY)
        love.graphics.rectangle("fill", 0, 0, insetX, h)
        love.graphics.rectangle("fill", w - insetX, 0, insetX, h)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawBossRedAlert()
    if bossRedAlertTimer <= 0 then
        return
    end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local life = bossRedAlertTimer / bossRedAlertDuration
    local pulse = (math.sin(love.timer.getTime() * 12) + 1) / 2
    local alpha = (0.08 + pulse * 0.2) * life

    love.graphics.setColor(0.85, 0.02, 0.015, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(1, 0.04, 0.02, alpha * 0.9)
    love.graphics.rectangle("fill", 0, 0, w, 8)
    love.graphics.rectangle("fill", 0, h - 8, w, 8)

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawBossWarning()
    if not bossWarningActive then
        return
    end

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local progress = math.min(1, bossWarningElapsed / bossWarningDuration)
    local fadeIn = math.min(1, bossWarningElapsed / 0.35)
    local fadeOut = math.min(1, (bossWarningDuration - bossWarningElapsed) / 0.65)
    local alpha = math.max(0, math.min(fadeIn, fadeOut))
    local pulse = (math.sin(love.timer.getTime() * 18) + 1) / 2
    local panelW = math.min(w - 56, 620)
    local panelH = 136
    local x = (w - panelW) / 2
    local y = h * 0.5 - panelH / 2

    love.graphics.setColor(0, 0, 0, 0.58 * alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.08, 0.005, 0.006, 0.9 * alpha)
    love.graphics.rectangle("fill", x, y, panelW, panelH, 6, 6)

    love.graphics.setColor(1, 0.02, 0.015, (0.45 + pulse * 0.45) * alpha)
    love.graphics.rectangle("line", x, y, panelW, panelH, 6, 6)
    love.graphics.rectangle("fill", x + 26, y + 30, panelW - 52, 2)
    love.graphics.rectangle("fill", x + 26, y + panelH - 32, panelW - 52, 2)

    love.graphics.setFont(bossWarningFont)
    love.graphics.setColor(0.08, 0, 0, 0.75 * alpha)
    love.graphics.printf("ELE DESPERTOU", x + 3, y + 43, panelW, "center")
    love.graphics.setColor(1, 0.08 + pulse * 0.08, 0.06, alpha)
    love.graphics.printf("ELE DESPERTOU", x, y + 40, panelW, "center")

    love.graphics.setFont(bossWarningSmallFont)
    love.graphics.setColor(0.86, 0.78, 0.74, 0.88 * alpha)
    love.graphics.printf("As luzes falham. A contencao acabou.", x + 24, y + 92, panelW - 48, "center")

    love.graphics.setColor(1, 0.02, 0.015, 0.5 * alpha)
    love.graphics.rectangle("fill", x, y + panelH - 4, panelW * progress, 4)

    love.graphics.setFont(defaultFont)
    love.graphics.setColor(1, 1, 1, 1)
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

    -- Carregar sons do jogo
    audioManager:loadSoundEffect("pistol_shot", "assets/sounds/shots/pistol_shot.ogg")
    audioManager:loadSoundEffect("rifle_shot", "assets/sounds/shots/rifle_shot.ogg")
    audioManager:loadSoundEffect("turret_shot", "assets/sounds/shots/turret_shot.ogg")
    audioManager:loadSoundEffect("pistol_reloading", "assets/sounds/reloading/pistol_reloading.ogg")
    audioManager:loadSoundEffect("rifle_reloading", "assets/sounds/reloading/rifle_reloading.ogg")
    audioManager:loadSoundEffect("alarm", "assets/sounds/boss/spawn/alarm.ogg")
    audioManager:loadSoundEffect("boss_appear", "assets/sounds/boss/spawn/boss_appear.ogg")
    audioManager:loadSoundEffect("door_explosion", "assets/sounds/boss/spawn/door_explosion.ogg")
    audioManager:loadSoundEffectGroup("zombie_roar", "assets/sounds/roars", "^zombie_roar_%d+%.ogg$")
    audioManager:loadSoundEffectGroup("boss_scream", "assets/sounds/boss/screams", "^boss_scream_%d+%.ogg$")

    currentMusicTrack = nil
    playMusicTrack("stopped")
end

local function resetGame(resetProgress)
    if resetProgress then
        winCondition:reset()
        victoryCutsceneStarted = false
    end

    projectiles = {}
    zombies = {}
    turrets = {}
    pickups = {}
    healthPickups = {}
    fragments = {}
    dxSample = nil
    boss = nil

    gameMap = Map.new(32)
    gameMap:loadFromFile(winCondition:currentMapPath())

    local currentInventory = nil
    if not resetProgress and player then
        currentInventory = player.inventory
    end
    createPlayer(currentInventory)
    previousPlayerHealth = player.health
    camera = Camera.new(love.graphics.getWidth(), love.graphics.getHeight())
    camera:setWorldSize(gameMap.width * gameMap.tileSize, gameMap.height * gameMap.tileSize)

    moveAction = PlayerMoveAction.new(player)
    shootAction = PlayerShootAction.new(player, projectiles, camera, audioManager)
    reloadAction = PlayerReloadAction.new(player, audioManager)

    local levelConfig = LevelConfig.getForLevel(winCondition.currentLevel)
    spawner = EnemySpawner.new(gameMap, zombies, levelConfig)
    spawnTurrets()
    spawnFragments()

    lighting = Lighting.new(love.graphics.getWidth(), love.graphics.getHeight())
    defaultFont = love.graphics.getFont()
    bossWarningFont = love.graphics.newFont(34)
    bossWarningSmallFont = love.graphics.newFont(15)

    if not gameState:isMainMenu() then
        gameState:set(GameState.states.playing)
    end
end

local function startNewGame()
    resetGame(true)
    gameState:set(GameState.states.playing)
    local levelConfig = LevelConfig.getForLevel(winCondition.currentLevel)
    levelIntro:show(levelConfig.introTitle or levelConfig.name, levelConfig.introDescription)
    playGameplayMusic()
end

local function startIntroCutscene()
    if audioManager then
        audioManager:pauseMusic()
    end

    gameState:set(GameState.states.cutscene)
    cutscene:playVideo("assets/cutscenes/start_game.mp4", function()
        startNewGame()
    end)
end

local function startLevelTransition(fromLevel, toLevel)
    local path = string.format("assets/image/levels/level_%d_to_level_%d.jpeg", fromLevel, toLevel)

    playMusicTrack("stopped")
    gameState:set(GameState.states.cutscene)
    cutscene:showImage(path, 5, function()
        winCondition:advanceLevel()
        resetGame(false)
        local levelConfig = LevelConfig.getForLevel(winCondition.currentLevel)
        levelIntro:show(levelConfig.introTitle or levelConfig.name, levelConfig.introDescription)
        playGameplayMusic()
    end)
end

local function startVictoryCutscene()
    victoryCutsceneStarted = true
    playMusicTrack("stopped")
    gameState:set(GameState.states.cutscene)
    cutscene:showImage("assets/image/end/victory.jpeg", 10, function()
        gameState:set(GameState.states.victory)
    end)
end

local function pointInRect(x, y, rect)
    return rect
        and x >= rect.x
        and x <= rect.x + rect.width
        and y >= rect.y
        and y <= rect.y + rect.height
end

local function persistAudioConfig()
    if audioManager and audioConfig then
        audioConfig.musicVolume = audioManager:getMusicVolume()
        audioConfig.sfxVolume = audioManager:getSFXVolume()
        AudioConfig.save(audioConfig)
    end
end

local function setPauseAudioSlider(sliderId, x)
    if not audioManager then
        return
    end

    local sliders = PauseMenu.getSliders(audioManager)
    local slider = sliders[sliderId]
    if not slider then
        return
    end

    local value = PauseMenu.sliderValueAt(slider, x)
    if sliderId == "music" then
        audioManager:setMusicVolume(value)
    elseif sliderId == "sfx" then
        audioManager:setSFXVolume(value)
    end

    persistAudioConfig()
end

function love.load()
    love.window.setMode(800, 600)

    gameState = GameState.new()
    winCondition = WinCondition.new()
    cutscene = Cutscene.new()
    levelIntro = LevelIntro.new()

    -- ============================================
    -- INICIALIZAR ÁUDIO
    -- ============================================
    initializeAudio()

    resetGame(true)
end

function love.update(dt)
    if gameState:isCutscene() then
        if cutscene then
            cutscene:update(dt)
        end
        return
    end

    if not gameState:canUpdate() then
        return
    end

    if audioManager then
        audioManager:update(dt)
    end
    if levelIntro then
        levelIntro:update(dt)
    end

    updateZombieRoars(dt)
    moveAction:execute(dt, gameMap, gameState)
    camera:update(player)
    shootAction:execute(gameState)
    reloadAction:execute(gameState)
    player:update(dt, camera)
    updatePickupNotifications(dt)
    updateDamageFeedback(dt)

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

    for i = #fragments, 1, -1 do
        local fragment = fragments[i]
        fragment:update(dt)
        if Collision.checkAABB(
            fragment.x,
            fragment.y,
            fragment.width,
            fragment.height,
            player.x,
            player.y,
            player.width,
            player.height
        ) then
            winCondition:registerFragment()
            addPickupNotification(
                string.format("Fragmento %d/%d", winCondition.fragmentCount, winCondition:currentFragmentTarget()),
                fragment.centerX,
                fragment.centerY,
                "fragment"
            )
            table.remove(fragments, i)
        end
    end

    if dxSample then
        dxSample:update(dt)
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
        if boss.consumeSummon and boss:consumeSummon() then
            spawnBossMinions()
        end

        if boss:shouldRemove() then
            spawnDXSampleAt(boss.x + boss.width / 2, boss.y + boss.height / 2)
            boss = nil
            winCondition:markBossDefeated()
        end
    end

    if spawner then
        spawner:update(dt, gameState, winCondition)
    end

    if previousPlayerHealth and player.health < previousPlayerHealth then
        triggerDamageFeedback()
    end
    previousPlayerHealth = player.health

    if not player:isAlive() then
        gameState:set(GameState.states.game_over)
        playMusicTrack("stopped")
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

    if bossRedAlertTimer > 0 then
        bossRedAlertTimer = math.max(0, bossRedAlertTimer - dt)
    end

    if not winCondition:isFinalLevel() and winCondition:isLevelComplete() then
        startLevelTransition(winCondition.currentLevel, winCondition.currentLevel + 1)
        return
    end

    if winCondition:isLevelComplete() and winCondition:isFinalLevel() and not victoryCutsceneStarted then
        startVictoryCutscene()
        return
    end
end

function love.draw()
    if gameState:isCutscene() then
        if cutscene then
            cutscene:draw()
        end
        return
    end

    if gameState:isMainMenu() then
        MainMenu.draw()
        return
    end

    love.graphics.push()
    applyScreenShake()
    camera:apply()

    gameMap:draw()

    for _, pickup in ipairs(pickups) do
        pickup:draw()
    end

    for _, healthPickup in ipairs(healthPickups) do
        healthPickup:draw()
    end

    for _, fragment in ipairs(fragments) do
        fragment:draw()
    end

    if dxSample then
        dxSample:draw()
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
        drawCollectibleLights()
    end

    drawBossRedAlert()

    HUD.draw(player, winCondition)
    drawPlayerHealthBar()
    drawRiflePrompt()
    drawDXSamplePrompt()
    drawDamageOverlay()
    if levelIntro then
        levelIntro:draw()
    end

    if gameState:isPaused() then
        PauseMenu.draw(audioManager)
    elseif gameState:isGameOver() then
        GameOverScreen.draw()
    elseif gameState:isVictory() then
        WinScreen.draw()
    end

    drawBossWarning()
end

function love.keypressed(key)
    if gameState:isMainMenu() then
        if key == "return" or key == "space" then
            startIntroCutscene()
        end
        return
    end

    if gameState:isCutscene() then
        return
    end

    if key == "escape" then
        local wasPlaying = gameState:isPlaying()
        local wasPaused = gameState:isPaused()
        gameState:togglePause()
        
        if wasPlaying then
            playMusicTrack("stopped")
        elseif wasPaused then
            playGameplayMusic()
        end

        return
    end

    if not gameState:isPlaying() then
        if key == "r" and (gameState:isGameOver() or gameState:isVictory()) then
            startNewGame()
        end
        return
    end

    if key == "r" then
        if gameState:isGameOver() or gameState:isVictory() then
            startNewGame()
            return
        end
        local weapon = player and player:getCurrentWeapon()
        if weapon and reloadAction then
            reloadAction:reload()
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

        if dxSample then
            local px = player.x + player.width / 2
            local py = player.y + player.height / 2
            local distance = math.sqrt((px - dxSample.centerX) ^ 2 + (py - dxSample.centerY) ^ 2)

            if distance < 80 then
                winCondition:markDXSampleCollected()
                addPickupNotification("Amostra DX coletada", dxSample.centerX, dxSample.centerY, "dx_sample")
                dxSample = nil
            end
        end
    end
    
    if key == "+" or key == "=" then
        if audioManager then
            audioManager:increaseMusicVolume(0.1)
            persistAudioConfig()
        end
    elseif key == "-" or key == "_" then
        if audioManager then
            audioManager:decreaseMusicVolume(0.1)
            persistAudioConfig()
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

function love.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if gameState:isCutscene() then
        if cutscene then
            cutscene:mousepressed(x, y, button)
        end
        return
    end

    if gameState:isMainMenu() then
        if pointInRect(x, y, MainMenu.getStartButton()) then
            startIntroCutscene()
        end
        return
    end

    if gameState:isPaused() then
        local sliders = PauseMenu.getSliders(audioManager)
        for id, slider in pairs(sliders) do
            if PauseMenu.pointInSlider(x, y, slider) then
                draggingAudioSlider = id
                setPauseAudioSlider(id, x)
                return
            end
        end

        local buttons = PauseMenu.getButtons()
        if pointInRect(x, y, buttons.resume) then
            gameState:set(GameState.states.playing)
            playGameplayMusic()
        elseif pointInRect(x, y, buttons.restart) then
            startNewGame()
        end
        return
    end

    if gameState:isGameOver() then
        if pointInRect(x, y, GameOverScreen.getRestartButton()) then
            startNewGame()
        end
        return
    end

    if gameState:isVictory() then
        if pointInRect(x, y, WinScreen.getRestartButton()) then
            startNewGame()
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if gameState and gameState:isPaused() and draggingAudioSlider then
        setPauseAudioSlider(draggingAudioSlider, x)
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        draggingAudioSlider = nil
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
