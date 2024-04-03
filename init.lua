local db = dbConnect("sqlite", "player_times.db")

if not db then
    outputDebugString("Could not connect to SQLite database.", 2)
    return
end

dbExec(db, "CREATE TABLE IF NOT EXISTS player_times (player_account TEXT PRIMARY KEY, total_time INTEGER)")

local playerData = setmetatable({}, {
    __index = function(tbl, key)
        return {
            joinTime = 0,
            totalTime = 0,
        }
    end
})

local function initializePlayerData(playerName)
    local query = dbQuery(db, "SELECT total_time FROM player_times WHERE player_account=?", playerName)
    local result = dbPoll(query, -1)
    if result and #result > 0 then
        local totalTime = tonumber(result[1]["total_time"])
        playerData[playerName] = {
            joinTime = os.time(),
            totalTime = totalTime
        }
    else
        playerData[playerName] = {
            joinTime = os.time(),
            totalTime = 0
        }
        dbExec(db, "INSERT INTO player_times (player_account, total_time) VALUES (?, ?)", playerName, 0)
    end
    dbFree(query)
end

function onPlayerLogin(_, account)
    local playerName = getAccountName(account)
    if playerName then
        initializePlayerData(playerName)
    end
end
addEventHandler("onPlayerLogin", root, onPlayerLogin)

function onLoadPlayers()
    for _, player in ipairs(getElementsByType("player")) do
        local account = getPlayerAccount(player)
        if account and not isGuestAccount(account) then
            local playerName = getAccountName(account)
            if playerName then
                initializePlayerData(playerName)
            end
        end
    end
end
addEventHandler("onResourceStart", resourceRoot, onLoadPlayers)

function onPlayerQuit()
    local account = getPlayerAccount(source)
    if account then
        local playerName = getAccountName(account)
        if playerData[playerName] then
            local currentTime = os.time()
            local playerInfo = playerData[playerName]
            local totalTime = playerInfo.totalTime + (currentTime - playerInfo.joinTime)
            
            dbExec(db, "UPDATE player_times SET total_time=? WHERE player_account=?", totalTime, playerName)
            playerData[playerName] = nil
        end
    end
end
addEventHandler("onPlayerQuit", root, onPlayerQuit)

function showPlayerTime(player, command)
    local account = getPlayerAccount(player)
    if not isGuestAccount(account) then
        local playerName = getAccountName(account)
        local playerInfo = playerData[playerName]
        if playerInfo then
            local currentTime = os.time()
            local totalTime = playerInfo.totalTime + (currentTime - playerInfo.joinTime)
            outputChatBox("Your total play time is: " .. formatTime(totalTime), player)
        else
            outputChatBox("You have no registered time yet.", player)
        end
    else
        outputChatBox("You need to be logged in to use this command.", player)
    end
end

function showTopPlayers()
    local query = dbQuery(db, "SELECT player_account, total_time FROM player_times ORDER BY total_time DESC LIMIT 10")
    local result = dbPoll(query, -1)
    if result and #result > 0 then
        outputChatBox("Top 10 Players with Most Play Time:")
        for i, data in ipairs(result) do
            outputChatBox(i .. ". " .. data["player_account"] .. ": " .. formatTime(tonumber(data["total_time"])))
        end
    else
        outputChatBox("There is not enough data to display.")
    end
    dbFree(query)
end

addCommandHandler("mytime", showPlayerTime)
addCommandHandler("toptime", showTopPlayers)

function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    
    local timeString = ""
    local count = 0
    
    if hours > 0 then
        timeString = timeString .. hours .. " hour" .. (hours > 1 and "s" or "")
        count = count + 1
    end
    
    if minutes > 0 then
        if count > 0 then
            timeString = timeString .. " and "
        end
        timeString = timeString .. minutes .. " minute" .. (minutes > 1 and "s" or "")
        count = count + 1
    end
    
    if seconds > 0 then
        if count > 0 then
            timeString = timeString .. " and "
        end
        timeString = timeString .. seconds .. " second" .. (seconds > 1 and "s" or "")
    end
    
    return timeString
end
