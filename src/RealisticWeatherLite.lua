RW_Weather = {}
RW_Weather.FACTOR = {
    SNOW_FACTOR = 0.0005,
    SNOW_HEIGHT = 1.0
}

SnowSystem.MAX_HEIGHT = RW_Weather.FACTOR.SNOW_HEIGHT

-------------------------------------------------------------------------------
-- UPDATE PRINCIPALE: Gestione Neve e Danni da Grandine
-------------------------------------------------------------------------------
function RW_Weather:update(_, dT)
    local timescale = dT * g_currentMission:getEffectiveTimeScale()

    ---------------------------------------------------------------------------
    -- 1. GESTIONE NEVE
    ---------------------------------------------------------------------------
    local temperature = self.temperatureUpdater:getTemperatureAtTime(self.owner.dayTime)
    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)

    if g_currentMission.missionInfo.isSnowEnabled then
        local blizzardFactor = (currentWeather ~= nil and currentWeather.isBlizzard) and 10 or 1
        self.isBlizzard = currentWeather ~= nil and currentWeather.isBlizzard

        if self:getIsSnowing() and temperature < 10 then
            local scale = 1 - temperature * 0.1
            self.snowHeight = math.clamp(
                self.snowHeight + RW_Weather.FACTOR.SNOW_FACTOR * (timescale / 100000) * self:getSnowFallScale() * scale * blizzardFactor,
                0, 
                RW_Weather.FACTOR.SNOW_HEIGHT
            )
        elseif temperature >= 10 then
            self.snowHeight = 0
            g_currentMission.snowSystem:removeAll()
        elseif temperature > 0 and self.snowHeight > 0 then
            local scale = self:getIsRaining() and math.max(5 / self:getRainFallScale(), 1.25) or 1
            self.snowHeight = math.clamp(
                self.snowHeight - temperature * 0.001 * (timescale / 100000) * scale, 
                0, 
                RW_Weather.FACTOR.SNOW_HEIGHT
            )
            if self.snowHeight == 0 then 
                g_currentMission.snowSystem:removeAll() 
            end
        end
    else
        self.snowHeight = math.max(self.snowHeight - 0.005 * (dT / 1000) * (g_currentMission:getEffectiveTimeScale() / 100), 0)
        self.isBlizzard = false
    end

    -- Applica l'altezza della neve visibile sul terreno
    g_currentMission.snowSystem:setSnowHeight(self.snowHeight)

    ---------------------------------------------------------------------------
    -- 2. GESTIONE DANNI DA GRANDINE (Rallentati e bilanciati)
    ---------------------------------------------------------------------------
    -- Controllo se l'opzione è attiva dal menu delle impostazioni
    if _G.getModSettings("hailDamage_enabled") then
        local hail = self:getHailFallScale()
        local indoorMask = g_currentMission.indoorMask

        if hail > 0 then
            local vehicles = g_currentMission.vehicleSystem.vehicles

            for _, vehicle in pairs(vehicles) do
                local wearable = vehicle.spec_wearable
                if wearable ~= nil then
                    local x, _, z = getWorldTranslation(vehicle.rootNode)

                    -- Se il veicolo è al coperto (sotto una tettoia), non subisce danni
                    if x ~= nil and z ~= nil and not indoorMask:getIsIndoorAtWorldPosition(x, z) then
                        -- Valori ridotti per non distruggere i veicoli troppo velocemente
                        local damageAmount = hail * 0.0001 * (timescale / 100000)
                        local wearAmount = hail * 0.0003 * (timescale / 100000)
                        
                        wearable:addWearAmount(wearAmount, true)
                        wearable:addDamageAmount(damageAmount, true)
                    end
                end
            end
        end
    end
end

Weather.update = Utils.overwrittenFunction(Weather.update, RW_Weather.update)

-------------------------------------------------------------------------------
-- GESTIONE NEBBIA FITTA
-------------------------------------------------------------------------------
function RW_Weather:randomizeFog(_, time)
    if not g_currentMission:getIsServer() then return end

    local season = self.owner.currentSeason
    local seasonToFog = self.seasonToFog[season]
    local currentDay = g_currentMission.environment.currentMonotonicDay
    local fog

    self.lastFogDay = self.lastFogDay or 0

    if seasonToFog == nil or currentDay == self.lastFogDay + 1 then
        fog = nil
    else
        fog = seasonToFog:createFromTemplate()

        -- Genera la nebbia fitta tranne in Estate (stagione 2)
        if season ~= 2 and math.random() >= 0.85 then -- Aumentata leggermente la probabilità (15%)
            fog.groundFogCoverageEdge0 = math.random(5, 10) / 100
            fog.groundFogCoverageEdge1 = math.random(90, 95) / 100
            fog.groundFogExtraHeight = math.random(25, 35)
            fog.groundFogGroundLevelDensity = math.random(85, 200) / 100
            fog.heightFogMaxHeight = math.random(650, 800)
            fog.heightFogGroundLevelDensity = math.random(75, 190) / 100
            fog.groundFogEndDayTimeMinutes = math.min(math.random(fog.groundFogStartDayTimeMinutes + 120, fog.groundFogStartDayTimeMinutes + 860), 1439)

            -- Abilita la nebbia durante pioggia e neve
            fog.groundFogWeatherTypes[WeatherType.SNOW] = true
            fog.groundFogWeatherTypes[WeatherType.RAIN] = true

            self.lastFogDay = currentDay
        end
    end

    self.fogUpdater:setTargetFog(fog, time)
end

Weather.randomizeFog = Utils.overwrittenFunction(Weather.randomizeFog, RW_Weather.randomizeFog)

-------------------------------------------------------------------------------
-- SALVATAGGIO E SINCRONIZZAZIONE
-------------------------------------------------------------------------------
function RW_Weather:setInitialState(_, snowHeight, timeSinceLastRain, lastFogDay)
    self.snowHeight = snowHeight
    self.timeSinceLastRain = timeSinceLastRain
    self.lastFogDay = lastFogDay
    g_currentMission.snowSystem:setSnowHeight(self.snowHeight)
end

Weather.setInitialState = Utils.overwrittenFunction(Weather.setInitialState, RW_Weather.setInitialState)

function RW_Weather:saveToXMLFile(handle, key)
    local xmlFile = XMLFile.wrap(handle)
    if xmlFile ~= nil then
        xmlFile:setInt(key .. "#lastFogDay", self.lastFogDay or 0)
        xmlFile:save(false, true)
        xmlFile:delete()
    end
end

Weather.saveToXMLFile = Utils.appendedFunction(Weather.saveToXMLFile, RW_Weather.saveToXMLFile)

function RW_Weather:loadFromXMLFile(handle, key)
    local xmlFile = XMLFile.wrap(handle)
    if xmlFile ~= nil then
        self.lastFogDay = xmlFile:getInt(key .. "#lastFogDay", 0)
        xmlFile:delete()
    end
end

Weather.loadFromXMLFile = Utils.prependedFunction(Weather.loadFromXMLFile, RW_Weather.loadFromXMLFile)