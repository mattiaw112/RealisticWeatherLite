-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE - IMPOSTAZIONI E UI (COMPATIBILE FS25)
-------------------------------------------------------------------------------
RealisticWeatherLiteSettings = {}
local RealisticWeatherLiteSettings_mt = Class(RealisticWeatherLiteSettings)

RealisticWeatherLiteSettings.CONTROLS = {
    hailDamage = { id = "hailDamage_enabled", name = "hailDamage_enabled", textKey = "hailDamage_enabled", tooltipKey = "hailDamage_tooltip", value = true },
    weatherNotifications = { id = "notifications_enabled", name = "notifications_enabled", textKey = "notifications_enabled", tooltipKey = "notifications_tooltip", value = true },
    fogControl = { id = "fog_enabled", name = "fog_enabled", textKey = "fog_enabled", tooltipKey = "fog_tooltip", value = true }
}

function RealisticWeatherLiteSettings:getModSetting(settingName)
    for _, control in pairs(RealisticWeatherLiteSettings.CONTROLS) do
        if control.id == settingName or control.name == settingName then
            return control.value
        end
    end
    return true
end

-- Esposizione globale per far leggere i dati allo script principale
_G.getModSettings = function(settingName)
    return RealisticWeatherLiteSettings:getModSetting(settingName)
end

-------------------------------------------------------------------------------
-- GESTIONE UI IN-GAME MENU (INTEGRAZIONE NATIVA FS25)
-------------------------------------------------------------------------------
function RealisticWeatherLiteSettings:getText(key, fallback)
    if g_i18n ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    return fallback or key
end

function RealisticWeatherLiteSettings:findOptionTemplate(frame)
    if frame.economicDifficulty ~= nil and frame.economicDifficulty.clone ~= nil then
        return frame.economicDifficulty
    end

    if frame.multiDirt ~= nil and frame.multiDirt.clone ~= nil then
        return frame.multiDirt
    end

    return nil
end

function RealisticWeatherLiteSettings:getSettingsTemplates(frame)
    if frame.gameSettingsLayout ~= nil and frame.gameSettingsLayout.elements ~= nil then
        return frame.gameSettingsLayout.elements[5], frame.gameSettingsLayout.elements[7]
    end

    return nil, nil
end

function RealisticWeatherLiteSettings:addOptionToLayout(layout, option, rowTemplate, titleText, tooltipText)
    local tooltip = option.elements ~= nil and option.elements[1] or nil
    if tooltip ~= nil then
        tooltip.text = tooltipText
        tooltip.sourceText = tooltipText
    end

    local title = rowTemplate.elements[2]:clone()
    title.id = "rwTitle_" .. tostring(option.id)
    title:applyProfile("fs25_settingsMultiTextOptionTitle", true)
    title:setText(titleText)

    local container = rowTemplate:clone()
    container.id = "rwContainer_" .. tostring(option.id)
    container:applyProfile("fs25_multiTextOptionContainer", true)

    for key, _ in pairs(container.elements) do
        container.elements[key] = nil
    end

    container:addElement(title)
    container:addElement(option)
    layout:addElement(container)
end

