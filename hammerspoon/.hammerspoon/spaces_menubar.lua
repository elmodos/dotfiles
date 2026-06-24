-- Menubar widget: per-monitor Space indicators, active Space highlighted.
-- Replaces the "Spaceman" app. Uses hs.spaces (private macOS APIs).
--
-- The widget is rendered as an image (hs.canvas), not a styled-text title, so
-- the active Space's number can be "knocked out" of a solid pill: the digit is
-- drawn with compositeRule="destinationOut", which erases the pill in the shape
-- of the glyph, leaving a transparent cut-out the menu bar shows through.
-- The image is set as a template icon, so macOS recolors the opaque pixels to
-- the menu-bar text color (auto light/dark) while the holes stay transparent.

local M = {}

-- ---- Appearance (tweak to taste) -------------------------------------------
local SIZE = 10
local activeAttr = {
    font = { name = ".AppleSystemUIFontMonospaced", size = SIZE },
}
local inactiveAttr = {
    font = { name = ".AppleSystemUIFontMonospaced", size = SIZE },
}
local separatorAttr = {
    font = { name = ".AppleSystemUIFont", size = SIZE }
}
local SEPARATOR = "∙" -- between monitors
-- Gap between space numbers on one monitor, as a fraction of a normal space.
-- A space's width scales with font size, so this gives ~1/2, 1/3, 1/4 etc.
-- Set to 0 for no gap.
local GAP_SCALE = 0.5
local gapAttr = { font = { name = ".AppleSystemUIFont", size = SIZE * GAP_SCALE } }

-- Pill behind each space number. Its color is irrelevant (template mode
-- repaints it); only the alpha/padding/radius affect the look. The active pill
-- is opaque; inactive pills use the same color at a lower alpha.
local PILL_PAD_X = 2   -- horizontal padding around the digit, in points
local PILL_PAD_Y = 0   -- vertical padding above/below
local PILL_RADIUS = 2
local PILL_ALPHA_ACTIVE = 1.0
local PILL_ALPHA_INACTIVE = 0.2
-- ----------------------------------------------------------------------------

local menubar = hs.menubar.new()
M.menubar = menubar
M.watchers = {}

-- Screens left-to-right, so the widget order matches physical layout.
local function orderedScreens()
    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
    return screens
end

-- The status item draws one image on every screen, so render at the highest
-- backing scale present (e.g. 2 for Retina) to stay crisp; the regular monitor
-- just downsamples. Recomputed each render so plugging displays in/out adapts.
local function currentScale()
    local scale = 1
    for _, screen in ipairs(hs.screen.allScreens()) do
        local mode = screen:currentMode()
        local s = (mode and mode.scale) or 1
        if s > scale then scale = s end
    end
    return scale
end

-- Copy a styledtext attribute table with its size-bearing fields multiplied,
-- so text rendered into the supersampled canvas matches the geometry scale.
local function scaleAttr(attr, scale)
    local out = {}
    for k, v in pairs(attr) do out[k] = v end
    if attr.font then
        out.font = { name = attr.font.name, size = attr.font.size * scale }
    end
    if attr.baselineOffset then
        out.baselineOffset = attr.baselineOffset * scale
    end
    return out
end

-- Build a flat, left-to-right list of segments to render. Each segment is a
-- styled-text fragment plus whether it's the active space (gets a pill).
local function buildSegments(scale)
    local all = hs.spaces.allSpaces()        -- screenUUID -> { spaceID, ... }
    local active = hs.spaces.activeSpaces()   -- screenUUID -> active spaceID
    if not all then return nil end

    local sepA = scaleAttr(separatorAttr, scale)
    local gapA = scaleAttr(gapAttr, scale)
    local activeA = scaleAttr(activeAttr, scale)
    local inactiveA = scaleAttr(inactiveAttr, scale)

    local segs = {}
    local firstScreen = true

    for _, screen in ipairs(orderedScreens()) do
        local uuid = screen:getUUID()
        local spaces = uuid and all[uuid]
        if spaces and #spaces > 0 then
            if not firstScreen then
                segs[#segs + 1] = { styled = hs.styledtext.new(SEPARATOR, sepA) }
            end
            firstScreen = false

            local activeId = active and active[uuid]
            for i, spaceId in ipairs(spaces) do
                if i > 1 and GAP_SCALE > 0 then
                    segs[#segs + 1] = { styled = hs.styledtext.new(" ", gapA) }
                end
                local isActive = (spaceId == activeId)
                local attr = isActive and activeA or inactiveA
                segs[#segs + 1] = {
                    styled = hs.styledtext.new(tostring(i), attr),
                    active = isActive,
                    digit = true,
                }
            end
        end
    end

    return segs
end

local function render()
    if not menubar then return end

    local scale = currentScale()
    local segs = buildSegments(scale)
    if not segs then return end
    if #segs == 0 then
        menubar:setIcon(nil)
        menubar:setTitle("")
        return
    end

    -- Geometry is in supersampled pixels; scale the point-based knobs to match.
    local padX = PILL_PAD_X * scale
    local padY = PILL_PAD_Y * scale
    local radius = PILL_RADIUS * scale

    -- Measure each segment so we can lay them out and size the canvas.
    local maxH = 0
    for _, s in ipairs(segs) do
        s.size = hs.drawing.getTextDrawingSize(s.styled)
        if s.size.h > maxH then maxH = s.size.h end
    end

    local canvasH = maxH + padY * 2
    local totalW = 0
    for _, s in ipairs(segs) do
        totalW = totalW + s.size.w + (s.digit and padX * 2 or 0)
    end

    local c = hs.canvas.new({ x = 0, y = 0, w = totalW, h = canvasH })
    local x = 0
    for _, s in ipairs(segs) do
        local w = s.size.w
        local y = (canvasH - s.size.h) / 2  -- vertically center each fragment
        if s.digit then
            -- Pill (opaque when active, semi-transparent otherwise)...
            local alpha = s.active and PILL_ALPHA_ACTIVE or PILL_ALPHA_INACTIVE
            c:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = { white = 1.0, alpha = alpha },
                roundedRectRadii = { xRadius = radius, yRadius = radius },
                frame = { x = x, y = 0, w = w + padX * 2, h = canvasH },
            })
            -- ...with the digit punched out of it (transparent cut-out).
            c:appendElements({
                type = "text",
                text = s.styled,
                frame = { x = x + padX, y = y, w = w, h = s.size.h },
                compositeRule = "destinationOut",
            })
            x = x + w + padX * 2
        else
            c:appendElements({
                type = "text",
                text = s.styled,
                frame = { x = x, y = y, w = w, h = s.size.h },
            })
            x = x + w
        end
    end

    local img = c:imageFromCanvas()
    c:delete()

    -- Report the logical (point) size while keeping the supersampled pixels, so
    -- the image is Retina-crisp without doubling its on-screen size. setSize
    -- returns a resized copy rather than mutating, so reassign.
    img = img:setSize({ w = totalW / scale, h = canvasH / scale })

    menubar:setTitle("")
    menubar:setIcon(img, true) -- template: pill adapts to light/dark, holes stay clear
end
M.render = render

-- Watchers: active-space change + display config change.
M.watchers.spaces = hs.spaces.watcher.new(render):start()
M.watchers.screen = hs.screen.watcher.new(render):start()

-- The space watcher fires on switches but NOT on add/remove of spaces, so poll
-- slowly to keep the count in sync (rendering is cheap).
M.watchers.timer = hs.timer.doEvery(2, render)

-- Click refreshes immediately.
menubar:setClickCallback(render)

render()

return M
