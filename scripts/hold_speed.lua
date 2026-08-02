local mp = require("mp")

-- 按住多长时间后算作长按，单位为秒
local hold_delay = 0.3

-- 长按右方向键时的播放速度
local right_speed = 3.5

-- 长按左方向键时的播放速度
local left_speed = 0.5

-- 短按方向键时跳转的秒数
local seek_seconds = 1

local states = {
    left = {
        timer = nil,
        holding = false,
        original_speed = nil
    },
    right = {
        timer = nil,
        holding = false,
        original_speed = nil
    }
}

local function flash_speed()
    mp.commandv("script-binding", "uosc/flash-speed")
end

local function flash_timeline()
    mp.commandv("script-binding", "uosc/flash-timeline")
end

local function create_handler(direction, target_speed, tap_seek)
    return function(event)
        local state = states[direction]

        -- 键盘按下
        if event.event == "down" then
            -- 防止异常情况下存在旧计时器
            if state.timer then
                state.timer:kill()
                state.timer = nil
            end

            state.holding = false

            -- 保存长按前的播放速度
            state.original_speed = mp.get_property_number("speed", 1.0)

            -- 超过指定时间后进入临时变速状态
            state.timer = mp.add_timeout(hold_delay, function()
                state.timer = nil
                state.holding = true

                mp.set_property_number("speed", target_speed)
                flash_speed()
            end)

            return
        end

        -- 系统按键自动重复事件不需要处理
        if event.event == "repeat" then
            return
        end

        -- 键盘松开，或者按键事件被系统取消
        if event.event == "up" or event.canceled then
            if state.timer then
                state.timer:kill()
                state.timer = nil
            end

            if state.holding then
                -- 长按结束：恢复长按前的速度
                mp.set_property_number("speed", state.original_speed or 1.0)

                flash_speed()
            else
                -- 未达到长按时间：作为普通短按跳转
                mp.commandv("seek", tap_seek, "relative+exact")
                flash_timeline()
            end

            state.holding = false
            state.original_speed = nil
            return
        end

        -- 某些输入设备无法提供按下和松开状态时，
        -- 退化为普通的短按跳转
        if event.event == "press" then
            mp.commandv("seek", tap_seek, "relative+exact")
            flash_timeline()
        end
    end
end

-- 这些绑定本身没有固定按键，
-- 具体按键由 input.conf 中的 script-binding 指定
mp.add_key_binding(nil, "left", create_handler("left", left_speed, -seek_seconds), {
    complex = true
})

mp.add_key_binding(nil, "right", create_handler("right", right_speed, seek_seconds), {
    complex = true
})
