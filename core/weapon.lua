local Weapon = {}
Weapon.__index = Weapon

function Weapon.new(config)
    local self = setmetatable({}, Weapon)

    self.clipSize = config.clipSize or 12
    self.clipAmmo = self.clipSize
    self.reserveAmmo = config.reserveAmmo or 48
    self.maxReserveAmmo = config.maxReserveAmmo or 90

    self.fireRate = config.fireRate or 0.3
    self.reloadTime = config.reloadTime or 1.5

    self.timeSinceLastShot = self.fireRate
    self.reloadTimer = 0
    self.isReloading = false

    return self
end

function Weapon:update(dt)
    self.timeSinceLastShot = self.timeSinceLastShot + dt

    if self.isReloading then
        self.reloadTimer = self.reloadTimer + dt
        if self.reloadTimer >= self.reloadTime then
            self:finishReload()
        end
    end
end

function Weapon:canShoot()
    return not self.isReloading
        and self.clipAmmo > 0
        and self.timeSinceLastShot >= self.fireRate
end

function Weapon:shoot()
    if not self:canShoot() then
        return false
    end

    self.clipAmmo = self.clipAmmo - 1
    self.timeSinceLastShot = 0

    if self.clipAmmo == 0 then
        self:reload()
    end

    return true
end

function Weapon:reload()
    if self.isReloading then
        return
    end

    if self.reserveAmmo <= 0 then
        return
    end

    if self.clipAmmo == self.clipSize then
        return
    end

    self.isReloading = true
    self.reloadTimer = 0
end

function Weapon:finishReload()
    local needed = self.clipSize - self.clipAmmo
    local ammoToLoad = math.min(needed, self.reserveAmmo)

    self.clipAmmo = self.clipAmmo + ammoToLoad
    self.reserveAmmo = self.reserveAmmo - ammoToLoad
    self.isReloading = false
end

function Weapon:addReserve(amount)
    if amount <= 0 then
        return
    end

    self.reserveAmmo = math.min(self.reserveAmmo + amount, self.maxReserveAmmo)
end

return Weapon
