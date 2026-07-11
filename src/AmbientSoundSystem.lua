RW_AmbientSoundSystem = {}
local modDirectory = g_currentModDirectory


function RW_AmbientSoundSystem:updateMask()

    local weather = g_currentMission.environment.weather
    local rainfall = weather:getRainFallScale()

    self.conditionFlags:setModifierValue("blizzard", weather.isBlizzard or false)
    self.conditionFlags:setModifierValue("rain", rainfall >= 0.33 and rainfall < 0.67)
    self.conditionFlags:setModifierValue("heavyRain", rainfall >= 0.67)
    self.conditionFlags:setModifierValue("lightRain", rainfall < 0.33 and rainfall > 0)
    self.conditionFlags:setModifierValue("anyRain", rainfall > 0)

end

AmbientSoundSystem.updateMask = Utils.appendedFunction(AmbientSoundSystem.updateMask, RW_AmbientSoundSystem.updateMask)


function RW_AmbientSoundSystem:loadFromConfigFile(superFunc)

    local returnValue = superFunc(self)

    if not returnValue then return false end

    local xmlFile = XMLFile.loadIfExists("rwAmbientSounds", modDirectory .. "xml/sounds.xml", AmbientSoundSystem.xmlSchema)

    if xmlFile == nil then return returnValue end

    self.conditionFlags:registerModifier("blizzard", nil)
    self.conditionFlags:registerModifier("heavyRain", nil)
    self.conditionFlags:registerModifier("lightRain", nil)
    self.conditionFlags:registerModifier("anyRain", nil)

    for _, key in xmlFile:iterator("sound.ambient.sample") do

        local filename = xmlFile:getValue(key .. "#filename")
        local probability = xmlFile:getValue(key .. "#probability", 1)
        local positionTag = xmlFile:getValue(key .. "#positionTag", "")
        local radius = xmlFile:getValue(key .. "#radius", 0)
        local innerRadius = xmlFile:getValue(key .. "#innerRadius", 0)
        local audioGroupName = xmlFile:getValue(key .. ".settings#audioGroup", "ENVIRONMENT")
        local fadeInTime = xmlFile:getValue(key .. ".settings#fadeInTime", 0)
        local fadeOutTime = xmlFile:getValue(key .. ".settings#fadeOutTime", 0)
        local minVolume = xmlFile:getValue(key .. ".settings#minVolume", 1)
        local maxVolume = xmlFile:getValue(key .. ".settings#maxVolume", 1)
        local indoorVolume = xmlFile:getValue(key .. ".settings#indoorVolume", 0.8)
        local minLoops = xmlFile:getValue(key .. ".settings#minLoops", 1)
        local maxLoops = xmlFile:getValue(key .. ".settings#maxLoops", 1)
        local minRetriggerDelaySeconds = xmlFile:getValue(key .. ".settings#minRetriggerDelaySeconds", 0)
        local maxRetriggerDelaySeconds = xmlFile:getValue(key .. ".settings#maxRetriggerDelaySeconds", 0)
        local minPitch = xmlFile:getValue(key .. ".settings#minPitch", 1)
        local maxPitch = xmlFile:getValue(key .. ".settings#maxPitch", 1)
        local minDelay = xmlFile:getValue(key .. ".settings#minDelay", 0)
        local maxDelay = xmlFile:getValue(key .. ".settings#maxDelay", 0)
        local minLength = xmlFile:getValue(key .. ".settings#minLength", 0)
        local maxLength = xmlFile:getValue(key .. ".settings#maxLength", 0)
        local minTimeOfDay = xmlFile:getValue(key .. ".settings#minTimeOfDay", 0)
        local maxTimeOfDay = xmlFile:getValue(key .. ".settings#maxTimeOfDay", 1440)
        local minDayOfYear = xmlFile:getValue(key .. ".settings#minDayOfYear", 0)
        local maxDayOfYear = xmlFile:getValue(key .. ".settings#maxDayOfYear", 365)
        local audioGroup = AudioGroup.getAudioGroupIndexByName(audioGroupName)

        if audioGroup == nil then audioGroup = AudioGroup.ENVIRONMENT end

        local path = Utils.getFilename(filename, modDirectory)
        local requiredFlags, preventFlags = self.conditionFlags:loadFlagsFromXMLFile(xmlFile, key)
        local sampleId = ambientSoundsAddSample(self.soundPlayerId, audioGroup, minRetriggerDelaySeconds, maxRetriggerDelaySeconds, requiredFlags, preventFlags, minTimeOfDay, maxTimeOfDay, minDayOfYear, maxDayOfYear, positionTag or "", radius or 0, innerRadius or 0)
        local sampleVariationId = ambientSoundsAddSampleVariation(self.soundPlayerId, sampleId, path, probability)
        ambientSoundsSampleSetIndoorVolumeFactor(self.soundPlayerId, sampleId, sampleVariationId, indoorVolume)
        ambientSoundsSampleSetFadeInOutTime(self.soundPlayerId, sampleId, sampleVariationId, fadeInTime, fadeOutTime)
        ambientSoundsSampleSetMinMaxVolume(self.soundPlayerId, sampleId, sampleVariationId, minVolume, maxVolume)
        ambientSoundsSampleSetMinMaxLoops(self.soundPlayerId, sampleId, sampleVariationId, minLoops, maxLoops)
        ambientSoundsSampleSetMinMaxPitch(self.soundPlayerId, sampleId, sampleVariationId, minPitch, maxPitch)
        ambientSoundsSampleSetMinMaxDelay(self.soundPlayerId, sampleId, sampleVariationId, minDelay, maxDelay)
        ambientSoundsSampleSetMinMaxLength(self.soundPlayerId, sampleId, sampleVariationId, minLength, maxLength)

        for _, variationKey in xmlFile:iterator(key .. ".variation") do

            local variationFilename = xmlFile:getValue(variationKey .. "#filename")
            local variationProbability = xmlFile:getValue(variationKey .. "#probability", 1)
            local variationFadeInTime = xmlFile:getValue(variationKey .. "#fadeInTime", fadeInTime)
            local variationFadeOutTime = xmlFile:getValue(variationKey .. "#fadeOutTime", fadeOutTime)
            local variationMinVolume = xmlFile:getValue(variationKey .. "#minVolume", minVolume)
            local variationMaxVolume = xmlFile:getValue(variationKey .. "#maxVolume", maxVolume)
            local variationIndoorVolume = xmlFile:getValue(variationKey .. "#indoorVolume", indoorVolume)
            local variationMinLoops = xmlFile:getValue(variationKey .. "#minLoops", minLoops)
            local variationMaxLoops = xmlFile:getValue(variationKey .. "#maxLoops", maxLoops)
            local variationMinPitch = xmlFile:getValue(variationKey .. "#minPitch", minPitch)
            local variationMaxPitch = xmlFile:getValue(variationKey .. "#maxPitch", maxPitch)
            local variationMinDelay = xmlFile:getValue(variationKey .. "#minDelay", minDelay)
            local variationMaxDelay = xmlFile:getValue(variationKey .. "#maxDelay", maxDelay)
            local variationMinLength = xmlFile:getValue(variationKey .. "#minLength", minLength)
            local variationMaxLength = xmlFile:getValue(variationKey .. "#maxLength", maxLength)
            local variationPath = Utils.getFilename(variationFilename, modDirectory)
            local variationSampleVariationId = ambientSoundsAddSampleVariation(self.soundPlayerId, sampleId, variationPath, variationProbability)

            ambientSoundsSampleSetIndoorVolumeFactor(self.soundPlayerId, sampleId, variationSampleVariationId, variationIndoorVolume)
            ambientSoundsSampleSetFadeInOutTime(self.soundPlayerId, sampleId, variationSampleVariationId, variationFadeInTime, variationFadeOutTime)
            ambientSoundsSampleSetMinMaxVolume(self.soundPlayerId, sampleId, variationSampleVariationId, variationMinVolume, variationMaxVolume)
            ambientSoundsSampleSetMinMaxLoops(self.soundPlayerId, sampleId, variationSampleVariationId, variationMinLoops, variationMaxLoops)
            ambientSoundsSampleSetMinMaxPitch(self.soundPlayerId, sampleId, variationSampleVariationId, variationMinPitch, variationMaxPitch)
            ambientSoundsSampleSetMinMaxDelay(self.soundPlayerId, sampleId, variationSampleVariationId, variationMinDelay, variationMaxDelay)
            ambientSoundsSampleSetMinMaxLength(self.soundPlayerId, sampleId, variationSampleVariationId, variationMinLength, variationMaxLength)

        end

        table.insert(self.samples, {
            ["filename"] = path,
            ["audioGroupId"] = audioGroup,
            ["requiredFlags"] = requiredFlags,
            ["preventFlags"] = preventFlags,
            ["minTimeOfDay"] = minTimeOfDay,
            ["maxTimeOfDay"] = maxTimeOfDay,
            ["minDayOfYear"] = minDayOfYear,
            ["maxDayOfYear"] = maxDayOfYear
        })

    end

    xmlFile:delete()

    return returnValue

end

AmbientSoundSystem.loadFromConfigFile = Utils.overwrittenFunction(AmbientSoundSystem.loadFromConfigFile, RW_AmbientSoundSystem.loadFromConfigFile)