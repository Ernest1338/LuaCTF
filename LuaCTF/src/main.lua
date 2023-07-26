#!/bin/luajit

local db = require("db")
local web = require("webjit")
local template = require("template")
local challenges = require("challenges")
local log = require("log")

-- CONFIGURATION
local log_requests_to_stdout = true
local log_events_to_file = true
local enable_caching = false -- EXPERIMENTAL

Database = db.new("database.db", { "users", "emails", "scoreboard", "solutions" })
Logger = log.new("logs.txt", log_events_to_file)

local function add_new_user(username, email, pass_hash)
    Database.insert("users", { username, pass_hash })
    Database.insert("emails", { username, email })
    Database.insert("scoreboard", { username, 0 })
    Database.insert("solutions", { username, "0," })
    Logger.log(string.format("New user created: \"%s\" \"%s\" \"%s\"", username, email, pass_hash))
end

local function get_cookie(cookies, looking_for)
    for _, cookie in pairs(cookies) do
        if cookie[1] == looking_for then
            return cookie[2]
        end
    end
    return nil
end

local function handle_menu(cookies, optional_logged_in)
    local to_return = "<a href=\"/register\">Register</a><a href=\"/login\">Login</a>"
    if optional_logged_in ~= nil then
        if optional_logged_in then
            to_return = "<a href=\"/profile\">Profile</a><a href=\"/logout\">Logout</a>"
        end
        return to_return
    end
    local logged_user = get_cookie(cookies, "ctf_user")
    if logged_user ~= nil and logged_user ~= "" then
        to_return = "<a href=\"/profile\">Profile</a><a href=\"/logout\">Logout</a>"
    end
    return to_return
end

local function users_endpoint(cookies)
    local users_table = ""

    for i, user in pairs(Database.db[1].data) do
        users_table = users_table .. "<tr><td>" .. i .. "</td><td>"
        users_table = users_table .. user[1] .. "</td></tr>"
    end

    return { template.render("empty", { handle_menu(cookies), template.render("users", { users_table }) }), "text/html" }
end

local function get_user_position(username)
    local scoreboard_data = {}

    for _, user in pairs(Database.db[1].data) do
        table.insert(scoreboard_data, { Database.get("scoreboard", user[1]), user[1] })
    end

    table.sort(scoreboard_data, function(lhs, rhs) return tonumber(lhs[1]) > tonumber(rhs[1]) end)

    for i, user in pairs(scoreboard_data) do
        if user[2] == username then
            return i
        end
    end

    return nil
end

local function scoreboard_endpoint(cookies)
    local scoreboard_table = ""

    local scoreboard_data = {}

    for _, user in pairs(Database.db[1].data) do
        table.insert(scoreboard_data, { Database.get("scoreboard", user[1]), user[1] })
    end

    table.sort(scoreboard_data, function(lhs, rhs) return tonumber(lhs[1]) > tonumber(rhs[1]) end)

    for i, user in pairs(scoreboard_data) do
        scoreboard_table = scoreboard_table .. "<tr><td>" .. i .. "</td><td>"
        scoreboard_table = scoreboard_table .. user[2] .. "</td><td>"
        scoreboard_table = scoreboard_table .. user[1] .. "</td></tr>"
    end

    return { template.render("empty", { handle_menu(cookies), template.render("scoreboard", { scoreboard_table }) }),
        "text/html" }
end

local function table_contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

local function string_split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local function has_solved(username, chal_id)
    local chals_solved = Database.get("solutions", username)
    if chals_solved == nil then
        return false
    end
    local solved_split = string_split(chals_solved, ",")
    return table_contains(solved_split, tostring(chal_id))
end

