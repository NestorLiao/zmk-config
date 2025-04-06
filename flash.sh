#!/usr/bin/env bash
# ===== CONFIGURATION =====
GITHUB_OWNER="NestorLiao"         # ← Change this
GITHUB_REPO="zmk-config"          # ← Change this
GITHUB_TOKEN="$(cat ~/.github_token)" # Make sure this file exists and is secure
ZIP_DEST="./zmk_build.zip"
UNZIP_DIR="./zmk_build"

LEFT_FW="corne_left-nice_nano_v2-zmk.uf2"
RIGHT_FW="corne_right-nice_nano_v2-zmk.uf2"

# ===== FUNCTIONS =====

download_latest_artifact() {
    echo "Fetching latest artifact..."

    # Step 1: Get latest successful workflow run ID
    run_id=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runs?per_page=1&status=success" \
        | jq -r '.workflow_runs[0].id')

    if [ "$run_id" == "null" ] || [ -z "$run_id" ]; then
        echo "❌ No successful workflow run found."
        exit 1
    fi

    echo "Found workflow run ID: $run_id"

    # Step 2: Get artifact download URL
    artifact_url=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runs/$run_id/artifacts" \
        | jq -r '.artifacts[0].archive_download_url')

    if [ "$artifact_url" == "null" ] || [ -z "$artifact_url" ]; then
        echo "❌ No artifacts found for run $run_id."
        exit 1
    fi

    echo "Downloading artifact zip..."
    curl -L -H "Authorization: token $GITHUB_TOKEN" \
        "$artifact_url" -o "$ZIP_DEST"

    echo "Unzipping..."
    rm -rf "$UNZIP_DIR"
    unzip -q "$ZIP_DEST" -d "$UNZIP_DIR"
}

flash_firmware() {
    local fw_path="$1"
    echo "Please reset the device into bootloader mode..."

    # Wait for mount
    while [ ! -d "/media/NICENANO" ]; do
        sleep 0.5
    done

    echo "NICENANO detected. Flashing $fw_path..."
    cp "$fw_path" /media/NICENANO/
    echo "Done."

    echo "Waiting for NICENANO to unmount..."
    while [ -d "/media/NICENANO" ]; do
        sleep 0.5
    done
}

# ===== MAIN =====

echo "== ZMK Auto Flash Script =="

# Step 1: Download and unzip artifact
download_latest_artifact

# Step 2: Flash left and right firmware
flash_firmware "$UNZIP_DIR/$LEFT_FW"
flash_firmware "$UNZIP_DIR/$RIGHT_FW"

echo "✅ All done. Firmware flashed."
