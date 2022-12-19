-- serialization: from object to data
-- deserialization: from data to object

Serde = {}

local function string_split(str, sep)
    local out = {}
    for chunk in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(out, chunk)
    end
    return out
end

local function data_to_tables(data)
    local tables = { {} }

    for _, line in pairs(string_split(data, "\n")) do
        if line == "-----" then
            table.insert(tables, {})
        else
            table.insert(tables[#tables], line)
        end
    end

    return tables
end

function Serde.deserialize(data)
    local deserialized = {}

    local tables = data_to_tables(data)

    for _, tab in pairs(tables) do
        local tmp_tab = {}
        tmp_tab.name = tab[1]
        tmp_tab.data = {}
        for i = 2, #tab do
            local data_split = string_split(tab[i], ":")
            -- TODO: (tamper proofing)
            -- handle case when tab[i] contains more than one ":"
            -- key and value can not be empty
            table.insert(tmp_tab.data, {data_split[1], data_split[2]})
        end
        table.insert(deserialized, tmp_tab)
    end

    return deserialized
end

function Serde.serialize(object)
    local serialized = ""

    for i, tab in pairs(object) do
        serialized = serialized .. tab.name .. "\n"
        for _, data in pairs(tab.data) do
            serialized = serialized .. data[1] .. ":" .. data[2] .. "\n"
        end
        if i ~= #object then
            serialized = serialized .. "-----\n"
        end
    end

    return serialized
end

return Serde
