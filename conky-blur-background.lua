require("cairo")
require("cairo_imlib2_helper")

local image_path = os.getenv("HOME") .. "/.config/conky/cache/blurred-background.png"
local refresh_script = os.getenv("HOME") .. "/.config/conky/conky-blur-background.sh"
local next_refresh = 0

function conky_draw_blurred_background()
    if conky_window == nil then
        return
    end

    local now = os.time()
    if now >= next_refresh then
        next_refresh = now + 60
        os.execute(string.format("%q >/dev/null 2>&1 &", refresh_script))
    end

    local context = cairo_create(conky_surface())

    -- Un pixel di abbondanza evita una possibile fessura scura sul bordo alto
    -- dovuta all'allineamento tra la superficie Cairo e il PNG del blur.
    cairo_place_image(image_path, context, 0, -1, conky_window.width, conky_window.height + 2, 1.0)
    cairo_destroy(context)
end
