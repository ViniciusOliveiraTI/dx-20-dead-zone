-- ============================================
-- AUDIO MANAGER - Sistema de Áudio Desacoplado
-- ============================================
-- Gerencia toda a música e efeitos sonoros do jogo
-- Responsabilidades:
--   - Carregar e tocar música de fundo
--   - Controlar volume de música e efeitos
--   - Reproduzir efeitos sonoros
--   - Pausar/retomar áudio quando o jogo pausa

local AudioManager = {}
AudioManager.__index = AudioManager

-- ============================================
-- Configuração Padrão
-- ============================================
local DEFAULT_CONFIG = {
    musicVolume = 0.7,      -- Volume padrão da música (0.0 a 1.0)
    sfxVolume = 0.8,        -- Volume padrão de efeitos (0.0 a 1.0)
    musicPath = nil,        -- Caminho do arquivo de música
    loopMusic = true,       -- Reproduzir em loop
}

-- ============================================
-- Constructor
-- ============================================
function AudioManager.new(config)
    local self = setmetatable({}, AudioManager)
    
    -- Mesclar configurações
    local finalConfig = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        finalConfig[k] = config and config[k] or v
    end
    
    self.musicVolume = finalConfig.musicVolume
    self.sfxVolume = finalConfig.sfxVolume
    self.musicPath = finalConfig.musicPath
    self.loopMusic = finalConfig.loopMusic
    
    self.currentMusic = nil      -- Áudio da música atual
    self.soundEffects = {}       -- Tabela de efeitos sonoros carregados
    self.activeSounds = {}       -- Sons atualmente tocando
    self.musicPaused = false     -- Estado de pausa da música
    
    return self
end

-- ============================================
-- Métodos de Configuração
-- ============================================

--- Carregar arquivo de música de fundo
-- @param path: caminho do arquivo (ex: "assets/music/background.mp4")
-- @param autoPlay: tocar automaticamente (padrão: true)
function AudioManager:loadMusic(path, autoPlay)
    autoPlay = autoPlay ~= false  -- true por padrão
    
    if not love.filesystem.getInfo(path) then
        print(string.format("[AudioManager] ERRO: Arquivo de música não encontrado: %s", path))
        return false
    end
    
    -- Descarregar música anterior se existir
    if self.currentMusic then
        if self.currentMusic:isPlaying() then
            self.currentMusic:stop()
        end
        self.currentMusic = nil
    end
    
    -- Carregar nova música
    -- LOVE 2D aceita arquivos de áudio em diversos formatos
    -- Para MP4: pode ter problemas em algumas plataformas
    -- Recomendado: converter para OGG ou MP3 para melhor compatibilidade
    local success, source = pcall(function()
        return love.audio.newSource(path, "stream")
    end)
    
    if not success then
        print(string.format("[AudioManager] ERRO ao carregar música: %s", source))
        print("[AudioManager] Dica: Converta o arquivo para OGG ou MP3 para melhor compatibilidade")
        return false
    end
    
    self.currentMusic = source
    self.currentMusic:setLooping(self.loopMusic)
    self.currentMusic:setVolume(self.musicVolume)
    self.musicPaused = false
    
    if autoPlay then
        self.currentMusic:play()
        print(string.format("[AudioManager] ✓ Música carregada e tocando: %s", path))
    else
        print(string.format("[AudioManager] ✓ Música carregada (não tocando): %s", path))
    end
    
    return true
end

--- Carregar efeito sonoro
-- @param name: nome identificador do efeito
-- @param path: caminho do arquivo
function AudioManager:loadSoundEffect(name, path)
    if not love.filesystem.getInfo(path) then
        print(string.format("[AudioManager] ERRO: Arquivo de efeito não encontrado: %s", path))
        return false
    end
    
    local success, source = pcall(function()
        return love.audio.newSource(path, "static")  -- static para efeitos curtos
    end)
    
    if not success then
        print(string.format("[AudioManager] ERRO ao carregar efeito '%s': %s", name, source))
        return false
    end
    
    self.soundEffects[name] = source
    source:setVolume(self.sfxVolume)
    print(string.format("[AudioManager] ✓ Efeito sonoro carregado: %s", name))
    return true
end

-- ============================================
-- Métodos de Reprodução
-- ============================================

--- Tocar música de fundo
function AudioManager:playMusic()
    if not self.currentMusic then
        print("[AudioManager] Nenhuma música carregada")
        return false
    end
    
    if self.currentMusic:isPlaying() then
        print("[AudioManager] Música já está tocando")
        return true
    end
    
    self.currentMusic:play()
    self.musicPaused = false
    return true
end

--- Tocar efeito sonoro
-- @param name: nome do efeito carregado
-- @param volume: volume do efeito (opcional, 0.0 a 1.0)
function AudioManager:playSoundEffect(name, volume)
    if not self.soundEffects[name] then
        print(string.format("[AudioManager] ERRO: Efeito '%s' não carregado", name))
        return false
    end
    
    local sfx = self.soundEffects[name]
    
    -- Definir volume específico se fornecido
    if volume then
        sfx:setVolume(volume)
    else
        sfx:setVolume(self.sfxVolume)
    end
    
    -- Reiniciar o som do início
    sfx:seek(0)
    sfx:play()
    return true
