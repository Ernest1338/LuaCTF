#!/bin/luajit

local web = require("webjit")

local function main()
    web.add("/", function() return "test" end)

    web.run("0.0.0.0", "8000", false)
end

main()
