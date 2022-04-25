local tinsert 	= table.insert
local tremove 	= table.remove
local tcount 	= table.getn

local sqlapi    = require "lua.sqlapi"
local utils     = require "lua.utils"
local json      = require "lua.json"

-- ---------------------------------------------------------------------------

local debugStore 				= nil
local MAXIMUM_REQUEST_DELAY     = 2     -- For higher paced games, this is much lower

-- ---------------------------------------------------------------------------
-- Timeouts
local TIMEOUT_SCENARIO          = 20.0
local TIMEOUT_SELECT            = 40.0
local TIMEOUT_DISCUSS           = 180.0 -- 3 minutes discussion (may remove)
local TIMEOUT_VERDICT           = 40.0
local TIMEOUT_NEXT              = 20.0  -- How long to display results and stats

-- ---------------------------------------------------------------------------

local USER_EVENT = {

	NONE                = 0, 
	POLL                = 1,    -- This just keeps the connect alive
    ENDSTATE            = 2,    -- Use this to move to next state

	SENDING_TRAITS      = 10,   -- User sends traits selection (up to 4)
	SENDING_PERSONS     = 11,   -- User sends persons selection (up to 4)

	REQUEST_GAME        = 20,   -- Client needs game state
	REQUEST_ROUND       = 21,   -- Client needs round state
    REQUEST_SCENARIOS   = 22,   -- Fetch the list of scenarios
    REQUEST_MYCARDS     = 23,   -- Get the cards for this round
    REQUEST_ROUNDCARDS  = 24,   -- Get the cards everyone has selected for discussion

    REQUEST_START       = 30,   -- Owner wants to start
    REQUEST_READY       = 31,   -- Player changing ready state in lobby

    REQUEST_WAITING     = 40,   -- Player is waiting after a timeout or similar

	SENDING_SCENARIO    = 50,   -- Judge chooses scenario

	SENDING_CHOICE      = 60,   -- Players choose character for scenario

	SENDING_VERDICT     = 70,   -- Judge sends verdict
}

-- Reverse lookup to validate events
local USER_EVENT_RL = {}
for k,v in pairs(USER_EVENT) do USER_EVENT_RL[v] = k end

-- ---------------------------------------------------------------------------
-- User submission data must be in this format - will be checked
local userdata = {

    state       = nil,      -- User round state
    uid         = nil,      -- user id 
    name        = "",       -- game name 
    round       = 0,        -- which round we are in (0 is lobby)
    timestamp   = 0,        -- client side timestamp - must be within X secs

    event       = USER_EVENT.NONE,       -- What this update is for ( see enum )
    json        = "",       -- json data for the update event
}

-- ---------------------------------------------------------------------------
-- NOTE: All round data is in mem - in a hash table. Once a game is complete,
--       all round info is collated and tables deleted. Do not rely on round data

local GAME_STATE = {

	NONE 		    = 0,
    EXIT 			= 2,

	GAME_JOINING	= 90,   -- Joining a game (host lobby)
	GAME_STARTING	= 91,   -- The host has started the game
	GAME_SCENARIO	= 93,   -- The Judge chooses the scenario! (timed)
	GAME_PLAY		= 94,	-- Players choosing character (timed)
	GAME_DISCUSS	= 96,   -- Entered choosing mode (not timed)
	GAME_VERDICT	= 97,   -- Entered Discussion/Judging mode (timed)
	GAME_NEXTROUND  = 98,   -- Next round is being kicked off - return to readying. 
	GAME_FINISH		= 99,   
}

-- ---------------------------------------------------------------------------

local pools         = {}        -- Game round pools to select from
local rounds        = {}        -- list of all running rounds

local selections    = {}

local dbscenarios   = nil        -- Available scenarios to choose from
local dbtraits      = nil 
local dbpersons     = nil

-- ---------------------------------------------------------------------------

local function log( str )
    print("[Error in checkround] "..str)
