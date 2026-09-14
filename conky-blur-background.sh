#!/usr/bin/env bash

set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cosmic_background_config="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicBackground/v1/all"
cache_dir="$config_dir/cache"
output_image="$cache_dir/blurred-background.png"
signature_file="$cache_dir/blurred-background.signature"

panel_width=340
panel_height=1100
gap_x=30
gap_y=40
blur_sigma=12
brightness=-8
corner_colour='#0c0d1c'

wallpaper=$(sed -n 's/^[[:space:]]*source: Path("\(.*\)"),$/\1/p' "$cosmic_background_config" | head -n 1)
[ -n "$wallpaper" ] && [ -r "$wallpaper" ] || exit 0

display_info=$(cosmic-randr list 2>/dev/null | sed -r 's/\x1B\[[0-9;]*[mK]//g')
resolution=$(printf '%s\n' "$display_info" | awk '/\(current\)/ {print $1; exit}')
scale_percent=$(printf '%s\n' "$display_info" | awk '/Scale:/ {gsub("%", "", $2); print $2; exit}')
[ -n "$resolution" ] && [ -n "$scale_percent" ] || exit 0

screen_width=${resolution%x*}
screen_height=${resolution#*x}
logical_width=$(awk -v value="$screen_width" -v scale="$scale_percent" 'BEGIN {printf "%d", value * 100 / scale + 0.5}')
logical_height=$(awk -v value="$screen_height" -v scale="$scale_percent" 'BEGIN {printf "%d", value * 100 / scale + 0.5}')
crop_x=$((logical_width - gap_x - panel_width))
crop_y=$gap_y
[ "$crop_x" -ge 0 ] && [ $((crop_y + panel_height)) -le "$logical_height" ] || exit 0

signature="$wallpaper|$logical_width|$logical_height|$crop_x|$crop_y|$panel_width|$panel_height|$blur_sigma|$brightness|$corner_colour"
if [ -f "$output_image" ] && [ -f "$signature_file" ] \
    && [ "$(<"$signature_file")" = "$signature" ] \
    && [ "$output_image" -nt "$wallpaper" ] \
    && [ "$output_image" -nt "$cosmic_background_config" ] \
    && [ "$(identify -format '%wx%h' "$output_image" 2>/dev/null)" = "${panel_width}x${panel_height}" ]; then
    exit 0
fi

mkdir -p "$cache_dir"
temporary_image=$(mktemp "$cache_dir/blurred-background.XXXXXX.png")
trap 'rm -f "$temporary_image"' EXIT

magick "$wallpaper" \
    -resize "${logical_width}x${logical_height}^" \
    -gravity center \
    -extent "${logical_width}x${logical_height}" \
    -gravity northwest \
    -crop "${panel_width}x${panel_height}+${crop_x}+${crop_y}" +repage \
    -blur "0x${blur_sigma}" \
    -brightness-contrast "${brightness}x0" \
    -background "$corner_colour" -alpha remove -alpha off \
    "$temporary_image"

mv "$temporary_image" "$output_image"
printf '%s\n' "$signature" > "$signature_file"

# Ricarica Lua quando il wallpaper è stato aggiornato mentre Conky è aperto.
touch "$config_dir/conky.conf"
