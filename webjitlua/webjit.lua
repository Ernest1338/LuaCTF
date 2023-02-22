local http_server = require "http.server"
local http_headers = require "http.headers"

-- TODO:
-- ? socket (or cqueues) backend (rewrite)

local webjit = {}
webjit.endpoints = {}
webjit.callbacks = {}
webjit.static_endpoints = {}
webjit.log = true
webjit.enable_caching = false
webjit.cache = {}

local escape_char = string.char(27)
Color = {
    red = escape_char .. "[31m",
    green = escape_char .. "[32m",
    gold = escape_char .. "[33m",
    blue = escape_char .. "[34m",
    yellow = escape_char .. "[93m",
    reset = escape_char .. "[00m",
}

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        if tonumber(str) ~= nil then
            table.insert(t, tonumber(str))
        else
            table.insert(t, str)
        end
    end
    return t
end

local function endpoint_matches(endpoint, matching_for)
    local endpoint_split = split(endpoint, "/")
    local matching_endpoint_split = split(matching_for, "/")
    if #endpoint_split ~= #matching_endpoint_split then
        return false
    end
    for i = 1, #matching_endpoint_split do
        if matching_endpoint_split[i] ~= "<>" then
            if matching_endpoint_split[i] ~= endpoint_split[i] then
                return false
            end
        end
    end
    return true
end

local function get_endpoint_params(endpoint, matching_for)
    local endpoint_split = split(endpoint, "/")
    local matching_endpoint_split = split(matching_for, "/")
    local params = {}
    for i = 1, #matching_endpoint_split do
        if matching_endpoint_split[i] == "<>" then
            table.insert(params, endpoint_split[i])
        end
    end
    -- if there is only one parameter, return it instead of a table
    if #params == 1 then
        return params[1]
    end
    return params
end

local function parse_cookies(to_parse)
    if to_parse == nil then
        return {}
    end
    local cookies = {}
    for _, cookie in pairs(split(to_parse, "; ")) do
        local cookie_split = split(cookie, "=")
        table.insert(cookies, { cookie_split[1], cookie_split[2] })
    end
    return cookies
end

local function reply(_, stream) -- _ = server
    -- Read in headers
    local req_headers = assert(stream:get_headers())
    local req_method = req_headers:get(":method")

    if webjit.log then
        -- Log request to stdout
        assert(io.stdout:write(string.format('%s[%s]%s "%s %s HTTP/%g"  "%s" "%s"\n',
            Color.green,
            os.date("%d/%b/%Y %H:%M:%S"),
            Color.reset,
            req_method or "",
            req_headers:get(":path") or "",
            stream.connection.version,
            req_headers:get("referer") or "-",
            req_headers:get("user-agent") or "-"
        )))
    end

    -- Handle response
    local res_headers = http_headers.new()
    if req_method ~= "HEAD" then
        local req_endpoint = req_headers["_data"][2]["value"]
        -- check for normal endpoints
        for _, endpoint in pairs(webjit.endpoints) do
            if endpoint_matches(req_endpoint, endpoint[1]) then
                local data_from_cache = webjit.get_from_cache(endpoint[1])
                if data_from_cache ~= nil and webjit.enable_caching and endpoint[3] then
                    res_headers:append(":status", "200")
                    if type(data_from_cache) == "table" then
                        res_headers:append("content-type", data_from_cache[2])
                    else
                        res_headers:append("content-type", "text/plain")
                    end
                    -- Send headers to client; end the stream immediately if this was a HEAD request
                    assert(stream:write_headers(res_headers, req_method == "HEAD"))
                    -- Send the data
                    if type(data_from_cache) == "table" then
                        assert(stream:write_chunk(data_from_cache[1], true))
                    else
                        assert(stream:write_chunk(data_from_cache, true))
                    end
                else
                    local callback_return
                    local cookies = parse_cookies(req_headers:get("cookie"))
                    local endpoint_params = get_endpoint_params(req_endpoint, endpoint[1])
                    if #endpoint_params ~= 0 then
                        callback_return = endpoint[2](endpoint_params, cookies)
                    else
                        callback_return = endpoint[2](cookies)
                    end
                    -- At this point we know that it's going to be status 200
                    res_headers:append(":status", "200")
                    if type(callback_return) == "table" then
                        res_headers:append("content-type", callback_return[2])
                    else
                        res_headers:append("content-type", "text/plain")
                    end
                    -- Send headers to client; end the stream immediately if this was a HEAD request
                    assert(stream:write_headers(res_headers, req_method == "HEAD"))
                    -- Send the data
                    if type(callback_return) == "table" then
                        assert(stream:write_chunk(callback_return[1], true))
                    else
                        assert(stream:write_chunk(callback_return, true))
                    end
                    if webjit.enable_caching and endpoint[3] then
                        webjit.cache_result(endpoint[1], callback_return)
                    end
                end
                return
            end
        end
        -- check for static file hosting
        for _, endpoint in pairs(webjit.static_endpoints) do
            local endpoint_split = split(endpoint[1], "/")
            if #endpoint_split == 0 then
                endpoint_split = { "/" }
            end
            local endpoint_main = endpoint_split[1]
            local req_endpoint_split = split(req_endpoint, "/")
            if #req_endpoint_split < 2 then
                table.insert(req_endpoint_split, 1, "/")
            end
            if endpoint_main == req_endpoint_split[1] then
                -- TODO: fix serving default index.html (when requesting a dir not file) at non "/" endpoints
                local filename = req_endpoint_split[2]
                if filename == nil then filename = "index.html" end
                if string.find(filename, "%.%.") then break end
                local file_handle = io.open(endpoint[2] .. filename, "rb")
                if file_handle == nil then break end
                res_headers:append(":status", "200")
                if filename:match(".html$") then
                    res_headers:append("content-type", "text/html")
                else
                    res_headers:append("content-type", "application/octet-stream")
                end
                assert(stream:write_headers(res_headers, req_method == "HEAD"))
                assert(stream:write_body_from_file(file_handle))
                return
            end
        end
        -- Default 404 page
        res_headers:append(":status", "404")
        res_headers:append("content-type", "text/html")
        assert(stream:write_headers(res_headers, req_method == "HEAD"))
        assert(stream:write_chunk("<h1>404 Not Found</h1>", true))
    end
