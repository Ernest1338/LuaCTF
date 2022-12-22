Loaded_templates = {}

local function get_loaded_template(template_name)
    for _, template in pairs(Loaded_templates) do
        if template[1] == template_name then
            return template[2]
        end
    end
    return nil
end

local function load_template(template_name)
    local template = get_loaded_template(template_name)
    if template ~= nil then
        return template
    end
    local template_handle = assert(io.open("../templates/" .. template_name .. ".html", "r"))
    template = template_handle:read("*a")
    template_handle:close()
    table.insert(Loaded_templates, { template_name, template }) -- comment out to disable caching
    return template
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

local function split_template(template)
    local table_split = {}
    local tmp_str = ""
    for _, line in pairs(string_split(template, "\n")) do
        if line == "<!-- TEMPLATE -->" then
            table.insert(table_split, tmp_str)
            tmp_str = ""
        else
            tmp_str = tmp_str .. line .. "\n"
        end
    end
    table.insert(table_split, tmp_str)
    return table_split
end

Template = {}

function Template.render(template_name, data)
    local template = load_template(template_name)
    if data == nil then
        return template
    end
    local template_split = split_template(template)
    if type(data) ~= "table" then
        return template_split[1] .. data .. template_split[2]
    end
    local template_rendered = ""

    for i, chunk in pairs(template_split) do
        template_rendered = template_rendered .. chunk
        if i ~= #template_split then
            template_rendered = template_rendered .. data[i]
        end
    end

    return template_rendered
end

return Template
