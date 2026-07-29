-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE - WHEEL PHYSICS (Solo Neve)
-------------------------------------------------------------------------------
RW_WheelPhysics = {}

function RW_WheelPhysics:updateFriction(_, _, groundWetness)
    if not self.hasSnowContact then
        return
    end

    local snowFactor = self.snowHeight ~= nil and (1 + (self.snowHeight * 0.33)) or 1
    local densityType = self.densityType ~= FieldGroundType.NONE
    local ground = WheelsUtil.getGroundType(densityType, self.contact ~= WheelContactType.GROUND, self.groundDepth)
    
    local friction = WheelsUtil.getTireFriction(self.tireType, ground, 0, snowFactor)

    local width = self.width
    local mass = self.vehicle:getTotalMass()
    local widthToMassRatio = math.min(width / (mass / #self.vehicle.spec_wheels.wheels), 1)

    friction = friction / (1.5 - math.min(width, 1))

    if mass < 8 then
        if widthToMassRatio > 0.06 and widthToMassRatio < 0.12 then
            friction = friction * (1 + (width / 5))
        else
            friction = friction * (1 - (width / 5))
        end
    end

    local timeSinceLastRain = g_currentMission.environment.weather.timeSinceLastRain or 0
    friction = friction / math.clamp(timeSinceLastRain / 1440, 1, 3)

    if self.vehicle:getLastSpeed() > 0.2 and friction ~= self.tireGroundFrictionCoeff then
        self.tireGroundFrictionCoeff = friction
        self.isFrictionDirty = true
    end
end

if WheelPhysics ~= nil and WheelPhysics.updateFriction ~= nil then
    WheelPhysics.updateFriction = Utils.overwrittenFunction(WheelPhysics.updateFriction, RW_WheelPhysics.updateFriction)
end