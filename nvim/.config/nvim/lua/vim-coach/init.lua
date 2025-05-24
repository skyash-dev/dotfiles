-- ~/.config/nvim/lua/vim-coach/init.lua
-- Real-time Vim coaching plugin with sassy feedback

local M = {}

-- Configuration
local config = {
    enabled = true,
    popup_timeout = 3000, -- milliseconds
    max_history = 20,
    sass_level = "medium", -- low, medium, high, brutal
}

-- Keystroke history buffer
local keystroke_history = {}
local last_popup_time = 0
local popup_cooldown = 2000 -- Don't spam popups

-- Sassy messages by level
local messages = {
    low = {
        arrow_keys = "Consider using vim motions like 'w' and 'b' instead of arrow keys!",
        repeated_movement = "Try using count prefixes like '3j' instead of repeating keys!",
        movement_delete = "You can combine movements with deletions, like 'dw'!",
        visual_overuse = "Direct commands like 'dw' are faster than visual mode!",
    },
    medium = {
        arrow_keys = "Arrow keys? Really? Use 'w', 'b', 'e' like a vim wizard! ✨",
        repeated_movement = "Stop the key mashing! Use '4j' instead of 'jjjj' 🤦‍♂️",
        movement_delete = "Bruh! 'dw' deletes a word. No need to walk then chop! 🔥",
        visual_overuse = "Visual mode addiction detected! Try 'dw' directly 🚨",
    },
    high = {
        arrow_keys = "ARROW KEYS?! What is this, 2005? Use 'w'/'b' you peasant! 👑",
        repeated_movement = "Key spam detected! '5k' > 'kkkkk'. Level up! 🎮",
        movement_delete = "Moving then deleting? That's some amateur hour stuff! Use 'dw'! 💪",
        visual_overuse = "Stop dancing with visual mode! 'dw' gets straight to business! 💀",
    },
    brutal = {
        arrow_keys = "🤮 DISGUSTING! Arrow keys are for VS Code peasants! Use vim motions or uninstall vim!",
        repeated_movement = "🤡 CLOWN BEHAVIOR! Pressing 'j' 6 times? Use '6j' or go back to notepad!",
        movement_delete = "🔥 CRINGE ALERT! 'lllx' is for noobs! Real vimmers use 'dw'! Git gud!",
        visual_overuse = "🤮 VISUAL MODE ADDICTION! 'vwd' is weak sauce! Chad vimmers use 'dw'!",
    }
}

