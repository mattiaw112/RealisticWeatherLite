if RealisticWeatherLite == nil then
    RealisticWeatherLite = {}
end

RealisticWeatherLite.hailNotified = false
RealisticWeatherLite.snowNotified = false

function RealisticWeatherLite:getModSettingSafe(name, default)
    if _G.getModSettings ~= nil then
        return _G.getModSettings(name)
    end
    return default
end

function RealisticWeatherLite:onPostLoad(savegame)
    print("--- [RealisticWeatherLite] MOD CARICATA E IN ESECUZIONE ---")
end

function RealisticWeatherLite:applyCustomFog(env, dt)
    if env == nil then return end
    
    local isRaining = false
    if env.getIsRaining ~= nil then
        isRaining = env:getIsRaining()
    elseif env.weather ~= nil and env.weather.isRaining ~= nil then
        isRaining = env.weather.isRaining
    end
    
    local dayTime = env.dayTime
    local isMorning = (dayTime >= 18000000 and dayTime <= 32400000)
    
    local targetDensity = (isMorning or isRaining) and 0.2 or 0.05
    local targetDistance = (isMorning or isRaining) and 300 or 1000

    if env.setFog ~= nil then
        env:setFog(targetDensity, targetDistance) 
    end
end

function RealisticWeatherLite:update(dt)
    if g_currentMission == nil or g_currentMission.environment == nil then return end
    
    local env = g_currentMission.environment
    local notify = self:getModSettingSafe("notifications_enabled", true)
    local isHailEnabled = self:getModSettingSafe("hailDamage_enabled", true)

    self:applyCustomFog(env, dt)

    local isSnowing = false
    if env.getIsSnowing ~= nil then
        isSnowing = env:getIsSnowing()
    elseif env.weather ~= nil then
        isSnowing = env.weather.isSnowing or false
    end
    
    if isSnowing then
        if env.setSnowCover ~= nil then env:setSnowCover(1.0, 0.001) end
        if not self.snowNotified and notify then
            g_currentMission:showInGameMessage("Meteo", "Bufera in corso!", 5000)
            self.snowNotified = true
        end
    else
        if env.setSnowCover ~= nil then env:setSnowCover(nil, 0.05) end
        self.snowNotified = false
    end

    if isHailEnabled then
        local hail = (env.getHailFallScale ~= nil) and env:getHailFallScale() or 0
        local indoorMask = g_currentMission.indoorMask
        if hail > 0 and indoorMask ~= nil then
            if not self.hailNotified and notify then
                g_currentMission:showInGameMessage("Meteo", "Grandine in arrivo!", 5000)
                self.hailNotified = true
            end

            if g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles ~= nil then
                local vehicles = g_currentMission.vehicleSystem.vehicles
                for _, vehicle in pairs(vehicles) do
                    if vehicle.spec_wearable ~= nil and vehicle.rootNode ~= nil then
                        local wearable = vehicle.spec_wearable
                        local x, _, z = getWorldTranslation(vehicle.rootNode)
                        if not indoorMask:getIsIndoorAtWorldPosition(x, z) then
                            local damageAmount = hail * 0.0006 * (dt / 16.67)
                            local wearAmount = hail * 0.0018 * (dt / 16.67)
                            wearable:addWearAmount(wearAmount)
                            wearable:addDamageAmount(damageAmount)
                        end
                    end
                end
            end
        else
            self.hailNotified = false
        end
    end
end

addModEventListener(RealisticWeatherLite)