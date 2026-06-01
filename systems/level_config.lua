local LevelConfig = {
    [1] = {
        name = "Corredores Simples",
        introTitle = "Fase 1 - Corredores Simples",
        introDescription = "O primeiro sinal de vida ecoa onde a luz quase desistiu.",
        environment = "simple_corridors",
        allowedEnemies = { "normal" },
        allowTurrets = false,
        allowBoss = false,
        killTarget = 1,
        fragmentTarget = 1,
        turretRange = 260
    },
    [2] = {
        name = "Ala de Segurança",
        introTitle = "Fase 2 - Ala de Segurança",
        introDescription = "Portas seladas, sensores vivos e algo errado no protocolo.",
        environment = "security_corridor",
        allowedEnemies = { "normal", "fast" },
        allowTurrets = true,
        allowBoss = false,
        killTarget = 1,
        fragmentTarget = 1,
        turretRange = 260
    },
    [3] = {
        name = "Sala de Contenção",
        introTitle = "Fase 3 - Sala de Contenção",
        introDescription = "As celas abriram antes que alguem pudesse apagar os registros.",
        environment = "containment_cells",
        allowedEnemies = { "normal", "fast", "brute" },
        allowTurrets = true,
        allowBoss = false,
        killTarget = 1,
        fragmentTarget = 1,
        turretRange = 280
    },
    [4] = {
        name = "Laboratório Central",
        introTitle = "Fase 4 - Laboratório Central",
        introDescription = "No coracao da pesquisa, cada parede guarda uma decisao ruim.",
        environment = "central_lab",
        allowedEnemies = { "normal", "fast", "brute" },
        allowTurrets = true,
        allowBoss = false,
        killTarget = 1,
        fragmentTarget = 1,
        turretRange = 300
    },
    [5] = {
        name = "Zona Central",
        introTitle = "Fase 5 - Zona Central",
        introDescription = "A origem da contaminacao pulsa atras da ultima porta.",
        environment = "central_zone",
        allowedEnemies = { "normal", "fast", "brute" },
        allowTurrets = true,
        allowBoss = true,
        killTarget = 1,
        fragmentTarget = 1,
        turretRange = 300
    }
}

function LevelConfig.getForLevel(level)
    return LevelConfig[level] or LevelConfig[1]
end

return LevelConfig
