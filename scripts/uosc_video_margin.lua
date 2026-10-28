local mp = require("mp")

-- 使用 uosc 发布的归一化底部边距，让视频避开独立控制区。
-- 边距由控件实际高度计算，自动适配窗口尺寸、全屏和显示缩放。
mp.observe_property("user-data/osc/margins", "native", function(_, margins)
    local bottom = margins and margins.b or 0
    mp.set_property_number("video-margin-ratio-bottom", bottom)
end)