function RealisticWeatherLiteSettings:registerSettingsUI(frame)
    if frame == nil or frame.gameSettingsLayout == nil or frame.rwSectionHeader ~= nil then
        return
    end

    local rowTemplate, headerTemplate = self:getSettingsTemplates(frame)
    local optionTemplate = self:findOptionTemplate(frame)

    if rowTemplate == nil or headerTemplate == nil or optionTemplate == nil then
        print("[RealisticWeatherLite] ERRORE: Template GUI FS25 non trovati nel menu impostazioni.")
        return
    end

    -- Inserimento Sezione Intestazione
    local header = headerTemplate:clone()
    header:applyProfile("fs25_settingsSectionHeader", true)
    header:setText(self:getText("rw_title", "Realistic Weather Lite"))
    header.focusChangeData = {}
    if FocusManager ~= nil then
        header.focusId = FocusManager:serveAutoFocusId()
    end
    frame.gameSettingsLayout:addElement(header)
    frame.rwSectionHeader = header

    local offText = self:getText("ui_off", "NO")
    local onText = self:getText("ui_on", "SI")

    -- Creazione selettori ON/OFF stile FS25 per ciascuna opzione
    for _, control in pairs(RealisticWeatherLiteSettings.CONTROLS) do
        local option = optionTemplate:clone()
        option.id = "rwOpt_" .. control.id
        option.target = option
        option.texts = { offText, onText }
        option.buttonLRChange = true

        local titleText = self:getText(control.textKey, control.name)
        local tooltipText = self:getText(control.tooltipKey, titleText)

        local currentControl = control
        option.onClickCallback = function(_, state)
            local ok, err = pcall(function()
                currentControl.value = (state == 2)
                print(string.format("[RealisticWeatherLite][DEBUG] Cambio opzione '%s' -> %s", tostring(currentControl.id), tostring(currentControl.value)))

                if g_currentMission ~= nil and RealisticWeatherLiteEvent ~= nil then
                    local hail = RealisticWeatherLiteSettings:getModSetting("hailDamage_enabled")
                    local notify = RealisticWeatherLiteSettings:getModSetting("notifications_enabled")
                    local fog = RealisticWeatherLiteSettings:getModSetting("fog_enabled")

                    RealisticWeatherLiteEvent.sendEvent(hail, notify, fog)
                end

                if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
                    RealisticWeatherLiteSettings:saveToDisk(g_currentMission.missionInfo)
                end
            end)
            if not ok then
                print(string.format("[RealisticWeatherLite][ERRORE] Callback opzione fallita: %s", tostring(err)))
            end
        end

        self:addOptionToLayout(frame.gameSettingsLayout, option, rowTemplate, titleText, tooltipText)
        option:setState(control.value and 2 or 1)

        frame[option.id] = option
    end

    frame.gameSettingsLayout:invalidateLayout()
    RealisticWeatherLiteSettings.isUIInitialized = true
end

if InGameMenuSettingsFrame ~= nil and not RealisticWeatherLiteSettings.settingsGuiInstalled then
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(
        InGameMenuSettingsFrame.onFrameOpen,
        function(frame)
            RealisticWeatherLiteSettings:registerSettingsUI(frame)
        end
    )
    RealisticWeatherLiteSettings.settingsGuiInstalled = true
end

-------------------------------------------------------------------------------
-- PERSISTENZA IMPOSTAZIONI (SALVATAGGIO XML DEDICATO NEL SAVEGAME)
-------------------------------------------------------------------------------
RealisticWeatherLiteSettings.SETTINGS_FILENAME = "realisticWeatherLiteSettings.xml"

RealisticWeatherLiteSettings.xmlSchema = XMLSchema.new("RealisticWeatherLiteSettings")
RealisticWeatherLiteSettings.xmlSchema:register(XMLValueType.BOOL, "realisticWeatherLite.hailDamage#value", "Hail damage enabled", true)
RealisticWeatherLiteSettings.xmlSchema:register(XMLValueType.BOOL, "realisticWeatherLite.notifications#value", "Weather notifications enabled", true)
RealisticWeatherLiteSettings.xmlSchema:register(XMLValueType.BOOL, "realisticWeatherLite.fog#value", "Fog enabled", true)

local function rw_getSettingsFilePath(missionInfo)
    if missionInfo == nil or missionInfo.savegameDirectory == nil then
        return nil
    end
    return missionInfo.savegameDirectory .. "/" .. RealisticWeatherLiteSettings.SETTINGS_FILENAME
end