end

-- ---------------------------------------------------------------------------

local function newround(game, roundno, state, oldround)

    roundno = roundno or 0
    state = state or GAME_STATE.JOINING

	local round = {

        round           = tonumber(roundno),    -- Always start round at "joining"
        gamename        = game.gamename,

		playercards	    = 4,
		playercount     = 2,
		player_select 	= 1,
        verdict         = 1,    -- Judges chosen solution
		
		judge 		    = 1,    -- index of the user (from people list) that is current judge
		cards		    = "",   -- List of cards (as encoded json)

		scenario	    = 1,    -- Index into dbscenarios (should always be more than 1)
        theme           = "",
		state 		    = state,

        playerhands     = {}
	}

    -- Game retains the current round id
    game.round           = tonumber(round.round)

    -- All traits and persons are pooled here. 
    --   When a trait and person is selected it is removed from the pool
    --   This ensures sets will all match properly
    if(pools[game.name] == nil) then 
        pools[game.name] = {

            -- These are indexed by uid and contain user traits and persons. 
            useradded   = {},

            -- This is the final pool once the round is ready (copid in from useradded and db)
            traits      = nil,
            persons     = nil,

            -- Each players pool of cards.
            mycards     = {},   
        }    
    end
    
    round.roundid = game.name..string.format("%02d", round.round)
    if(oldround) then 
        round.cards = oldround.cards 
        round.judge = oldround.judge
    end 

    rounds[round.roundid] = round 

    selections[round.roundid] = {}
    return round
end

-- ---------------------------------------------------------------------------

local function resetround(self)
	self.round 	= nil
end

-- ---------------------------------------------------------------------------

local function getrandom(list)

	local listsize = utils.tcount(list) 
	local select = math.random(listsize)
	return select
end

-- ---------------------------------------------------------------------------
-- Generate a card table, this will be used in the rounds
local function makecard(self)
	
	local card = {
		person 	= getrandom( self.persons ),
		trait 	= getrandom( self.traits ),

		playeridx 		= nil,		-- assigned afterwards
		played 			= nil,		-- when used this is set 
		won 			= nil,		-- the just sets this if it wins a round
	}
	return card
end

-- ---------------------------------------------------------------------------

local function setUserWaiting( game, uid )

    for k,v in pairs(game.people) do 
        if( uid == v.uid ) then 
            v.state = USER_EVENT.REQUEST_WAITING
            break 
        end 
    end
end

-- ---------------------------------------------------------------------------

local function getUser( game, uid )

    if(game.people == nil) then return nil end
    for k,v in pairs(game.people) do 
        if( uid == v.uid ) then 
            return v
        end 
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Check the incoming data matches current state
--  TODO: A bunch of logging needed here
local function checkround( game, round, data )

    -- if(game.state ~= data.state) then return nil end 
    if(data.uid == nil) then log("data.uid == nil"); return nil end 
    if(round.gamename ~= data.name) then log("round.gamename ~= data.name  ("..tostring(round.gamename).."  "..tostring(data.name)..")"); return nil end 
    -- if(round.round ~= data.round) then log("round.round ~= data.round ("..tostring(round.round).."  "..tostring(data.round)..")") end -- non fatal
    if(os.time() - data.timestamp > MAXIMUM_REQUEST_DELAY) then log("Timestamp longer than MAXIMUM_REQUEST_DELAY"); return nil end 
    if(USER_EVENT_RL[data.event] == nil) then log("Data event not found: "..tostring(data.event)); return nil end

    return true
end 

