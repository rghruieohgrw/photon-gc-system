local SIGNATURE_BASE = "https://raw.githubusercontent.com/rghruieohgrw/photon-signatures/main/"
local signatures = {}

function load_signatures()
    local place_id = get_placeid()
    local url = SIGNATURE_BASE .. place_id .. ".json"
    
    http.get(url, function(body, status)
        if status == 200 then
            signatures = JSON_to_table(body)
            print("[GC] Loaded: " .. (signatures.game_name or "Unknown"))
        end
    end)
end

function scan_pattern(pattern)
    local start_addr = game_baseaddress()
    local bytes = {}
    for b in string.gmatch(pattern, "%S+") do
        table.insert(bytes, b == "?" and nil or tonumber(b, 16))
    end
    
    for addr = start_addr, start_addr + 0x5000000 do
        local match = true
        for i, expected in ipairs(bytes) do
            if expected then
                local current = read_memory(addr + i - 1, "MEMORY_BYTE")
                if current ~= expected then
                    match = false
                    break
                end
            end
        end
        if match then return addr end
    end
    return nil
end

function write_property(category, prop, value)
    if not signatures[category] or not signatures[category][prop] then
        return false
    end
    
    local sig = signatures[category][prop]
    local addr = scan_pattern(sig.pattern)
    
    if addr then
        write_memory(addr + sig.offset, sig.type, value)
        print("[GC] Set " .. prop .. " = " .. value)
        return true
    end
    return false
end

-- NEW: Simple string syntax
function setgc(prop, value)
    -- If first arg is table, use old behavior
    if type(prop) == "table" then
        for category, props in pairs(prop) do
            for p, v in pairs(props) do
                write_property(category, p, v)
            end
        end
    else
        -- Simple mode: auto-detect category
        local category = nil
        if signatures.weapon and signatures.weapon[prop] then
            category = "weapon"
        elseif signatures.humanoid and signatures.humanoid[prop] then
            category = "humanoid"
        else
            -- Search both categories
            for cat, props in pairs(signatures) do
                if props and props[prop] then
                    category = cat
                    break
                end
            end
        end
        
        if category then
            write_property(category, prop, value)
        else
            print("[GC] Property not found: " .. prop)
        end
    end
end

load_signatures()
