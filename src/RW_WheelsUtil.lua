-------------------------------------------------------------------------------
-- REALISTIC WEATHER LITE - WHEELS UTIL (Solo Coefficienti Neve)
-------------------------------------------------------------------------------
RW_WheelsUtil = {}

local mudTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.42,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.40,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.32,
    [WheelsUtil.GROUND_FIELD] = 0.30
}

local offRoadTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.30,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.28,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.25,
    [WheelsUtil.GROUND_FIELD] = 0.22
}

local streetTireCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.22,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.20,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.16,
    [WheelsUtil.GROUND_FIELD] = 0.14
}

local crawlerCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.75,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.75,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.65,
    [WheelsUtil.GROUND_FIELD] = 0.62
}

local chainsCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 1.05,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 1.05,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 0.85,
    [WheelsUtil.GROUND_FIELD] = 0.85
}

local metalCoeffsSnow = {
    [WheelsUtil.GROUND_ROAD] = 0.75,
    [WheelsUtil.GROUND_HARD_TERRAIN] = 0.75,
    [WheelsUtil.GROUND_SOFT_TERRAIN] = 1.05,
    [WheelsUtil.GROUND_FIELD] = 1.05
}