-- ---------------------------------------------------------------------------
-- hosting game then the round info is controlled by this client
local function setup( module, game )

    pools[game.name]         = nil        -- Game round pools to select from
    
	-- Save previous players (when updating) 
	newround(game)
    
	-- local left = self.width * 0.5 - 170 * self.scale	
	-- self.playercard_move = { pos = left }	
    sqlapi.setConn(module.sql.conn)
    if(dbscenarios == nil) then dbscenarios = sqlapi.getTable( "scenarios" ) end 
    if(dbpersons == nil) then dbpersons = sqlapi.getTable( "persons" ) end 
    if(dbtraits == nil) then dbtraits = sqlapi.getTable( "traits" ) end 
    sqlapi.setConn(module.sql.prevconn)
end

-- ---------------------------------------------------------------------------
local OK_TABLE = { "OK" }

local function processjoining( game, round, data )

    -- Traits have been submitted
    local event = data.event
    if(event == USER_EVENT.SENDING_TRAITS) then 

        local pool = pools[game.name]
        if(pool.useradded[data.uid] == nil) then pool.useradded[data.uid] = {} end
        pool.useradded[data.uid].traits = data.json
        return OK_TABLE
    
    elseif(event == USER_EVENT.SENDING_PERSONS) then 

        local pool = pools[game.name]
        if(pool.useradded[data.uid] == nil) then pool.useradded[data.uid] = {} end
        pool.useradded[data.uid].persons = data.json
        return OK_TABLE

    elseif(event == USER_EVENT.REQUEST_READY) then 

        if(game.round == nil) then return nil end 
        local person = nil
        for k,v in pairs(game.people) do 
            if(data.uid == v.uid) then person = v;break end
        end
        if(person == nil) then return nil end 
        person.state = data.json.state
        return OK_TABLE

    elseif(event == USER_EVENT.REQUEST_START) then 

        if(game.round == nil) then return nil end 
        if(data.uid ~= game.owner) then return nil end  -- Only owner can start!

        -- Theres are set by owner when we change state
        game.phasetime = TIMEOUT_SCENARIO
        -- Random assign judge in beginning - then iterate
        round.judge = math.random(1, utils.tcount(game.people))
        -- This is the state the game will now use. Only round state should change now
        game.state = GAME_STATE.GAME_STARTING
        return game

    elseif(event == USER_EVENT.REQUEST_WAITING) then 

        setUserWaiting(game, data.uid)
        return OK_TABLE
    end 
    return nil
end