local function render_challenges(cookies)
    local chals_rendered = ""
    local username = get_cookie(cookies, "ctf_user")
    local i = 1
    for _, chal_cat in pairs(challenges) do
        if #chal_cat.challenges ~= 0 then
            chals_rendered = chals_rendered .. "<h3>" .. chal_cat.category .. "</h3>"
            for _, chal in pairs(chal_cat.challenges) do
                if has_solved(username, i) then
                    chals_rendered = chals_rendered ..
                        "<details style=\"background-color: #2B8F2B; color: black;\"><summary>" ..
                        chal[1] ..
                        " - " ..
                        chal[3] ..
                        " Points" ..
                        "</summary><p>" ..
                        chal[2] ..
                        "</p><form action=\"/flag_submit/\" method=\"GET\"><input type=\"text\" name=\"flag\" required=\"\" placeholder=\"flag{...}\"><input type=\"hidden\" name=\"challenge\" value=\""
                        ..
                        i .. "\"><input type=\"submit\" value=\"Submit\"></form></details>"
                else
                    chals_rendered = chals_rendered ..
                        "<details><summary>" ..
                        chal[1] ..
                        " - " ..
                        chal[3] ..
                        " Points" ..
                        "</summary><p>" ..
                        chal[2] ..
                        "</p><form action=\"/flag_submit/\" method=\"GET\"><input type=\"text\" name=\"flag\" required=\"\" placeholder=\"flag{...}\"><input type=\"hidden\" name=\"challenge\" value=\""
                        ..
                        i .. "\"><input type=\"submit\" value=\"Submit\"></form></details>"
                end
                i = i + 1
            end
        end
    end
    return chals_rendered
end

local function challenges_endpoint(cookies)
    local chals_rendered = render_challenges(cookies)
    return { template.render("empty", { handle_menu(cookies), template.render("challenges", { chals_rendered }) }),
        "text/html" }
end

