-------------------------------------------------------------------------------
-- HUD PERSONALIZZATO: Solo Neve (Semplificato)
-------------------------------------------------------------------------------
RW_GameInfoDisplay = {}
RW_GameInfoDisplay.TICKS_PER_UPDATE = 200

function RW_GameInfoDisplay:draw()
    if self.temperatureBg == nil then
        self.updateTicks = RW_GameInfoDisplay.TICKS_PER_UPDATE
        self.snowHeightMin = 0
        self.snowHeightMax = 0
        
        -- Controllo sicuro all'inizializzazione
        local weatherInit = g_currentMission and g_currentMission.environment and g_currentMission.environment.weather
        self.setSnow = (weatherInit and weatherInit.snowHeight) or 0

        self.temperatureBgLeft = g_overlayManager:createOverlay("gui.gameInfo_left", 0, 0, 0, 0)
        self.temperatureBg = g_overlayManager:createOverlay("gui.gameInfo_middle", 0, 0, 0, 0)
        local colour = HUD.COLOR.BACKGROUND
        self.temperatureBgLeft:setColor(colour[1], colour[2], colour[3], colour[4])
        self.temperatureBg:setColor(colour[1], colour[2], colour[3], colour[4])
        local width, height = self:scalePixelValuesToScreenVector(10, 65)
        self.temperatureBgLeft:setDimension(width, height)
        self.temperatureBg:setDimension(width * 8, height)
        self.temperatureTextSize = self:scalePixelToScreenHeight(17)
        self.snowTextOffsetX, self.snowTextOffsetY = self:scalePixelValuesToScreenVector(6, 27)
        
        -- Spostato ulteriormente a sinistra (ridotto a 3)
        self.snowOneTextOffsetX, _ = self:scalePixelValuesToScreenVector(3, 27)

        -- Configurazione box neve
        self.snowAmountBg = g_overlayManager:createOverlay("gui.gameInfo_middle", 0, 0, 0, 0)
        self.snowAmountBg:setColor(colour[1], colour[2], colour[3], colour[4])
        self.snowAmountBgWidth, self.snowAmountBgHeight = width * 20, height
        self.snowAmountBg:setDimension(self.snowAmountBgWidth, self.snowAmountBgHeight)
        self.snowOneText = "%d cm"
    end

    local _, y = self:getPosition()
    local elementLoaded = true

    -- Gestione altezza neve da mostrare nell'HUD in modo sicuro
    local weather = g_currentMission and g_currentMission.environment and g_currentMission.environment.weather
    local snowHeightVal = RealisticWeatherLite.snowHeight or (weather and weather.snowHeight) or 0
    
    if snowHeightVal > 0 then
        -- Ancorato direttamente alla base di gioco senza controlli esterni superflui
        local refX = self.infoBgLeft.x
        
        self.snowAmountBg:setPosition(refX - self.snowAmountBg.width, y - self.snowAmountBg.height)
        self.snowAmountBg:render()
        self.temperatureBgLeft:setPosition(self.snowAmountBg.x - self.temperatureBgLeft.width, y - self.snowAmountBg.height)

        local snowCm = math.round(snowHeightVal * 100)
        local snowTextStr = string.format(self.snowOneText, snowCm)

        setTextColor(1, 1, 1, 1)
        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_LEFT)
        renderText(self.snowAmountBg.x + self.snowOneTextOffsetX, self.snowAmountBg.y + self.snowTextOffsetY, self.temperatureTextSize, snowTextStr)
    else
        local refX = self.infoBgLeft.x
        self.temperatureBgLeft:setPosition(refX - self.temperatureBgLeft.width, y - self.temperatureBgLeft.height)
    end

    setTextBold(false)
    if elementLoaded then self.temperatureBgLeft:render() end
end

if GameInfoDisplay ~= nil and GameInfoDisplay.draw ~= nil then
    GameInfoDisplay.draw = Utils.appendedFunction(GameInfoDisplay.draw, RW_GameInfoDisplay.draw)
end