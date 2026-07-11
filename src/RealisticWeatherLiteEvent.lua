RealisticWeatherLiteEvent = {}
RealisticWeatherLiteEvent_mt = Class(RealisticWeatherLiteEvent, Event)

InitEventClass(RealisticWeatherLiteEvent, "RealisticWeatherLiteEvent")

function RealisticWeatherLiteEvent.emptyNew()
    return Event.new(RealisticWeatherLiteEvent_mt)
end

function RealisticWeatherLiteEvent.new(hailDamage, notifications)
    local self = RealisticWeatherLiteEvent.emptyNew()
    self.hailDamage = hailDamage
    self.notifications = notifications
    return self
end

function RealisticWeatherLiteEvent:readStream(streamId, connection)
    self.hailDamage = streamReadBool(streamId)
    self.notifications = streamReadBool(streamId)
    
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
end

function RealisticWeatherLiteEvent:run(connection)
    -- Applica le impostazioni
    if settings ~= nil and settings.CONTROLS ~= nil then
        settings.CONTROLS.hailDamage.value = self.hailDamage
        settings.CONTROLS.weatherNotifications.value = self.notifications
        print("[WeatherNet] Impostazioni sincronizzate con successo!")
    end

    -- Se siamo il Server, rinviamo l'aggiornamento a tutti gli altri client
    if g_currentMission ~= nil and g_currentMission:getIsServer() and connection ~= nil and not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection)
    end
end

-- Funzione di comodo per inviare l'evento da menu o da codice
function RealisticWeatherLiteEvent.sendEvent(hailDamage, notifications)
    if g_currentMission:getIsServer() then
        if g_server ~= nil then
            g_server:broadcastEvent(RealisticWeatherLiteEvent.new(hailDamage, notifications))
        end
    elseif g_client ~= nil and g_client.getServerConnection ~= nil then
        g_client:getServerConnection():sendEvent(RealisticWeatherLiteEvent.new(hailDamage, notifications))
    end
end