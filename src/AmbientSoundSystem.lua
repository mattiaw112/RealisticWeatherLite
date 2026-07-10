RW_AmbientSoundSystem = {}
local modDirectory = g_currentModDirectory

function RW_AmbientSoundSystem:updateMask()
    if g_currentMission == nil or g_currentMission.environment == nil then return end
    
    local env = g_currentMission.environment
    local weather = env.weather
    
    -- Recupero sicuro delle scale meteo in formato FS25
    local rainfall = 0
    if env.getRainFallScale ~= nil then
        rainfall = env:getRainFallScale()
    elseif weather ~= nil and weather.getRainFallScale ~= nil then
        rainfall = weather:getRainFallScale()
    end

    local hailfall = 0
    if env.getHailFallScale ~= nil then
        hailfall = env:getHailFallScale()
    elseif weather ~= nil and weather.getHailFallScale ~= nil then
        hailfall = weather:getHailFallScale()
    end

    local isSnowing = false
    if env.getIsSnowing ~= nil then
        isSnowing = env:getIsSnowing()
    elseif weather ~= nil then
        isSnowing = weather.isSnowing or false
    end

    -- Controllo opzionale: se la mod è disattivata nel menu, azzeriamo i flag custom
    local isHailEnabled = _G.getModSettings("hailDamage_enabled")
    if not isHailEnabled then
        hailfall = 0
    end

    -- Impostazione corretta dei modificatori nativi del gioco
    if self.conditionFlags ~= nil then
        self.conditionFlags:setModifierValue("blizzard", isSnowing)
        self.conditionFlags:setModifierValue("hail", hailfall > 0)
        self.conditionFlags:setModifierValue("rain", rainfall >= 0.33 and rainfall < 0.67)
        self.conditionFlags:setModifierValue("heavyRain", rainfall >= 0.67)
        self.conditionFlags:setModifierValue("lightRain", rainfall < 0.33 and rainfall > 0)
        self.conditionFlags:setModifierValue("anyRain", rainfall > 0 or hailfall > 0)
    end
end

-- Questa riga aggancia la nostra funzione a quella del gioco base
AmbientSoundSystem.updateMask = Utils.appendedFunction(AmbientSoundSystem.updateMask, RW_AmbientSoundSystem.updateMask)

function RW_AmbientSoundSystem:loadFromConfigFile(returnValue)
    -- Se il gioco ha già fallito di suo a caricare i suoni base, ci fermiamo
    if not returnValue then return false end

    -- Registriamo i modificatori meteo sulla struttura esistente del gioco
    if self.conditionFlags ~= nil then
        self.conditionFlags:registerModifier("blizzard", nil)
        self.conditionFlags:registerModifier("hail", nil)
        self.conditionFlags:registerModifier("heavyRain", nil)
        self.conditionFlags:registerModifier("lightRain", nil)
        self.conditionFlags:registerModifier("anyRain", nil)
    end

    local xmlPath = Utils.getFilename("xml/sounds.xml", modDirectory)
    
    -- Usiamo il caricamento XML generico del gioco senza passargli uno schema rigido che può essere nil
    local xmlFile = XMLFile.loadIfExists("rwAmbientSounds", xmlPath)
    if xmlFile == nil then return returnValue end

    for _, key in xmlFile:iterator("ambientSounds.ambient.sample") do
        local filename = xmlFile:getValue(key .. ".file#filename")
        
        if filename ~= nil and filename ~= "" then
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
            
            local audioGroup = AudioGroup.getAudioGroupIndexByName(audioGroupName) or AudioGroup.ENVIRONMENT

            local path = Utils.getFilename(filename, modDirectory)
            local requiredFlags, preventFlags = {}, {}
            if self.conditionFlags ~= nil and self.conditionFlags.loadFlagsFromXMLFile ~= nil then
                requiredFlags, preventFlags = self.conditionFlags:loadFlagsFromXMLFile(xmlFile, key)
            end
            
            -- Chiamate protette inserendo valori di fallback siuri (niente nil alle funzioni C++)
            local sampleId = ambientSoundsAddSample(
                self.soundPlayerId, 
                audioGroup, 
                minRetriggerDelaySeconds or 0, 
                maxRetriggerDelaySeconds or 0, 
                requiredFlags, 
                preventFlags, 
                minTimeOfDay or 0, 
                maxTimeOfDay or 1440, 
                minDayOfYear or 0, 
                maxDayOfYear or 365, 
                positionTag or "", 
                radius or 0, 
                innerRadius or 0
            )
            
            if sampleId ~= nil then
                local sampleVariationId = ambientSoundsAddSampleVariation(self.soundPlayerId, sampleId, path, probability or 1)
                
                if sampleVariationId ~= nil then
                    ambientSoundsSampleSetIndoorVolumeFactor(self.soundPlayerId, sampleId, sampleVariationId, indoorVolume or 0.8)
                    ambientSoundsSampleSetFadeInOutTime(self.soundPlayerId, sampleId, sampleVariationId, fadeInTime or 0, fadeOutTime or 0)
                    ambientSoundsSampleSetMinMaxVolume(self.soundPlayerId, sampleId, sampleVariationId, minVolume or 1, maxVolume or 1)
                    ambientSoundsSampleSetMinMaxLoops(self.soundPlayerId, sampleId, sampleVariationId, minLoops or 1, maxLoops or 1)
                    ambientSoundsSampleSetMinMaxPitch(self.soundPlayerId, sampleId, sampleVariationId, minPitch or 1, maxPitch or 1)
                    ambientSoundsSampleSetMinMaxDelay(self.soundPlayerId, sampleId, sampleVariationId, minDelay or 0, maxDelay or 0)
                    ambientSoundsSampleSetMinMaxLength(self.soundPlayerId, sampleId, sampleVariationId, minLength or 0, maxLength or 0)
                end
            end

            if self.samples ~= nil then
                table.insert(self.samples, {
                    ["filename"] = path,
                    ["audioGroupId"] = audioGroup,
                    ["requiredFlags"] = requiredFlags,
                    ["preventFlags"] = preventFlags,
                    ["minTimeOfDay"] = minTimeOfDay or 0,
                    ["maxTimeOfDay"] = maxTimeOfDay or 1440,
                    ["minDayOfYear"] = minDayOfYear or 0,
                    ["maxDayOfYear"] = maxDayOfYear or 365
                })
            end
        end
    end

    xmlFile:delete()
    return returnValue
end

-- Aggancio sicuro al caricamento configurazione del gioco base
AmbientSoundSystem.loadFromConfigFile = Utils.appendedFunction(AmbientSoundSystem.loadFromConfigFile, RW_AmbientSoundSystem.loadFromConfigFile)
```[cite: 5]

---

### 🔍 Cosa cambia ora:
1. **`hail` e `blizzard` finalmente attivi:** Sostituendo i vecchi controlli con `hailfall > 0` e `isSnowing`, l'interfaccia nativa del gioco sa esattamente quando attivare le tracce nel tuo file `sounds.xml`[cite: 4, 5].
2. **Collegato alle impostazioni di gioco:** Se l'utente toglie la spunta a "Abilita Danni Grandine", lo script imposta automaticamente a zero la scala della grandine per i suoni ambientali, silenziandoli[cite: 4, 5].