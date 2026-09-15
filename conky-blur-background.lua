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

    -- Disegna 1:1 senza stiramento: finestra misurata 348x1096, immagine ora 348x1096
    -- Nessun offset -1/+2, allineamento pixel-perfect con il wallpaper.
    cairo_place_image(image_path, context, 0, 0, conky_window.width, conky_window.height, 1.0)
    cairo_destroy(context)
end
