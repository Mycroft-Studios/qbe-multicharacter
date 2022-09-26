local QBE = exports['qb-extended']:GetCoreObject()
local hasDonePreloading = {}

-- Functions

local function GiveStarterItems(source)
    local source = source
    local Player = QBE.GetPlayer(source)

    for _, v in pairs(QBE.Shared.StarterItems) do
        local info = {}
        if v.item == "id_card" then
            info.citizenid = Player.PlayerData.citizenid
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.gender = Player.PlayerData.charinfo.gender
            info.nationality = Player.PlayerData.charinfo.nationality
        elseif v.item == "driver_license" then
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.type = "Class C Driver License"
        end
        Player.Functions.AddItem(v.item, v.amount, false, info)
    end
end

local function loadHouseData(source)
    local HouseGarages = {}
    local Houses = {}
    local result = MySQL.query.await('SELECT * FROM houselocations', {})
    if result[1] then
        for i=1, #(result) do
            local owned = false
            if tonumber(result[i].owned) == 1 then
                owned = true
            end
            local garage = result[i].owned.garage and json.decode(result[i].owned.garage) or {}
            Houses[result[i].owned.name] = {
                coords = json.decode(result[i].owned.coords),
                owned = owned,
                price = result[i].owned.price,
                locked = true,
                adress = result[i].owned.label,
                tier = result[i].owned.tier,
                garage = garage,
                decorations = {},
            }
            HouseGarages[result[i].owned.name] = {
                label = result[i].owned.label,
                takeVehicle = garage,
            }
        end
    end
    -- What the *fuck* is this?
    -- why is it sending it to completely differant resources that are not even depenednacies?
    -- TriggerClientEvent("qb-garages:client:houseGarageConfig", source, HouseGarages)
    -- TriggerClientEvent("qb-houses:client:setHouseConfig", source, Houses)
end

-- Commands

QBE.Commands.Add("logout", Lang:t("commands.logout_description"), {}, false, function(source)
    QBE.Player.Logout(source)
    TriggerClientEvent('qbe-multicharacter:client:chooseChar', source)
end, "admin")


-- Is this a debug command ??????
-- QBE.Commands.Add("closeNUI", Lang:t("commands.closeNUI_description"), {}, false, function(source)
--     TriggerClientEvent('qbe-multicharacter:client:closeNUI', source)
-- end)

-- Events

AddEventHandler('QBE:Server:PlayerLoaded', function(Player)
    Wait(1000) -- 1 second should be enough to do the preloading in other resources
    hasDonePreloading[Player.PlayerData.source] = true
end)

AddEventHandler('QBE:Server:OnPlayerUnload', function(source)
    hasDonePreloading[source] = false
end)

RegisterNetEvent('qbe-multicharacter:server:disconnect', function()
    local source = source
    DropPlayer(source, Lang:t("commands.droppedplayer"))
end)

RegisterNetEvent('qbe-multicharacter:server:loadUserData', function(cData)
    local source = source
    if QBE.Player.Login(source, cData.citizenid) then
        repeat
            Wait(10)
        until hasDonePreloading[source]
        print('[^2INFO^7] Player ^5'..GetPlayerName(source)..'^7 (Citizen ID: ^5'..cData.citizenid..'^7) has succesfully loaded!')
        QBE.Commands.Refresh(source)
        loadHouseData(source)
        TriggerClientEvent('apartments:client:setupSpawnUI', source, cData)
        TriggerEvent("qbe-log:server:CreateLog", "joinleave", "Loaded", "green", "**".. GetPlayerName(source) .. "** ("..(QBE.GetIdentifier(source, 'discord') or 'undefined') .." |  ||"  ..(QBE.GetIdentifier(source, 'ip') or 'undefined') ..  "|| | " ..(QBE.GetIdentifier(source, 'license') or 'undefined') .." | " ..cData.citizenid.." | "..source..") loaded..")
    end
end)

RegisterNetEvent('qbe-multicharacter:server:createCharacter', function(data)
    local source = source
    local newData = {}
    newData.cid = data.cid
    newData.charinfo = data
    if QBE.Player.Login(source, false, newData) then
        repeat
            Wait(10)
        until hasDonePreloading[source]
        if Apartments.Starting then
            SetPlayerRoutingBucket(source, source)
            print('[^2INFO^7] Player ^5'..GetPlayerName(source)..'^7 has succesfully loaded!')
            QBE.Commands.Refresh(source)
            loadHouseData(source)
            TriggerClientEvent("qbe-multicharacter:client:closeNUI", source)
            TriggerClientEvent('apartments:client:setupSpawnUI', source, newData)
            GiveStarterItems(source)
        else
            print('[^2INFO^7] Player ^5'..GetPlayerName(source)..'^7 has succesfully loaded!')
            QBE.Commands.Refresh(source)
            loadHouseData(source)
            TriggerClientEvent("qbe-multicharacter:client:closeNUIdefault", source)
            GiveStarterItems(source)
        end
    end
end)

RegisterNetEvent('qbe-multicharacter:server:deleteCharacter', function(citizenid)
    local source = source
    QBE.Player.DeleteCharacter(source, citizenid)
    TriggerClientEvent('QBE:Notify', source, Lang:t("notifications.char_deleted") , "success")
end)

-- Callbacks

QBE.CreateCallback("qbe-multicharacter:server:GetUserCharacters", function(source, cb)
    local source = source
    local license = QBE.GetIdentifier(source, 'license')

    MySQL.query('SELECT * FROM players WHERE license = ?', {license}, function(result)
        cb(result)
    end)
end)

QBE.CreateCallback("qbe-multicharacter:server:GetServerLogs", function(_, cb)
    MySQL.query('SELECT * FROM server_logs', {}, function(result)
        cb(result)
    end)
end)

QBE.CreateCallback("qbe-multicharacter:server:GetNumberOfCharacters", function(source, cb)
    local source = source
    local license = QBE.GetIdentifier(source, 'license')
    local numOfChars = Config.PlayersNumberOfCharacters[license] or Config.DefaultNumberOfCharacters
    cb(numOfChars)
end)

QBE.CreateCallback("qbe-multicharacter:server:setupCharacters", function(source, cb)
    local license = QBE.GetIdentifier(source, 'license')
    local plyChars = {}
    MySQL.query('SELECT * FROM players WHERE license = ?', {license}, function(result)
        for i = 1, (#result), 1 do
            result[i].charinfo = json.decode(result[i].charinfo)
            result[i].money = json.decode(result[i].money)
            result[i].job = json.decode(result[i].job)
            plyChars[#plyChars+1] = result[i]
        end
        cb(plyChars)
    end)
end)

QBE.CreateCallback("qbe-multicharacter:server:getSkin", function(_, cb, cid)
    local result = MySQL.query.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = ?', {cid, 1})
    cb(result[1] and result[1].model, result[1].skin or nil)
end)

QBE.Commands.Add("deletechar", Lang:t("commands.deletechar_description"), {{name = Lang:t("commands.citizenid"), help = Lang:t("commands.citizenid_help")}}, false, function(source,args)
    if args and args[1] then
        QBE.Player.ForceDeleteCharacter(tostring(args[1]))
        TriggerClientEvent("QBE:Notify", source, Lang:t("notifications.deleted_other_char", {citizenid = tostring(args[1])}))
    else
        TriggerClientEvent("QBE:Notify", source, Lang:t("notifications.forgot_citizenid"), "error")
    end
end, "god")