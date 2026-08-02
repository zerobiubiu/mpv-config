local mp = require("mp")
local utils = require("mp.utils")

local function is_url(path)
    return path and path:match("^[%a][%w+.-]*://") ~= nil
end

local function normalize_path(path)
    if not path or path == "" then
        return nil
    end

    -- URL 保留原始大小写，避免破坏大小写敏感参数
    if is_url(path) then
        return path
    end

    path = path:gsub("\\", "/")

    -- 相对路径转换为基于 mpv 工作目录的路径
    local is_absolute = path:match("^%a:/") ~= nil or path:sub(1, 1) == "/"

    if not is_absolute then
        local working_directory = mp.get_property("working-directory", "")

        path = utils.join_path(working_directory, path):gsub("\\", "/")
    end

    -- Windows 本地文件路径不区分大小写
    if package.config:sub(1, 1) == "\\" then
        path = path:lower()
    end

    return path
end

local function remove_current_watch_history()
    local current_path = normalize_path(mp.get_property("path"))

    if not current_path then
        return true
    end

    local configured_path = mp.get_property("watch-history-path")

    if not configured_path or configured_path == "" then
        return true
    end

    local history_path = mp.command_native({"expand-path", configured_path})

    local history_file = io.open(history_path, "r")

    -- 没有历史文件时，无须处理
    if not history_file then
        return true
    end

    local retained_lines = {}
    local removed_count = 0

    for line in history_file:lines() do
        local entry = utils.parse_json(line)
        local entry_path = entry and normalize_path(entry.path)

        if entry_path == current_path then
            removed_count = removed_count + 1
        else
            -- 无法解析的行也保留，避免意外破坏文件
            retained_lines[#retained_lines + 1] = line
        end
    end

    history_file:close()

    if removed_count == 0 then
        return true
    end

    -- 当前视频是历史中唯一项目时，直接删除历史文件
    if #retained_lines == 0 then
        local ok, error_message = os.remove(history_path)

        if not ok then
            mp.msg.error("无法删除观看历史文件：" .. tostring(error_message))
            return false
        end

        return true
    end

    local temporary_path = history_path .. ".tmp"
    local temporary_file = io.open(temporary_path, "w")

    if not temporary_file then
        mp.msg.error("无法创建临时观看历史文件")
        return false
    end

    for _, line in ipairs(retained_lines) do
        temporary_file:write(line, "\n")
    end

    temporary_file:close()

    -- Windows 无法直接用 rename 覆盖已有文件
    local removed, remove_error = os.remove(history_path)

    if not removed then
        os.remove(temporary_path)
        mp.msg.error("无法替换观看历史文件：" .. tostring(remove_error))
        return false
    end

    local renamed, rename_error = os.rename(temporary_path, history_path)

    if not renamed then
        mp.msg.error("无法写回观看历史文件：" .. tostring(rename_error))
        return false
    end

    return true
end

local function quit_without_record()
    -- 防止退出过程中再次写入续播状态
    mp.set_property_native("save-position-on-quit", false)

    -- 防止退出过程中再次写入观看历史
    mp.set_property_native("save-watch-history", false)

    -- 删除当前视频已经存在的续播配置
    mp.commandv("delete-watch-later-config")

    -- 删除观看历史中当前视频的全部条目
    local history_removed = remove_current_watch_history()

    if not history_removed then
        mp.osd_message("观看历史删除失败，已取消退出", 3000)
        return
    end

    mp.commandv("quit")
end

mp.add_key_binding(nil, "quit", quit_without_record)