-- Inefficiency patterns
local patterns = {
    {
        name = "arrow_keys",
        detect = function(history)
            local recent = get_recent_keys(history, 3)
            for _, key in ipairs(recent) do
                if vim.tbl_contains({"<Right>", "<Left>", "<Up>", "<Down>"}, key) then
                    return true
                end
            end
            return false
        end,
        suggestion = function() return messages[config.sass_level].arrow_keys end
    },
    {
        name = "repeated_movement",
        detect = function(history)
            local recent = get_recent_keys(history, 5)
            local movement_keys = {"h", "j", "k", "l"}
            
            for _, move_key in ipairs(movement_keys) do
                local count = 0
                for i = #recent, math.max(1, #recent - 4), -1 do
                    if recent[i] == move_key then
                        count = count + 1
                    else
                        break
                    end
                end
                if count >= 3 then
                    return true, move_key, count
                end
            end
            return false
        end,
        suggestion = function() return messages[config.sass_level].repeated_movement end
    },
    {
        name = "movement_delete",
        detect = function(history)
            local recent = get_recent_keys(history, 6)
            if #recent < 4 then return false end
            
            -- Check for patterns like lllx, hhhx, etc.
            local movement_count = 0
            local movement_key = nil
            local delete_count = 0
            
            -- Count consecutive movements from the end backwards
            for i = #recent, 1, -1 do
                if recent[i] == "x" or recent[i] == "X" then
                    delete_count = delete_count + 1
                elseif vim.tbl_contains({"h", "l"}, recent[i]) then
                    if movement_key == nil then movement_key = recent[i] end
                    if recent[i] == movement_key then
                        movement_count = movement_count + 1
                    else
                        break
                    end
                else
                    break
                end
            end
            
            return movement_count >= 2 and delete_count >= 1
        end,
        suggestion = function() return messages[config.sass_level].movement_delete end
    },
    {
        name = "visual_overuse",
        detect = function(history)
            local recent = get_recent_keys(history, 5)
            if #recent < 3 then return false end
            
            -- Look for patterns like v + movement + d/y/c
            for i = 1, #recent - 2 do
                if recent[i] == "v" then
                    -- Check if there's a movement followed by an operation
                    local has_movement = false
                    local has_operation = false
                    
                    for j = i + 1, math.min(i + 4, #recent) do
                        if vim.tbl_contains({"h", "j", "k", "l", "w", "e", "b"}, recent[j]) then
                            has_movement = true
                        elseif vim.tbl_contains({"d", "y", "c"}, recent[j]) and has_movement then
                            has_operation = true
                            break
                        end
                    end
                    
                    if has_movement and has_operation then
                        return true
                    end
                end
            end
            return false
        end,
        suggestion = function() return messages[config.sass_level].visual_overuse end
    }
}

-- Helper functions
function get_recent_keys(history, count)
    local start_idx = math.max(1, #history - count + 1)
    local recent = {}
    for i = start_idx, #history do
        table.insert(recent, history[i])
    end
    return recent
end

function add_keystroke(key)
    table.insert(keystroke_history, key)
    if #keystroke_history > config.max_history then
        table.remove(keystroke_history, 1)
    end
end

function show_popup(message)
    local current_time = vim.fn.reltime()
    local time_ms = vim.fn.reltimestr(current_time) * 1000
    
    -- Cooldown check
    if time_ms - last_popup_time < popup_cooldown then
        return
    end
    
    last_popup_time = time_ms
    
    -- Create floating window
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.min(60, #message + 4)
    local height = 3
    
    local opts = {
        relative = 'cursor',
        width = width,
        height = height,
        col = 1,
        row = 1,
        anchor = 'NW',
        style = 'minimal',
        border = 'rounded',
    }
    
    local win = vim.api.nvim_open_win(buf, false, opts)
    
    -- Set popup content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "🧠 VIM COACH:",
        message,
        ""
    })
    
    -- Highlight
    vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:WarningMsg,FloatBorder:WarningMsg')
    
    -- Auto-close after timeout
    vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end, config.popup_timeout)
end

function check_inefficiencies()
    if not config.enabled then return end
    
    for _, pattern in ipairs(patterns) do
        local detected, extra_info = pattern.detect(keystroke_history)
        if detected then
            local message = pattern.suggestion()
            show_popup(message)
            break -- Only show one popup at a time
        end
    end
end

-- Key mapping interceptor
function setup_key_hooks()
    local keys_to_track = {
        "h", "j", "k", "l", "w", "e", "b", "x", "X", "d", "y", "c", "v",
        "<Right>", "<Left>", "<Up>", "<Down>", "<BS>"
    }
    
    for _, key in ipairs(keys_to_track) do
        vim.keymap.set('n', key, function()
            add_keystroke(key)
            
            -- Execute the original key function
            local escaped_key = key
            if key:match("^<.*>$") then
                escaped_key = key
            end
            
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(escaped_key, true, false, true), 'n', false)
            
            -- Check for inefficiencies after a short delay
            vim.defer_fn(check_inefficiencies, 50)
        end, { desc = "Vim Coach: Track " .. key })
    end
end

-- Plugin setup
function M.setup(user_config)
    config = vim.tbl_deep_extend("force", config, user_config or {})
    
    -- Commands
    vim.api.nvim_create_user_command('VimCoachEnable', function()
        config.enabled = true
        print("🧠 Vim Coach enabled! Prepare for some sass...")
    end, {})
    
    vim.api.nvim_create_user_command('VimCoachDisable', function()
        config.enabled = false
        print("😴 Vim Coach disabled. Back to your inefficient ways...")
    end, {})
    
    vim.api.nvim_create_user_command('VimCoachSass', function(opts)
        local level = opts.args
        if vim.tbl_contains({"low", "medium", "high", "brutal"}, level) then
            config.sass_level = level
            print("🔥 Sass level set to: " .. level)
        else
            print("Available sass levels: low, medium, high, brutal")
        end
    end, {
        nargs = 1,
        complete = function() return {"low", "medium", "high", "brutal"} end
    })
    
    vim.api.nvim_create_user_command('VimCoachStats', function()
        print("📊 Keystroke history: " .. #keystroke_history .. " keys")
        print("🎯 Recent keys: " .. table.concat(get_recent_keys(keystroke_history, 10), ", "))
    end, {})
    
    -- Initialize
    setup_key_hooks()
    print("🧠 Vim Coach loaded! Sass level: " .. config.sass_level)
end

return M