end

function webjit.add(endpoint, callback, should_cache)
    local l_should_cache = should_cache
    if should_cache == nil then
        l_should_cache = false
    end
    table.insert(webjit.endpoints, { endpoint, callback, l_should_cache })
end

function webjit.host_static_files(endpoint, dir)
    table.insert(webjit.static_endpoints, { endpoint, dir })
end

function webjit.invalidate_cache(endpoint)
    if endpoint == nil then
        -- print("whole cache invalidated")
        webjit.cache = {}
    end
    for i = 1, #webjit.cache do
        if webjit.cache[i][1] == endpoint then
            -- print("cache endpoint: " .. endpoint .. " invalidated")
            table.remove(webjit.cache, i)
            return
        end
    end
end

function webjit.get_from_cache(endpoint)
    for i = 1, #webjit.cache do
        if webjit.cache[i][1] == endpoint then
            webjit.cache[i][3] = webjit.cache[i][3] - 1
            if webjit.cache[i][3] == 0 then
                webjit.invalidate_cache(endpoint)
                return nil
            end
            -- print("retrieved from cache endpoint: " .. endpoint)
            return webjit.cache[i][2]
        end
    end
    -- print("cache miss on endpoint: " .. endpoint)
    return nil
end

function webjit.cache_result(endpoint, callback)
    -- print("caching endpoint: " .. endpoint)
    -- 100 reqs is the default cache life time
    table.insert(webjit.cache, { endpoint, callback, 100 })
end

function webjit.run(host, port, log, enable_caching)
    local server = assert(http_server.listen {
        host = host;
        port = port;
        onstream = reply;
        onerror = function(_, context, op, err, _) -- _ = server, _ = errno
            if webjit.log then
                local msg = op .. " on " .. tostring(context) .. " failed"
                if err then
                    msg = msg .. ": " .. tostring(err)
                end
                msg = Color.red .. "[ERROR] " .. Color.reset .. msg
                assert(io.stderr:write(msg, "\n"))
            end
        end;
    })

    -- Disable logging if choosen
    if log == false then
        webjit.log = false
    end

    -- Enable caching if choosen
    if enable_caching == true then
        webjit.enable_caching = true
    end

    -- Manually call :listen() so that we are bound before calling :localname()
    assert(server:listen())
    do
        local bound_port = select(3, server:localname())
        assert(io.stderr:write(string.format("%sListening on port %s%d%s\n", Color.gold, Color.green, bound_port,
            Color.reset)))
    end
    -- Start the main server loop
    assert(server:loop())
end

return webjit
