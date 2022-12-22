#!/bin/luajit

local db = require("db")

local function dump_table(o)
    if type(o) == 'table' then
        local s = '{'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump_table(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local function main()
    local database = db.new("database.db", {"users", "testing"})
    print(dump_table(database.db))

    database.insert("users", {"user1", "password1"})
    print(dump_table(database.db))
    database.insert("users", {"user2", "password2"})
    print(dump_table(database.db))
    database.update("users", {"user2", "password3"})
    print(dump_table(database.db))
    database.insert("testing", {"test1", "test2"})
    print(dump_table(database.db))

    print(dump_table(database.get_table("users")))

    print(database.get("testing", "test1"))
end

main()
