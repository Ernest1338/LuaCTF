-- TODO: dont allow duplicate keys

local serde = require("serde")

function commit_db_change(database, file_name)
    local file_handle = io.open(file_name, "w")
    file_handle:write(serde.serialize(database))
    file_handle:close()
end

function create_db(file_name, tables)
    local file_handle = io.open(file_name, "w")
    local database = ""

    for i, tab in pairs(tables) do
        database = database .. tab .. "\n"
        if i ~= #tables then
            database = database .. "-----\n"
        end
    end

    file_handle:write(database)
    file_handle:close()

    return serde.deserialize(database)
end

DB = {}

function DB.new(file_name, tables)
    local db_obj = {}

    local file_handle = io.open(file_name, "r+")
    if file_handle == nil then
        db_obj.db = create_db(file_name, tables)
        commit_db_change(db_obj.db, file_name)
    else
        db_obj.db = serde.deserialize(file_handle:read("*a"))
        file_handle:close()
    end

    function db_obj.insert(tab_name, data)
        for i, tab in pairs(db_obj.db) do
            if tab.name == tab_name then
                table.insert(db_obj.db[i].data, data)
                commit_db_change(db_obj.db, file_name)
                return 0
            end
        end
        return nil
    end

    function db_obj.update(tab_name, data)
        for i, tab in pairs(db_obj.db) do
            if tab.name == tab_name then
                for a, tab_data in pairs(tab.data) do
                    if tab_data[1] == data[1] then
                        db_obj.db[i].data[a][2] = data[2]
                        commit_db_change(db_obj.db, file_name)
                        return 0
                    end
                end
                return nil
            end
        end
    end

    function db_obj.remove(tab_name, key)
        for i, tab in pairs(db_obj.db) do
            if tab.name == tab_name then
                for a, tab_data in pairs(tab.data) do
                    if tab_data[1] == key then
                        local ret_val = table.remove(db_obj.db[i].data, a)
                        commit_db_change(db_obj.db, file_name)
                        return ret_val
                    end
                end
                return nil
            end
        end
    end

    function db_obj.get(tab_name, key)
        for _, tab in pairs(db_obj.db) do
            if tab.name == tab_name then
                for _, data in pairs(tab.data) do
                    if data[1] == key then
                        return data[2]
                    end
                end
                return nil
            end
        end
    end

    function db_obj.exists(tab_name, key)
        for _, tab in pairs(db_obj.db) do
            if tab.name == tab_name then
                for _, data in pairs(tab.data) do
                    if data[1] == key then
                        return true
                    end
                end
                return false
            end
        end
    end

    return db_obj
end

return DB
