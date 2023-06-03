---------------------------------------------------------------------------------
-- Store general server info here
---------------------------------------------------------------------------------

---------------------------------------------------------------------------------

local UPDATE_RATE   = 100

---------------------------------------------------------------------------------

return {

    ---------------------------------------------------------------------------------

    SERVER_IP           = "0.0.0.0",
    API_VERSION         = "/api/v1",

    PORT                = 5000,
    PORT_WEB            = 5443,


    PIPE_ReadRouter     = 0,
    PIPE_WriteRouter    = 1,

    PIPE_ReadHttps      = 2,
    PIPE_WriteHttps     = 3,

    ---------------------------------------------------------------------------------
    -- Data server config
    
    -- Admin
    LOGIN_TIMEOUT         = 3600 * 8,  -- 8 hours default login amount

    -- TODO: Update rate shall be able to be modified per module 
    -- Game System
    GAME_CHECK_TIMEOUT    = 5,         -- Every five seconds check the games

    UPDATE_RATE           = UPDATE_RATE,
    UPDATE_TICKS          = UPDATE_RATE * 0.001,

    -- User Profiles (short lived user accounts)
    DEFAULT_TIMEOUT       = 120,       -- 120 seconds idle timeout for users 
    DEFAULT_LANG          = "en-US",

    CONNECT_TIMEOUT       = 3600,      -- 1 hour to remove profile for user

    ADMIN_DATA            = "data/admins/store.dli",
    API_GAME_TOKEN        = "j3mHKlgGZ4",

    -- Used for generating a bearer token (or similar to)
    --   CHANGE THIS IF YOU ARE GOING PUBLIC - its a test key
    --   To generate one - choose an aes256cbc generator or similar
    --   The GBG data is a Garbage block to pad all keys to over 16 bytes
    KEY = 0xF6BACB47A4949E554974D51DBD9D6C6A5BA38F0AAEF2F17B73F4843287F44E1C,
    GBG = "bfwduuhnKJLHFneuh443vldspdfleghtGlsbdlw",
}

---------------------------------------------------------------------------------
