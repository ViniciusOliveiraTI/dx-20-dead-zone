local ZombieTypes = {
    normal = {
        speed = 90,
        damage = 14,
        health = 55,
        color = {0.3, 0.8, 0.3}
    },
    fast = {
        speed = 160,
        damage = 8,
        health = 30,
        color = {0.8, 0.8, 0.3}
    },
    brute = {
        speed = 45,
        damage = 24,
        health = 160,
        color = {0.5, 0.3, 0.3}
    },
    boss = {
        speed = 35,
        meleeDamage = 35,
        rangedDamage = 20,
        health = 650,
        color = {0.8, 0.1, 0.1},
        meleeRange = 70,
        rangedRange = 250,
        meleeCooldown = 1.2,
        rangedCooldown = 10.0
    }
}

return ZombieTypes