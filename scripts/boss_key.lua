local mp = require("mp")

local function handle_escape()
    -- 全屏状态：只退出全屏
    if mp.get_property_native("fullscreen", false) then
        mp.set_property_native("fullscreen", false)
        return
    end

    -- 窗口状态：触发老板键
    mp.set_property_native("pause", true)
    mp.set_property_native("mute", true)
    mp.set_property_native("window-minimized", true)
end

-- 不直接绑定实体键，由 input.conf 调用
mp.add_key_binding(nil, "escape", handle_escape)
