# Glove80 ZMK Config — local build & flash

uf2 := "glove80.uf2"
zmk_branch := "main"

# Default: show available recipes
default:
    @just --list

# Build firmware locally via Docker
build:
    @echo "==> Building Glove80 firmware (branch: {{ zmk_branch }})..."
    ./build.sh {{ zmk_branch }}
    @echo "==> Done. Firmware: {{ uf2 }}"
    @ls -lh {{ uf2 }}

# Flash firmware to both halves (builds first)
flash: build
    @just flash-only

# Flash without rebuilding (use if you already built)
flash-only:
    @test -f {{ uf2 }} || { echo "ERROR: {{ uf2 }} not found. Run 'just build' first." >&2; exit 1; }
    @just flash-left-only
    @echo ""
    @echo "==> Left half done. Now flash the right half."
    @just flash-right-only

# Flash left half only (no rebuild)
flash-left-only:
    @test -f {{ uf2 }} || { echo "ERROR: {{ uf2 }} not found. Run 'just build' first." >&2; exit 1; }
    @just _flash-side "GLV80LHBOOT" "LEFT" "ESC"

# Flash right half only (no rebuild)
flash-right-only:
    @test -f {{ uf2 }} || { echo "ERROR: {{ uf2 }} not found. Run 'just build' first." >&2; exit 1; }
    @just _flash-side "GLV80RHBOOT" "RIGHT" "'"

# Internal: flash one side by label
_flash-side label side boot-key:
    #!/usr/bin/env bash
    set -euo pipefail

    LABEL="{{ label }}"
    SIDE="{{ side }}"
    BOOT_KEY="{{ boot-key }}"
    FIRMWARE="{{ justfile_directory() }}/{{ uf2 }}"
    MOUNT="/run/media/$USER/${LABEL}"

    echo ""
    echo "==> Flashing ${SIDE} half (${LABEL})"
    echo "    Hold the ${SIDE,,} half in bootloader mode (MAGIC + ${BOOT_KEY} for 3s)"
    echo ""

    echo "==> Waiting for ${LABEL} to appear..."
    for i in $(seq 1 60); do
        if [ -d "$MOUNT" ]; then
            break
        fi
        sleep 1
    done

    if [ ! -d "$MOUNT" ]; then
        echo "ERROR: ${LABEL} not found after 60s." >&2
        echo "       Make sure the ${SIDE,,} half is in bootloader mode." >&2
        exit 1
    fi

    echo "==> Copying firmware..."
    cp "$FIRMWARE" "${MOUNT}/CURRENT.UF2"
    sync

    echo "==> ${SIDE} half flashed!"

# Parse the ZMK keymap into keymap-drawer's YAML layout format
parse:
    uvx --from keymap-drawer keymap \
    -c ./docs/kd-config.yaml \
    parse -z ./config/glove80.keymap > ./docs/kd-layout.yaml

# Render the parsed keymap layout to a PNG diagram
draw: parse
    uvx --from keymap-drawer keymap \
    -c ./docs/kd-config.yaml \
    draw ./docs/kd-layout.yaml \
    | rsvg-convert -o ./docs/glove80-draw.png
