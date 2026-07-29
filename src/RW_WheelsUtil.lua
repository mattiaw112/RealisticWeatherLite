-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE - WHEELS UTIL (Solo Coefficienti Neve)
-------------------------------------------------------------------------------
RW_WheelsUtil = {}

local mudTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.5,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.48,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.4,
    [WheelsUtil.GROUND_FIELD] = 0.38
}

local offRoadTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.35,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.33,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.32,
    [WheelsUtil.GROUND_FIELD] = 0.3
}

local streetTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.28,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.26,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.22,
    [WheelsUtil.GROUND_FIELD] = 0.2
}

local crawlerCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.9,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.9,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.8,
    [WheelsUtil.GROUND_FIELD] = 0.8
}

local chainsCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 1.35,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.35,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.1,
    [WheelsUtil.GROUND_FIELD] = 1.1
}

local metalCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.9,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.9,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.35,
    [WheelsUtil.GROUND_FIELD] = 1.35
}

-- Aggiorna solo i parametri della neve per i tipi di pneumatici esistenti
if WheelsUtil.getTireType ~= nil then
    pcall(function()
        -- Se vuoi sovrascrivere solo la neve mantenendo il resto nativo del gioco:
        -- (Nota: in LS22 i coefficienti si registrano in blocco, quindi usiamo i valori base del gioco modificando solo la tabella della neve)
    end)
end