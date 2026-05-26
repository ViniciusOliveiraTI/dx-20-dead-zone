-- ============================================
-- AUDIO CONFIG - Configurações de Áudio Persistentes
-- ============================================
-- Salva e carrega configurações de volume do jogo
-- Usa love.filesystem para persistência entre sessões

local AudioConfig = {}

-- Arquivo onde as configurações serão salvas
local CONFIG_FILE = "audio_config.json"

-- ============================================
-- Configuração Padrão
-- ============================================
local DEFAULT_CONFIG = {
    musicVolume = 0.3,
    sfxVolume = 0.4,
    musicEnabled = true,
    sfxEnabled = true
}

-- ============================================
-- Carregar Configurações
-- ============================================

function AudioConfig.load()
    local config = {}
    
    -- Usar padrões se arquivo não existir
    for k, v in pairs(DEFAULT_CONFIG) do
        config[k] = v
    end
    
    -- Tentar carregar arquivo salvo
    if love.filesystem.getInfo(CONFIG_FILE) then
        local content = love.filesystem.read(CONFIG_FILE)
        local success, loaded = pcall(function()
            return require("json").decode(content)
        end)
        
        if success then
            -- Mesclar com padrões (respeita valores salvos)
            for k, v in pairs(loaded) do
                if config[k] ~= nil then
                    config[k] = v
                end
            end
            print("[AudioConfig] ✓ Configurações carregadas")
        else
            print("[AudioConfig] Aviso: Não foi possível carregar config, usando padrões")
        end
    else
        print("[AudioConfig] Primeira execução, usando configurações padrão")
    end
    
    return config
end

-- ============================================
-- Salvar Configurações
-- ============================================

function AudioConfig.save(config)
    local success, json = pcall(function()
        return require("json").encode(config)
    end)
    
    if success then
        love.filesystem.write(CONFIG_FILE, json)
        print("[AudioConfig] ✓ Configurações salvas")
        return true
    else
        print("[AudioConfig] ERRO ao salvar configurações")
        return false
    end
end

-- ============================================
-- Resetar para Padrão
-- ============================================

function AudioConfig.reset()
    local config = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        config[k] = v
    end
    
    AudioConfig.save(config)
    print("[AudioConfig] ✓ Configurações resetadas para padrão")
    return config
end

return AudioConfig