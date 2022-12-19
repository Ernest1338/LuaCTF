#!/bin/luajit

local log = require("log")

local function main()
    local logger = log.new("logs.txt")
    logger.log("testing123")
end

main()
