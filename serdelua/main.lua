#!/bin/luajit

local serde = require("serde")

local function main()
    local test_data = [[table1
key1:value1
key2:value2
-----
table2
key3:value3
key4:value4
]]
    local deserialized = serde.deserialize(test_data)
    local new_data = {
        name = "table3",
        data = {
            {"another key", "and some value"},
            {"key 69", "2137"},
            {"this", "and that"},
        },
    }
    table.insert(deserialized, new_data)
    table.insert(deserialized, {name="table4",data={{"a","b"},{"c","d"}}})
    local serialized = serde.serialize(deserialized)
    local deserialized2 = serde.deserialize(serialized)
    local serialized2 = serde.serialize(deserialized2)
    print(serialized2)
end

main()