end

-- ============================================
-- Métodos de Controle
-- ============================================

--- Pausar/Retomar música
function AudioManager:toggleMusicPause()
    if not self.currentMusic then
        return
    end
    
    if self.musicPaused then
        self.currentMusic:play()
        self.musicPaused = false
        print("[AudioManager] ✓ Música retomada")
    else
        self.currentMusic:pause()
        self.musicPaused = true
        print("[AudioManager] ✓ Música pausada")
    end
end

--- Pausar música
function AudioManager:pauseMusic()
    if self.currentMusic and not self.musicPaused then
        self.currentMusic:pause()
        self.musicPaused = true
    end
end

--- Retomar música
function AudioManager:resumeMusic()
    if self.currentMusic and self.musicPaused then
        self.currentMusic:play()
        self.musicPaused = false
    end
end

--- Parar música completamente
function AudioManager:stopMusic()
    if self.currentMusic then
        self.currentMusic:stop()
        self.musicPaused = false
    end
end

--- Parar todos os efeitos sonoros
function AudioManager:stopAllSoundEffects()
    for _, sfx in pairs(self.soundEffects) do
        if sfx:isPlaying() then
            sfx:stop()
        end
    end
end

-- ============================================
-- Métodos de Volume
-- ============================================

--- Definir volume da música
-- @param volume: 0.0 (silencioso) a 1.0 (máximo)
function AudioManager:setMusicVolume(volume)
    volume = math.max(0, math.min(1, volume))  -- Clamp entre 0 e 1
    self.musicVolume = volume
    
    if self.currentMusic then
        self.currentMusic:setVolume(volume)
    end
    
    print(string.format("[AudioManager] Volume da música: %.0f%%", volume * 100))
end

--- Definir volume de efeitos sonoros
-- @param volume: 0.0 (silencioso) a 1.0 (máximo)
function AudioManager:setSFXVolume(volume)
    volume = math.max(0, math.min(1, volume))  -- Clamp entre 0 e 1
    self.sfxVolume = volume
    
    for _, sfx in pairs(self.soundEffects) do
        sfx:setVolume(volume)
    end
    
    print(string.format("[AudioManager] Volume de efeitos: %.0f%%", volume * 100))
end

--- Aumentar volume da música
-- @param amount: quanto aumentar (0.0 a 1.0)
function AudioManager:increaseMusicVolume(amount)
    self:setMusicVolume(self.musicVolume + amount)
end

--- Diminuir volume da música
-- @param amount: quanto diminuir (0.0 a 1.0)
function AudioManager:decreaseMusicVolume(amount)
    self:setMusicVolume(self.musicVolume - amount)
end

--- Aumentar volume de efeitos
-- @param amount: quanto aumentar (0.0 a 1.0)
function AudioManager:increaseSFXVolume(amount)
    self:setSFXVolume(self.sfxVolume + amount)
end

--- Diminuir volume de efeitos
-- @param amount: quanto diminuir (0.0 a 1.0)
function AudioManager:decreaseSFXVolume(amount)
    self:setSFXVolume(self.sfxVolume - amount)
end

-- ============================================
-- Métodos de Información
-- ============================================

--- Obter volume da música
function AudioManager:getMusicVolume()
    return self.musicVolume
end

--- Obter volume de efeitos
function AudioManager:getSFXVolume()
    return self.sfxVolume
end

--- Verificar se música está tocando
function AudioManager:isMusicPlaying()
    return self.currentMusic and self.currentMusic:isPlaying() and not self.musicPaused
end

--- Verificar se música está pausada
function AudioManager:isMusicPaused()
    return self.musicPaused
end

--- Obter tempo atual da música (em segundos)
function AudioManager:getMusicTime()
    if self.currentMusic then
        return self.currentMusic:tell()
    end
    return 0
end

--- Obter duração total da música (em segundos)
function AudioManager:getMusicDuration()
    if self.currentMusic then
        return self.currentMusic:getDuration()
    end
    return 0
end

-- ============================================
-- Métodos de Atualização
-- ============================================

--- Chamar a cada frame (não é obrigatório, mas recomendado para futuras melhorias)
function AudioManager:update(dt)
    -- Reservado para futuras funcionalidades
    -- Como fade in/out, crossfade entre músicas, etc
end

-- ============================================
-- Métodos de Limpeza
-- ============================================

--- Descarregar tudo (chamar ao sair do jogo)
function AudioManager:destroy()
    self:stopMusic()
    self:stopAllSoundEffects()
    self.currentMusic = nil
    self.soundEffects = {}
    print("[AudioManager] ✓ Áudio descarregado")
end

return AudioManager