-- ---------------------------------------------------------------------------
-- Populate an array from a dbsource. Making sure duplicates dont occur
local function populateArray( array, count, dbsource )

    local dbct = utils.tcount(dbsource) 
    local pool = {}
    for i=1, dbct do tinsert(pool, i) end 

    for left = 1, count do 
        local rselect = math.random(1, #pool)
        tinsert(array, dbsource[pool[rselect]])
        tremove(pool, rselect)
    end

    -- Create a "remaining" db source
    local newdb = {}
    for i,v in ipairs(pool) do tinsert(newdb, dbsource[v]) end
    return newdb
end 

-- ---------------------------------------------------------------------------

local function getmycards( game, round, data )

    local pcount = utils.tcount(game.people)
    if(pools[game.name].traits == nil and pools[game.name].persons == nil) then
        -- Collate created persons and traits, into the pool. 
        local persons   = {}
        local traits    = {}
        for idx, person in pairs(game.people) do 
            local uadded = pools[game.name].useradded[person.uid]
            if(uadded) then 
                if( uadded.persons ) then 
                    for i, person in pairs( uadded.persons ) do 
                        tinsert(persons, person)
                    end
                end 
                if( uadded.traits ) then 
                    for i, trait in pairs( uadded.traits ) do 
                        tinsert(traits, trait)
                    end
                end 
            end 
        end 

        -- Check how many we need. usually #people * 4
        local numpersons = pcount * round.playercards
        local numtraits = pcount * round.playercards

        local missingp = numpersons - #persons 
        local missingt = numtraits - #traits

        -- fill traits and persons with db traits and db persons
        populateArray( persons, missingp, dbpersons )
        populateArray( traits, missingt, dbtraits )

        pools[game.name].traits = traits 
        pools[game.name].persons = persons
    end 

    -- Now we have a pool of traits and people, start selecting from them
    round.cards = { }
    local temptraits = {}
    local temppersons = {}
    pools[game.name].traits = populateArray( temptraits, round.playercards, pools[game.name].traits )
    pools[game.name].persons = populateArray( temppersons, round.playercards, pools[game.name].persons )

    for i=1, round.playercards do 
        tinsert(round.cards, { trait = temptraits[i], person = temppersons[i] })
    end 

    return round.cards
end 

-- ---------------------------------------------------------------------------

local function processstarting( game, round, data )

    local pcount = utils.tcount(game.people)
    if(data.event == USER_EVENT.REQUEST_WAITING) then 

        setUserWaiting(game, data.uid)

    elseif(data.event == USER_EVENT.REQUEST_SCENARIOS) then 
        -- Everyone gets scenarios, since they might become judges
        return dbscenarios

    elseif(data.event == USER_EVENT.REQUEST_MYCARDS) then 
        -- Each user gets a list of cards to choose from 
        local mycards = getmycards(game, round, data)
        pools[game.name].mycards[data.uid] = mycards
        return mycards
    end 

    -- Check everyone is waiting - this means all players have startup done
    local waiting = 0
    for k,v in pairs(game.people) do 
        if( v.state == USER_EVENT.REQUEST_WAITING ) then waiting = waiting + 1 end 
    end 

    -- Everyone waiting
    if(waiting == pcount) then 
        game.state = GAME_STATE.GAME_SCENARIO
        game.phasetime = TIMEOUT_SCENARIO
        for k,v in pairs(game.people) do v.state = USER_EVENT.NONE end     
    end 
    return OK_TABLE
end 

-- ---------------------------------------------------------------------------

local function processscenario( game, round, data )

    if(data.event == USER_EVENT.REQUEST_WAITING) then 

        setUserWaiting(game, data.uid)
    -- Scenario selecting - this is the judge choosing a scenario
    elseif( data.event == USER_EVENT.SENDING_SCENARIO ) then 

        round.scenario = data.json.viewscenario
        round.theme = dbscenarios[round.scenario].theme
        return OK_TABLE
    end 

    -- Check if the judge goes into waiting - means selection is complete
    local judge = game.people[round.judge]
    if( judge.state == USER_EVENT.REQUEST_WAITING ) then 

        game.state = GAME_STATE.GAME_PLAY
        game.phasetime = TIMEOUT_SELECT
        for k,v in pairs(game.people) do v.state = USER_EVENT.NONE end     
        return OK_TABLE
    end 
    return nil
end

-- ---------------------------------------------------------------------------

local function addtoselection( id, data )

    -- first check if it exists - if so, overwrite data else, add a new one
    for idx,v in ipairs(selections[id]) do 
        if(v.uid == data.uid) then 
            v.trait = data.trait
            v.person = data.person
            return 
        end 
    end 
    tinsert(selections[id], data)
end

-- ---------------------------------------------------------------------------

local function processplay( game, round, data )

    local pcount = utils.tcount(game.people)
    if(data.event == USER_EVENT.REQUEST_WAITING) then 

        setUserWaiting(game, data.uid)

    elseif(data.event == USER_EVENT.SENDING_CHOICE) then 

        local user = getUser(game, data.uid)
        if(user) then 
            data.json.name = user.username
            data.json.uid = user.uid 
            addtoselection(round.roundid, data.json)
        end
        return OK_TABLE

    elseif(data.event == USER_EVENT.REQUEST_ROUNDCARDS) then 
        -- Each user gets a list of cards to choose from 
        return selections[round.roundid]
    end

    -- Check everyone is waiting - this means all players have startup done
    local waiting = 0
    for k,v in pairs(game.people) do 
        if( v.state == USER_EVENT.REQUEST_WAITING ) then waiting = waiting + 1 end 
    end 

    -- Everyone waiting
    if(waiting == pcount) then 
        game.state = GAME_STATE.GAME_DISCUSS
        game.phasetime = TIMEOUT_DISCUSS
        for k,v in pairs(game.people) do v.state = USER_EVENT.NONE end     
    end 
    return OK_TABLE
end 

-- ---------------------------------------------------------------------------
-- Nothing much to do here
local function processdiscuss( game, round, data )

    local pcount = utils.tcount(game.people)
    if(data.event == USER_EVENT.REQUEST_WAITING) then 

        setUserWaiting(game, data.uid)

    elseif(data.event == USER_EVENT.SENDING_CHOICE) then 

        local user = getUser(game, data.uid)
        if(user) then 
            data.json.name = user.username
            data.json.uid = user.uid 
            addtoselection(round.roundid, data.json)
        end
        return OK_TABLE

    elseif(data.event == USER_EVENT.REQUEST_ROUNDCARDS) then 
        -- Each user gets a list of cards to choose from 
        local user = getUser(game, data.uid)
        if(user) then 
            return selections[round.roundid]
        end 
    end

    -- Check everyone is waiting - this means all players have startup done
    local waiting = 0
    for k,v in pairs(game.people) do 
        if( v.state == USER_EVENT.REQUEST_WAITING ) then waiting = waiting + 1 end 
    end 

    -- Everyone waiting
    if(waiting == pcount) then 
        game.state = GAME_STATE.GAME_VERDICT
        game.phasetime = TIMEOUT_VERDICT
        for k,v in pairs(game.people) do v.state = USER_EVENT.NONE end     
    end 
    return OK_TABLE
end

-- ---------------------------------------------------------------------------
-- Wait for judges verdict
local function processverdict( game, round, data )

    local pcount = utils.tcount(game.people)
    if(data.event == USER_EVENT.REQUEST_WAITING) then 

        setUserWaiting(game, data.uid)

    elseif(data.event == USER_EVENT.SENDING_VERDICT) then 

        round.verdict = data.json.verdict
        return OK_TABLE
    end

    -- Check everyone is waiting - this means all players have startup done
    local waiting = 0
    for k,v in pairs(game.people) do 
        if( v.state == USER_EVENT.REQUEST_WAITING ) then waiting = waiting + 1 end 
    end 

    -- Everyone waiting
    if(waiting == pcount) then 
        game.state = GAME_STATE.GAME_NEXTROUND
        game.phasetime = TIMEOUT_NEXT
        for k,v in pairs(game.people) do v.state = USER_EVENT.NONE end     
    end 
    return OK_TABLE
end

-- ---------------------------------------------------------------------------

local function finalisecards(game, round, data)

    local allmycards = pools[game.name].mycards[data.uid]
    -- remove cards that lost
    for k,v in pairs(selections[round.roundid]) do 
        if(k ~= round.verdict) then 
            -- check if it is in this users card set 
            local marked = {}
            for i,card in pairs(allmycards) do 
                if(card.person.desc == v.person.desc and card.trait.desc == v.trait.desc) then 
                    tinsert(marked, i)
                end 
            end 
            for i, vv in ipairs(marked) do 
                tremove(allmycards, vv)
            end 

        end 
    end  
    pools[game.name].mycards[data.uid] = allmycards
    round.cards = allmycards
end

-- ---------------------------------------------------------------------------
-- Upon verdict completion set new judge, remove losing characters
--   the start new round
local function processnextround( game, round, data )

    local pcount = utils.tcount(game.people)
    if(data.event == USER_EVENT.REQUEST_WAITING) then 

        finalisecards(game, round, data)
        setUserWaiting(game, data.uid)
    end 

    -- Check everyone is waiting - this means all players have startup done
    local waiting = 0
    for k,v in pairs(game.people) do 
        if( v.state == USER_EVENT.REQUEST_WAITING ) then waiting = waiting + 1 end 
    end 

    -- Everyone waiting
    if(waiting == pcount) then 

        -- check if only one player with cards? If so winner.. else keep going


        -- If players have no cards, they become judges automatically


        -- If all players have cards then cycle judge
        round.judge = round.judge + 1
        if(round.judge > utils.tcount( game.people )) then round.judge = 1 end 

        newround(game, game.round + 1, round.gamestate, round)

        game.state = GAME_STATE.GAME_SCENARIO
        game.phasetime = TIMEOUT_SCENARIO
        for k,v in pairs(game.people) do v.state = USER_EVENT.NONE end     
    end 
    return OK_TABLE
end

-- ---------------------------------------------------------------------------
-- Finish collects stats on users and stores new traits, persons and scenarios
local function processfinish( game, round, data )

    local pcount = utils.tcount(game.people)
    if(data.event == USER_EVENT.REQUEST_WAITING) then 

        setUserWaiting(game, data.uid)
    end 
end

-- ---------------------------------------------------------------------------
-- Incoming data is processed here. Check state and only process 
--   when state matches request data
local function processround( game, data )

    local roundid = game.name..string.format("%02d", game.round)
    local round = rounds[roundid]
    if(round == nil) then p(rounds); return nil end

    -- Incoming data is a user submission which has a strict format. See top.
    if(checkround( game, round, data ) == nil) then return nil end

    local outtbl = { }

    -- Common events - respond directly
    local event = data.event
    if(event == USER_EVENT.POLL) then 

        return OK_TABLE

    elseif(event == USER_EVENT.REQUEST_GAME) then 

        return game

    elseif(event == USER_EVENT.REQUEST_ROUND) then 

        -- These are modified each round
        round.cards = pools[game.name].mycards[data.uid]
        return round
    end 

    -- During joining players can create local traits and persons (these are submitted here)
    if(game.state == GAME_STATE.GAME_JOINING) then 

        outtbl = processjoining( game, round, data )

    -- The game is starting. Any init etc for the rounds are done here
    --   Assigning empty trait and persons. Selecting a start judge
    elseif(game.state == GAME_STATE.GAME_STARTING) then 

        outtbl = processstarting( game, round, data )        

    -- The judge is now choosing a scenario and players can browser their characters
    elseif(game.state == GAME_STATE.GAME_SCENARIO) then 

        outtbl = processscenario( game, round, data )

    -- Scenario chosen, now people have a limited time to choose their character that best suits
    elseif(game.state == GAME_STATE.GAME_PLAY) then 

        outtbl = processplay( game, round, data )

    -- Scenario chosen, now people have a limited time to choose their character that best suits
    elseif(game.state == GAME_STATE.GAME_DISCUSS) then 

        outtbl = processdiscuss( game, round, data )

    -- The judge choose a single character for the win. 
    elseif(game.state == GAME_STATE.GAME_VERDICT) then 

        outtbl = processverdict( game, round, data )

    -- End of round means discarding dead characters and preparing the next round (jumps to STARTING)
    elseif(game.state == GAME_STATE.GAME_NEXTROUND) then 

        outtbl = processnextround( game, round, data )

    -- When only one player is left standing (there can be only one)  we are complete.
    --     Tally up scores, show scores. Show summaries. Save data for stats/reports.
    elseif(game.state == GAME_STATE.GAME_FINISH) then 

        outtbl = processfinish( game, round, data )
    end 

    return outtbl
end

-- ---------------------------------------------------------------------------

return {

	init				= init,
	setup 				= setup,
	
    processround        = processround,
	submitselect 		= submitselect,
	readround			= readround,

	getplayername 		= getplayername,

    GAME_STATE          = GAME_STATE, 
	DISCUSS_TIMEOUT		= TIMEOUT_DISCUSS,
	SELECT_TIMEOUT 		= TIMEOUT_SELECT,
}

-- ---------------------------------------------------------------------------
