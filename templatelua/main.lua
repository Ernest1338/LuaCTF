#!/bin/luajit

local template = require("template")
local web = require("webjit")

local function root_handler()
    local index = template.render("index", {"<h1>this is rendered form lua!</h1>"})
    return {index, "text/html"}
end

local function test_handler()
    local content = template.render("test", {"<title>title changed with lua</title>", "<center><h1>This was rendered using lua!</h1></center>"})
    return {content, "text/html"}
end

local function main()
    web.add("/", root_handler)
    web.add("/test", test_handler)

    web.run("0.0.0.0", "8000", false)
end

main()
