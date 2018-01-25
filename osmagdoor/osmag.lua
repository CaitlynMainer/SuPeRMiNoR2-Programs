local serialization = require("serialization")
local filesystem = require("filesystem")

m = {}

dbfile = "/authdb.dat"
logfile = "/authlog.txt"

function m.makeCode()
    local l = 10
    local s = ""
    for i = 1, l do
        s = s .. string.char(math.random(97, 122))
    end
    return s
end

function m.loadDB()
    if filesystem.exists(dbfile) == false then
        ldb = {pairs = {}, registered = {}, new = {}, groups = {}}
        table.insert(ldb["groups"], {"gid" = 1, "name" = "Default Group"})
    else
        f = io.open(dbfile, "rb")
        rdb = f:read("*a")
        ldb = serialization.unserialize(rdb)
        f:close()
    end
    return ldb
end

function m.saveDB(ldb)
	if filesystem.exists("/backups") == false then
		filesystem.makeDirectory("/backups")
	end
	filesystem.copy(dbfile, "/backups/" .. os.date() .. ".backup")
    f = io.open(dbfile, "wb")
    f:write(serialization.serialize(ldb))
    f:close()
end

function m.updateDB()
    local db = m.loadDB()
    print("Database updater scanning for things that need to be fixed...")

    for i, pair in ipairs(db["pairs"]) do
        if not pair["password"] then 
            newpass = osmag.makeCode()
            db["pairs"][i]["password"] = newpass
            doorc = component.proxy(pair["door"])
            doorc.setPassword(newpass)
            print("[DBUpdate] Added password to door "..pair["name"])
        end
        if not pair["gid"] then
            db["pairs"][i]["gid"] = 1
            print("[DBUpdate] Added default group to door "..pair["name"])
        end
    end

    --Remove expired cards
    print("Removing expired cards...")
    currenttime = os.time()
    for i, card in ipairs(db["registered"]) do
        if card["type"] == "temp" then
            if currenttime > card["expire"] then
                print("Removing expired card: "..card["title"])
                table.remove(db["registered"], i)
            end
        end
        if not card["groups"] then
            db["registered"][i]["groups"] = {}
            table.insert(db["registered"][i]["groups"], 1)
            print("[DBUpdate] Added default group to card "..card["title"])
        end
    end

    --Add group structure if it doesn't exist
    print("Adding default group structure")
    if not db["groups"] then
        db["groups"] = {}
        table.insert(ldb["groups"], {"gid" = 1, "name" = "Default Group"})

    print("Database update complete.")
    m.saveDB(db)
end

function killDoor(address, password)
	local door = component.proxy(address)
    door.setPassword(password, "")
end

function m.tryToDeleteDoor(address, password)
	pcall(killDoor, address, password)
end

function m.log(logdata)
    local f = io.open(logfile, "a")
    f:write(logdata .. "\n")
    f:close()
end

return m