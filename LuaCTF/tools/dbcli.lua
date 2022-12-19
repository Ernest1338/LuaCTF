#!/bin/luajit

local argparse = require("argparse")
package.path = package.path .. ";../src/?.lua"
local database = require("db")

local function list_tables(db)
    for _, tab in pairs(db.db) do
        print(tab.name)
    end
end

local function dump_table(db, table_name)
    for _, tab in pairs(db.db) do
        if tab.name == table_name then
            for _, data in pairs(tab.data) do
                print(data[1] .. ":" .. data[2])
            end
            return
        end
    end
    print("Table " .. table_name .. " does not exist")
end

local function get_from_table(db, table_name, key)
    print(db.get(table_name, key))
end

local function try_exec(ret_val)
    if ret_val == nil then
        print("ERROR")
        return
    end
    print("OK")
end

local function modify_in_table(db, table_name, key, new_value)
    try_exec(db.update(table_name, { key, new_value }))
end

local function append_to_table(db, table_name, key, value)
    try_exec(db.insert(table_name, { key, value }))
end

local function remove_from_table(db, table_name, key)
    try_exec(db.remove(table_name, key))
end

-- FIXME: this is just coped from main.lua
local function hash(data)
    -- TODO: better hash function
    local out_hash = 0
    for chr in data:gmatch(".") do
        out_hash = out_hash + string.byte(chr)
    end
    return out_hash
end

local function encode_email(email)
    return email:gsub("@", "%%40")
end

-- CTF only
local function add_ctf_user(db, username, email, password)
    db.insert("users", {username, hash(password)})
    db.insert("emails", {username, encode_email(email)})
    db.insert("scoreboard", {username, 0})
    db.insert("solutions", {username, "0,"})
    print("OK")
end

-- CTF only
local function remove_ctf_user(db, username)
    for i, _ in pairs(db.db) do
        db.remove(db.db[i].name, username)
    end
    print("OK")
end

local function init_db(db_filename)
    return database.new(db_filename)
end

-- TODO: create table

local function main()
    local parser = argparse("dbcli", "CLI for the custom database system")

    parser:option("-f --file", "Database file", "../src/database.db")

    parser:command("list l", "List tables")

    local dump_table_command = parser:command("dump d", "Dump table")
    dump_table_command:argument("table_name")

    local get_from_table_command = parser:command("get g", "Get data by key from a table")
    get_from_table_command:argument("table_name")
    get_from_table_command:argument("key")

    local modify_in_table_command = parser:command("modify m", "Modify data by key in a table")
    modify_in_table_command:argument("table_name")
    modify_in_table_command:argument("key")
    modify_in_table_command:argument("new_value")

    local append_to_table_command = parser:command("append a", "Append data to table")
    append_to_table_command:argument("table_name")
    append_to_table_command:argument("key")
    append_to_table_command:argument("value")

    local remove_from_table_command = parser:command("remove r", "Remove data from a table")
    remove_from_table_command:argument("table_name")
    remove_from_table_command:argument("key")

    local add_ctf_user_command = parser:command("adduser u", "Add (CTF) user")
    add_ctf_user_command:argument("username")
    add_ctf_user_command:argument("email")
    add_ctf_user_command:argument("password")

    local remove_ctf_user_command = parser:command("removeuser d", "Remove (CTF) user")
    remove_ctf_user_command:argument("username")

    local args = parser:parse()

    if args["list"] then
        list_tables(init_db(args["file"]))
    elseif args["dump"] then
        dump_table(init_db(args["file"]), args["table_name"])
    elseif args["get"] then
        get_from_table(init_db(args["file"]), args["table_name"], args["key"])
    elseif args["modify"] then
        modify_in_table(init_db(args["file"]), args["table_name"], args["key"], args["new_value"])
    elseif args["append"] then
        append_to_table(init_db(args["file"]), args["table_name"], args["key"], args["value"])
    elseif args["remove"] then
        remove_from_table(init_db(args["file"]), args["table_name"], args["key"])
    elseif args["adduser"] then
        add_ctf_user(init_db(args["file"]), args["username"], args["email"], args["password"])
    elseif args["removeuser"] then
        remove_ctf_user(init_db(args["file"]), args["username"])
    end
end

main()
