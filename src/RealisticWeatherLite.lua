if RealisticWeatherLite == nil then
    RealisticWeatherLite = {}
end

RealisticWeatherLite.hailNotified = false
RealisticWeatherLite.snowNotified = false

-------------------------------------------------------------------------------
-- LETTURA SICURA DELLE IMPOSTAZIONI DA settings.lua
-------------------------------------------------------------------------------
function RealisticWeatherLite:getModSettingSafe(name, default)
    if _G.getModSettings ~= nil then
        return _G.getModSettings(name)
    end
    return default
end

function RealisticWeatherLite:onPostLoad(savegame)
    print("--- [RealisticWeatherLite] MOD CARICATA E IN ESECUZIONE CON IMPOSTAZIONI ---")
end

-------------------------------------------------------------------------------
-- 1. NEBBIA DENSA E DINAMICA
-------------------------------------------------------------------------------
function RealisticWeatherLite:applyCustomFog(env, dt)
    if env == nil then return end

    local isRaining = false
    if env.getIsRaining ~= nil then
        isRaining = env:getIsRaining()
    elseif env.weather ~= nil and env.weather.isRaining ~= nil then
        isRaining = env.weather.isRaining
    end

    local dayTime = env.dayTime or 0
    -- Nebbia densa al mattino (5:00 - 9:00) o durante la pioggia
    local isMorning = (dayTime >= 18000000 and dayTime <= 32400000)

    local targetDensity = (isMorning or isRaining) and 0.2 or 0.05
    local targetDistance = (isMorning or isRaining) and 300 or 1000

    if env.setFog ~= nil then
        env:setFog(targetDensity, targetDistance)
    end
end

-------------------------------------------------------------------------------
-- 2. UPDATE PRINCIPALE CON CONTROLLI DA MENU OPZIONI E TIMESCALE (FINO A 360x)
-------------------------------------------------------------------------------
function RealisticWeatherLite:update(dt)
    if g_currentMission == nil or g_currentMission.environment == nil then return end

    local env = g_currentMission.environment
    
    -- Legge le impostazioni modificate nel menu di gioco via settings.lua
    local notify = self:getModSettingSafe("notifications_enabled", true)
    local isHailEnabled = self:getModSettingSafe("hailDamage_enabled", true)

    -- Applicazione nebbia
    self:applyCustomFog(env, dt)

    ---------------------------------------------------------------------------
    -- NEVE PROFONDA E NOTIFICHE
    ---------------------------------------------------------------------------
    local isSnowing = false
    if env.getIsSnowing ~= nil then
        isSnowing = env:getIsSnowing()
    elseif env.weather ~= nil then
        isSnowing = env.weather.isSnowing or false
    end

    if isSnowing then
        -- Neve profonda 1 metro
        if env.setSnowCover ~= nil then 
            env:setSnowCover(1.0, 0.001) 
        end
        
        if not self.snowNotified and notify then
            if g_currentMission.showInGameMessage ~= nil then
                g_currentMission:showInGameMessage("Meteo", "Bufera di neve in corso!", 5000)
            end
            self.snowNotified = true
        end
    else
        if env.setSnowCover ~= nil then 
            env:setSnowCover(nil, 0.05) 
        end
        self.snowNotified = false
    end

    ---------------------------------------------------------------------------
    -- GRANDINE: USURA E DANNI AI VEICOLI ADATTIVI AL TEMPO DI GIOCO
    ---------------------------------------------------------------------------
    if isHailEnabled then
        local hail = 0
        if env.getHailFallScale ~= nil then
            hail = env:getHailFallScale()
        elseif env.weather ~= nil and env.weather.getHailFallScale ~= nil then
            hail = env.weather:getHailFallScale()
        end

        local indoorMask = g_currentMission.indoorMask
        
        if hail > 0 then
            if not self.hailNotified and notify then
                if g_currentMission.showInGameMessage ~= nil then
                    g_currentMission:showInGameMessage("Meteo", "Grandine in arrivo! Metti al riparo i veicoli.", 5000)
                end
                self.hailNotified = true
            end

            -- Recupero dinamico della velocità del tempo della partita (es: 1x, 5x, 60x fino a 360x)
            local timeScale = 1
            if g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.timeScale ~= nil then
                timeScale = g_currentMission.missionInfo.timeScale
            end

            -- Calcolo del danno e dell'usura per i veicoli all'aperto
            if g_currentMission.vehicleSystem ~= nil and g_currentMission.vehicleSystem.vehicles ~= nil then
                local vehicles = g_currentMission.vehicleSystem.vehicles
                for _, vehicle in pairs(vehicles) do
                    if vehicle.spec_wearable ~= nil and vehicle.rootNode ~= nil then
                        local wearable = vehicle.spec_wearable
                        local x, _, z = getWorldTranslation(vehicle.rootNode)

                        local isIndoor = false
                        if indoorMask ~= nil and indoorMask.getIsIndoorAtWorldPosition ~= nil then
                            isIndoor = indoorMask:getIsIndoorAtWorldPosition(x, z)
                        end

                        if not isIndoor then
                            -- Inserito * timeScale: il danno e l'usura scalano con la velocità del tempo scelta
                            local damageAmount = hail * 0.0004 * (dt / 16.67) * timeScale
                            local wearAmount = hail * 0.0010 * (dt / 16.67) * timeScale

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

-- Registrazione dell'evento nel motore di gioco
addModEventListener(RealisticWeatherLite)