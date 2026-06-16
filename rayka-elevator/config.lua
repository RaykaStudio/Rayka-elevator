Config = {}

-- Select your framework = 'esx' | 'qb' | 'standalone'
Config.Framework = 'esx' 

Config.Settings = {
    CommandName = 'elevator',
    AudioVolume = 0.3, -- Sound volume
}

-- Select your notification system 'ox' (ox_lib) | 'qb' (qbcore) | 'esx' (esx_notify)

Config.NotifyType = 'ox'

Config.Marker = {
    Type = 27,
    Size = {x = 1.0, y = 1.0, z = 1.0},
    Color = {r = 59, g = 130, b = 246, a = 100}
}