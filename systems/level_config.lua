local LevelConfig = {
    [1] = {
        name = "Corredores Simples",
        environment = "simple_corridors",
        allowedEnemies = { "normal" },
        allowTurrets = false,
        allowBoss = false,
        killTarget = 5,
        fragmentTarget = 4,
        turretRange = 260
    },
    [2] = {
        name = "Ala de Segurança",
        environment = "security_corridor",
        allowedEnemies = { "normal", "fast" },
        allowTurrets = true,
        allowBoss = false,
        killTarget = 8,
        fragmentTarget = 5,
        turretRange = 260
    },
    [3] = {
        name = "Sala de Contenção",
        environment = "containment_cells",
        allowedEnemies = { "normal", "fast", "brute" },
        allowTurrets = true,
        allowBoss = false,
        killTarget = 12,
        fragmentTarget = 6,
        turretRange = 280
    },
    [4] = {
        name = "Laboratório Central",
        environment = "central_lab",
        allowedEnemies = { "normal", "fast", "brute" },
        allowTurrets = true,
        allowBoss = false,
        killTarget = 15,
        fragmentTarget = 7,
        turretRange = 300
    },
    [5] = {
        name = "Zona Central",
        environment = "central_zone",
        allowedEnemies = { "normal", "fast", "brute" },
        allowTurrets = true,
        allowBoss = true,
        killTarget = 10,
        fragmentTarget = 8,
        turretRange = 300
    }
}

function LevelConfig.getForLevel(level)
    return LevelConfig[level] or LevelConfig[1]
end

return LevelConfig
