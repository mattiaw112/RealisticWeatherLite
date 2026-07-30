-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE - WHEEL PHYSICS (Solo Neve)
-------------------------------------------------------------------------------
RW_WheelPhysics = {}

function RW_WheelPhysics:updateFriction(_, _, groundWetness)
    -- Se non c'è contatto con la neve o l'altezza della neve è zero/assente, esce subito e lascia la fisica originale intatta
    if not self.hasSnowContact or (self.snowHeight or 0) <= 0 then
        return
    end

    local snowFactor = 1 + (self.snowHeight * 0.33)
    local densityType = self.densityType ~= FieldGroundType.NONE
    local ground = WheelsUtil.getGroundType(densityType, self.contact ~= WheelContactType.GROUND, self.groundDepth)
    
    local tireType = self.tireType or 0
    local friction = WheelsUtil.getTireFriction(tireType, ground, 0, snowFactor)

    -- Controllo blindato e sicuro al 100% per i cingolati
    local isCrawler = false
    if WheelTireType ~= nil and WheelTireType.CRAWLER ~= nil then
        isCrawler = (tireType == WheelTireType.CRAWLER)
    end
    isCrawler = isCrawler or (self.crawler ~= nil) or (self.isCrawler == true)

    if not isCrawler then
        local width = self.width or 0
        if self.vehicle and self.vehicle.spec_wheels and self.vehicle.spec_wheels.wheels then
            local mass = self.vehicle:getTotalMass()
            local totalWheels = #self.vehicle.spec_wheels.wheels
            if totalWheels > 0 then
                local widthToMassRatio = math.min(width / (mass / totalWheels), 1)

                friction = friction / (1.5 - math.min(width, 1))

                if mass < 8 then
                    if widthToMassRatio > 0.06 and widthToMassRatio < 0.12 then
                        friction = friction * (1 + (width / 5))
                    else
                        friction = friction * (1 - (width / 5))
                    end
                end
            end
        end
    end

    local timeSinceLastRain = g_currentMission and g_currentMission.environment and g_currentMission.environment.weather and g_currentMission.environment.weather.timeSinceLastRain or 0
    friction = friction / math.clamp(timeSinceLastRain / 1440, 1, 3)

    if self.vehicle and self.vehicle.getLastSpeed and self.vehicle:getLastSpeed() > 0.2 and friction ~= self.tireGroundFrictionCoeff then
        self.tireGroundFrictionCoeff = friction
        self.isFrictionDirty = true
    end
end

if WheelPhysics ~= nil and WheelPhysics.updateFriction ~= nil then
    WheelPhysics.updateFriction = Utils.overwrittenFunction(WheelPhysics.updateFriction, RW_WheelPhysics.updateFriction)
end