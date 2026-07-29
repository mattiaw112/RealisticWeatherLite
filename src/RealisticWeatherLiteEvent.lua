-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE EVENT (Sincronizzazione Multiplayer)
-------------------------------------------------------------------------------
RealisticWeatherLiteEvent = {}
RealisticWeatherLiteEvent_mt = Class(RealisticWeatherLiteEvent, Event)

InitEventClass(RealisticWeatherLiteEvent, "RealisticWeatherLiteEvent")

function RealisticWeatherLiteEvent.emptyNew()
    return Event.new(RealisticWeatherLiteEvent_mt)
end

function RealisticWeatherLiteEvent.new(hailDamage, notifications, fogEnabled)
    local self = RealisticWeatherLiteEvent.emptyNew()
    self.hailDamage = hailDamage
    self.notifications = notifications
    self.fogEnabled = fogEnabled
    return self
end

function RealisticWeatherLiteEvent:readStream(streamId, connection)
    self.hailDamage = streamReadBool(streamId)
    self.notifications = streamReadBool(streamId)
    self.fogEnabled = streamReadBool(streamId)
    
    -- Controllo Permessi Admin
    local canApply = false
    if connection ~= nil and connection.getIsServer ~= nil and connection:getIsServer() then
        canApply = true
    elseif g_currentMission ~= nil and g_currentMission.userManager ~= nil and connection ~= nil then
        canApply = g_currentMission.userManager:getIsConnectionMasterUser(connection)
    end

    if canApply then
        self:run(connection)
    end
end

function RealisticWeatherLiteEvent:writeStream(streamId, connection)
    streamWriteBool(streamId, self.hailDamage)
    streamWriteBool(streamId, self.notifications)
    streamWriteBool(streamId, self.fogEnabled)
end

function RealisticWeatherLiteEvent:run(connection)
    -- Applica le impostazioni sincronizzate puntando alla tabella corretta
    local targetSettings = RealisticWeatherLiteSettings or settings
    if targetSettings ~= nil and targetSettings.CONTROLS ~= nil then
        if targetSettings.CONTROLS.hailDamage then targetSettings.CONTROLS.hailDamage.value = self.hailDamage end
        if targetSettings.CONTROLS.weatherNotifications then targetSettings.CONTROLS.weatherNotifications.value = self.notifications end
        if targetSettings.CONTROLS.fogControl then targetSettings.CONTROLS.fogControl.value = self.fogEnabled end
        print("[WeatherNet] Impostazioni sincronizzate con successo (Grandine, Notifiche, Nebbia)!")
    end

    -- Se siamo il Server, rinviamo l'aggiornamento a tutti gli altri client
    if g_currentMission ~= nil and g_currentMission:getIsServer() and connection ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection)
    end
end

-- Funzione helper per l'invio rapido
function RealisticWeatherLiteEvent.sendEvent(hailDamage, notifications, fogEnabled)
    if g_currentMission:getIsServer() then
        if g_server ~= nil then
            g_server:broadcastEvent(RealisticWeatherLiteEvent.new(hailDamage, notifications, fogEnabled))
        end
    elseif g_client ~= nil and g_client.getServerConnection ~= nil then
        g_client:getServerConnection():sendEvent(RealisticWeatherLiteEvent.new(hailDamage, notifications, fogEnabled))
    end
end