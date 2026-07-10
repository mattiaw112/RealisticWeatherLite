RealisticWeatherLiteRequestEvent = {}
RealisticWeatherLiteRequestEvent_mt = Class(RealisticWeatherLiteRequestEvent, Event)

InitEventClass(RealisticWeatherLiteRequestEvent, "RealisticWeatherLiteRequestEvent")

function RealisticWeatherLiteRequestEvent.emptyNew()
    return Event.new(RealisticWeatherLiteRequestEvent_mt)
end

function RealisticWeatherLiteRequestEvent.new()
    local self = RealisticWeatherLiteRequestEvent.emptyNew()
    return self
end

function RealisticWeatherLiteRequestEvent:readStream(streamId, connection)
    self:run(connection)
end

function RealisticWeatherLiteRequestEvent:writeStream(streamId, connection)
    -- Non serve scrivere nulla, è solo una richiesta di chiamata
end

function RealisticWeatherLiteRequestEvent:run(connection)
    -- Il Server riceve la richiesta dal Client e gli risponde mandandogli i dati attuali
    if not connection:getIsServer() and g_server ~= nil then
        local hail = _G.getModSettings("hailDamage_enabled")
        local notify = _G.getModSettings("notifications_enabled")
        
        connection:sendEvent(RealisticWeatherLiteEvent.new(hail, notify))
    end
end

-- Funzione helper che il client usa per inviare la richiesta
function RealisticWeatherLiteRequestEvent.sendEvent()
    if g_client ~= nil then
        g_client:getServerConnection():sendEvent(RealisticWeatherLiteRequestEvent.new())
    end
end