function RealisticWeatherLiteSettings:saveToDisk(missionInfo)
    local filePath = rw_getSettingsFilePath(missionInfo)
    if filePath == nil then
        print("[RealisticWeatherLite] Salvataggio impostazioni saltato: savegameDirectory non disponibile")
        return
    end

    local xmlFile = XMLFile.create("rwSettingsXML", filePath, "realisticWeatherLite", RealisticWeatherLiteSettings.xmlSchema)
    if xmlFile == nil then
        print("[RealisticWeatherLite] ERRORE: impossibile creare " .. filePath)
        return
    end

    xmlFile:setValue("realisticWeatherLite.hailDamage#value", RealisticWeatherLiteSettings.CONTROLS.hailDamage.value)
    xmlFile:setValue("realisticWeatherLite.notifications#value", RealisticWeatherLiteSettings.CONTROLS.weatherNotifications.value)
    xmlFile:setValue("realisticWeatherLite.fog#value", RealisticWeatherLiteSettings.CONTROLS.fogControl.value)
    xmlFile:save()
    xmlFile:delete()

    print(string.format("[RealisticWeatherLite] Impostazioni salvate (hail=%s, notify=%s, fog=%s) -> %s",
        tostring(RealisticWeatherLiteSettings.CONTROLS.hailDamage.value),
        tostring(RealisticWeatherLiteSettings.CONTROLS.weatherNotifications.value),
        tostring(RealisticWeatherLiteSettings.CONTROLS.fogControl.value),
        filePath))
end

function RealisticWeatherLiteSettings:loadFromDisk(missionInfo)
    local filePath = rw_getSettingsFilePath(missionInfo)
    if filePath == nil then
        print("[RealisticWeatherLite] Caricamento impostazioni saltato: savegameDirectory non disponibile")
        return
    end

    if not fileExists(filePath) then
        print("[RealisticWeatherLite] Nessun file impostazioni trovato (" .. filePath .. "), uso i default")
        return
    end

    local xmlFile = XMLFile.load("rwSettingsXML", filePath, RealisticWeatherLiteSettings.xmlSchema)
    if xmlFile == nil then
        print("[RealisticWeatherLite] ERRORE: impossibile leggere " .. filePath)
        return
    end

    RealisticWeatherLiteSettings.CONTROLS.hailDamage.value = xmlFile:getValue("realisticWeatherLite.hailDamage#value", true)
    RealisticWeatherLiteSettings.CONTROLS.weatherNotifications.value = xmlFile:getValue("realisticWeatherLite.notifications#value", true)
    RealisticWeatherLiteSettings.CONTROLS.fogControl.value = xmlFile:getValue("realisticWeatherLite.fog#value", true)
    xmlFile:delete()

    print(string.format("[RealisticWeatherLite] Impostazioni caricate (hail=%s, notify=%s, fog=%s) <- %s",
        tostring(RealisticWeatherLiteSettings.CONTROLS.hailDamage.value),
        tostring(RealisticWeatherLiteSettings.CONTROLS.weatherNotifications.value),
        tostring(RealisticWeatherLiteSettings.CONTROLS.fogControl.value),
        filePath))

    RealisticWeatherLiteSettings.isUIInitialized = false
end

if FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil then
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function(missionInfo, ...)
        RealisticWeatherLiteSettings:saveToDisk(missionInfo)
    end)
end

-------------------------------------------------------------------------------
-- LOADER AL CARICAMENTO DELLA MAPPA
-------------------------------------------------------------------------------
RealisticWeatherLiteSettingsLoader = {}
local RW_SettingsLoader = RealisticWeatherLiteSettingsLoader

function RW_SettingsLoader:loadMap(name)
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    RealisticWeatherLiteSettings:loadFromDisk(missionInfo)
end

addModEventListener(RW_SettingsLoader)

-------------------------------------------------------------------------------
-- EVENTO MULTIPLAYER JOIN
-------------------------------------------------------------------------------
if FSBaseMission ~= nil and FSBaseMission.onClientJoined ~= nil then
    FSBaseMission.onClientJoined = Utils.appendedFunction(FSBaseMission.onClientJoined, function(self, connection)
        if g_currentMission ~= nil and g_currentMission:getIsServer() and connection ~= nil then
            local hail = RealisticWeatherLiteSettings:getModSetting("hailDamage_enabled")
            local notify = RealisticWeatherLiteSettings:getModSetting("notifications_enabled")
            local fog = RealisticWeatherLiteSettings:getModSetting("fog_enabled")
            
            if RealisticWeatherLiteEvent ~= nil then
                connection:sendEvent(RealisticWeatherLiteEvent.new(hail, notify, fog))
            end
        end
    end)
end