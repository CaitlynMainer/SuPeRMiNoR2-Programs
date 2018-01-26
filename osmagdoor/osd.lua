local component = require("component")
local event = require("event")
local os = require("os")
local serialization = require("serialization")
local filesystem = require("filesystem")
local term = require("term")
local superlib = require("superlib")
local osmag = require("osmag")

dbfile = "/authdb.dat"
logfile = "/authlog.txt"

closeList = {}

local function openDoor(door, pass)
    if door.isOpen() == false then
        door.toggle(pass)
    end
end

local function closeDoor()
    doorad = table.remove(closeList, 1)
    door = component.proxy(doorad["addr"])
    if door.isOpen() == true then
        door.toggle(doorad["password"])
    end
end

local function toggleDoor(doordb)
    pass = doordb["password"]
    door = component.proxy(doordb["door"])
    openDoor(door, pass)
    table.insert(closeList, {addr=doordb["door"], password=doordb["password"]})
    event.timer(3, closeDoor)
end

local function checkCard(UUID, carddata, doordata)
    db = osmag.loadDB()

    if carddata["type"] == "temp" then 
        currenttime = os.time()
        if currenttime > carddata["expire"] then
            return false
        end
    end

    for i in ipairs(db["registered"]) do
        if db["registered"][i]["uuid"] == UUID then

            for i, g in ipairs(db["registered"][i]["groups"]) do
                if g == doordata["gid"] then
                    return db["registered"][i]
                end

            end

        end
    end
    return false
end

function findDoor(addr) --Finds the door linked to the provided mag reader UUID, if any. Returns door table
    for u, d in ipairs(db["pairs"]) do
        if addr == d["mag"] then
            return d
        end
    end
    return false
end

function auth(_,addr, playerName, data, UUID, locked)
    db = osmag.loadDB()

    carddata = serialization.unserialize(data)
    for i, d in ipairs(db["new"]) do --Check for first swipe of newly registered card, and get its UUID
        if d["code"] == carddata["code"] then
            if d["type"] == "full" then
                table.insert(db["registered"], {uuid=UUID, title=d["title"], type=d["type"], groups={1}})
            elseif d["type"] == "temp" then
                table.insert(db["registered"], {uuid=UUID, title=d["title"], type=d["type"], groups={1}, expire=d["expire"]})
            end
            osmag.log("Registered card ".. UUID .. " to user ".. d["title"])
            table.remove(db["new"], i)
            osmag.saveDB(db)
        end
    end

    dresult = findDoor(addr)
    if dresult then
        cresult = checkCard(UUID, carddata, dresult)
        if cresult then
            toggleDoor(cresult)
        end
    end 
end

db = osmag.loadDB()
print("OSd (OpenSecuritydoorDaemon) starting up...")
osmag.updateDB()
print("Registering event handlers")
event.listen("magData", auth)
print("Event listeners registered")
print("Do not run this program again, untill the next restart of this computer.")
print("if you do, you will have multiple handlers running.")