local function split_get_params(data)
    local split = {}
    data = string.sub(data, 2, #data)
    local params = string_split(data, "&")
    for _, param in pairs(params) do
        local param_split = string_split(param, "=")
        table.insert(split, { param_split[1], param_split[2] })
    end
    return split
end

local function hash(data)
    -- DJB2 hashing algorithm
    local out = 5381
    for i = 1, #data do
        local char = string.byte(data, i)
        out = (out * 33) ~ char
    end
    return out
end

local function register_user_endpoint(data, cookies)
    local data_split = split_get_params(data)
    local to_return
    local username = data_split[1][2]
    local email = data_split[2][2]
    local password = data_split[3][2]
    local confirm_password = data_split[4][2]
    local password_hash = hash(password)

    if password ~= confirm_password then
        to_return = "Passwords do not match"
        goto done
    end
    if Database.exists("users", username) then
        to_return = "Username already exists"
        goto done
    end

    add_new_user(username, email, password_hash)

    if enable_caching then
        web.invalidate_cache()
    end

    to_return = "Registered successfully"
    ::done::
    return { template.render("empty",
        { handle_menu(cookies),
            "<article><h2 style=\"text-align: center;\">" ..
            to_return ..
            "</h2></article><script>history.pushState({}, null, document.URL.split(\"?\")[0]);</script>" ..
            template.render("register") }),
        "text/html" }
end

local function login_user_endpoint(data, cookies)
    local data_split = split_get_params(data)
    local to_return
    local set_cookies = ""
    local logged_in = false
    local username = data_split[1][2]
    local password = data_split[2][2]
    local password_hash = hash(password)
    local auth_key = hash(username .. password_hash)

    if not Database.exists("users", username) then
        to_return = "User does not exist"
        Logger.log(string.format("Login attempt at username \"%s\" which doesnt exist", username))
        goto done
    end
    if tonumber(Database.get("users", username)) ~= password_hash then
        to_return = "Wrong password"
        Logger.log(string.format("User \"%s\" failed to log in (wrong password)", username))
        goto done
    end

    Logger.log(string.format("User logged in: \"%s\" \"%s\" \"%s\"", username, password_hash, auth_key))

    set_cookies = "<script>document.cookie = \"ctf_user=" ..
        username ..
        "; path=/\"; document.cookie = \"ctf_auth_key=" ..
        auth_key .. "; path=/\";</script>"

    if enable_caching then
        web.invalidate_cache()
    end

    to_return = "Logged in successfully!"
    logged_in = true
    ::done::
    return { template.render("empty",
        { handle_menu(cookies, logged_in),
            "<article><h2 style=\"text-align: center;\">" ..
            to_return ..
            "</h2></article><script>history.pushState({}, null, document.URL.split(\"?\")[0]);</script>" ..
            set_cookies .. template.render("login") }),
        "text/html" }
end

local function get_chal_from_id(id)
    local i = 1
    for _, cat in pairs(challenges) do
        for _, chal in pairs(cat.challenges) do
            if i == id then
                return chal
            end
            i = i + 1
        end
    end
    return nil
end

local function flag_decode(flag)
    local decoded = flag
    decoded = decoded:gsub("%%7B", "{")
    decoded = decoded:gsub("%%7D", "}")
    return decoded
end

local function flag_submit_endpoint(data, cookies)
    local data_split = split_get_params(data)
    local to_return
    local flag = flag_decode(data_split[1][2])
    local challenge_id = tonumber(data_split[2][2])
    local challenge = get_chal_from_id(challenge_id)
    local username = get_cookie(cookies, "ctf_user")
    if username == nil then
        return { template.render("empty", { handle_menu(cookies), template.render("challenges",
            { "<article><h2 style=\"text-align: center;\">You need to log in, to submit a flag!</h2></article>" ..
            render_challenges(cookies) }) }),
            "text/html" }
    end
    local previous_points = Database.get("scoreboard", username)
    local previous_solutions = Database.get("solutions", username)
    if challenge == nil then
        to_return = "[ERROR] Something went wrong"
        goto done
    end

    if flag == challenge[4] then
        local auth_key = get_cookie(cookies, "ctf_auth_key")
        local expected_auth_key = hash(username .. Database.get("users", username))
        if auth_key ~= expected_auth_key then
            to_return = "[ERROR] something went wrong"
            goto done
        end
        if not has_solved(username, challenge_id) then
            to_return = "Flag accepted, added " .. challenge[3] .. " points!"
            Database.update("scoreboard", { username, previous_points + challenge[3] })
            Database.update("solutions", { username, previous_solutions .. challenge_id .. "," })
            Logger.log(string.format("Challenge \"%s\" solved by \"%s\"", challenge[1], username))
        else
            to_return = "You already solved this challenge!"
        end
    else
        Logger.log(string.format("User \"%s\" failed to solve challenge \"%s\"", username, challenge[1]))
        to_return = "Wrong flag"
    end

    ::done::
    return { template.render("empty", { handle_menu(cookies), template.render("challenges",
        { "<article><h2 style=\"text-align: center;\">" .. to_return .. "</h2></article>" .. render_challenges(cookies) }) }),
        "text/html" }
end

local function index_endpoint(cookies)
    return { template.render("empty", { handle_menu(cookies), template.render("index") }), "text/html" }
end

local function login_endpoint(cookies)
    return { template.render("empty", { handle_menu(cookies), template.render("login") }), "text/html" }
end

local function register_endpoint(cookies)
    return { template.render("empty", { handle_menu(cookies), template.render("register") }), "text/html" }
end

local function profile_endpoint(cookies)
    local username = get_cookie(cookies, "ctf_user")
    local points = Database.get("scoreboard", username)
    local user_position = get_user_position(username)
    return { template.render("empty",
        { handle_menu(cookies),
            "<article><h2 style=\"text-align: center;\">" ..
            username ..
            "</h2></article><article><h3 style=\"text-align: center; margin-top: 1em;\">Points: " ..
            points ..
            "</h3></article><article><h3 style=\"text-align: center; margin-top: 1em;\">Position on the scoreboard: "
            ..
            user_position ..
            "</h3></article>" }),
        "text/html" }
end

local function logout_endpoint(cookies)
    Logger.log(string.format("User \"%s\" logged out", get_cookie(cookies, "ctf_user")))

    if enable_caching then
        web.invalidate_cache()
    end

    return { template.render("empty",
        { handle_menu(cookies, false),
            "<article><h2 style=\"text-align: center;\">Logged out</h2></article><script>document.cookie = \"ctf_user=; Max-age=0\"; document.cookie = \"ctf_auth_key=; Max-age=0\";history.pushState({}, null, document.URL.split(\"?\")[0]);</script>" }),
        "text/html" }
end

local function main()
    web.add("/", index_endpoint, true)
    web.add("/users", users_endpoint, true)
    web.add("/scoreboard", scoreboard_endpoint, true)
    web.add("/challenges", challenges_endpoint)
    web.add("/register", register_endpoint, true)
    web.add("/login", login_endpoint, true)
    web.add("/register_user/<>", register_user_endpoint)
    web.add("/login_user/<>", login_user_endpoint)
    web.add("/flag_submit/<>", flag_submit_endpoint)
    web.add("/profile", profile_endpoint)
    web.add("/logout", logout_endpoint, true)
    web.host_static_files("/static", "../static/")

    Logger.log("Server started")

    web.run("0.0.0.0", "8000", log_requests_to_stdout, enable_caching)
end

main()
