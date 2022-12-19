Log = {}

function Log.new(file_name, enabled)
    local log_obj = {}

    function log_obj.log(message)
        if enabled == false then return end
        local file_handle = assert(io.open(file_name, "a"))
        file_handle:write("[" .. os.date("%d/%m/%Y %H:%M:%S") .. "] " .. message .. "\n")
        file_handle:close()
    end

    return log_obj
end

return Log
