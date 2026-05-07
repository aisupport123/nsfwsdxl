#!/bin/bash
# =============================================================
#  ComfyUI startup script for Vast.ai
#  Place this file at: /workspace/startup.sh
#  Make executable: chmod +x /workspace/startup.sh
# =============================================================

set -euo pipefail

# ---------- Paths --------------------------------------------
COMFY_DIR="/workspace/ComfyUI"
MODELS_DIR="$COMFY_DIR/models"
NODES_DIR="$COMFY_DIR/custom_nodes"

CHECKPOINTS_DIR="$MODELS_DIR/checkpoints"
LORAS_DIR="$MODELS_DIR/loras"
UPSCALE_DIR="$MODELS_DIR/upscale_models"
ULTRA1_DIR="$MODELS_DIR/ultralytics/bbox"
ULTRA2_DIR="$MODELS_DIR/ultralytics/segm"
SAMS_DIR="$MODELS_DIR/sams"

# ---------- Model lists --------------------------------------

CHECKPOINTS=(
    "https://huggingface.co/Kutches/XL/resolve/main/lustifySDXLNSFW_ggwpV7.safetensors"
)

LORAS=(
    "https://huggingface.co/tianweiy/DMD2/resolve/main/dmd2_sdxl_4step_lora.safetensors"
    "https://huggingface.co/minaiosu/silvermoong/resolve/main/748cmXL_NBVP1_lokr_V6311PZ.safetensors"
)

UPSCALE_MODELS=(
    "https://huggingface.co/notkenski/upscalers/resolve/main/1xSkinContrast-High-SuperUltraCompact.pth"
    "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/1x-ITF-SkinDiffDetail-Lite-v1.pth"
    "https://huggingface.co/shubhdotai/upscaler/resolve/9b9bfba2a119bee0d175427cadb05283a3ed2fb1/4xNMKDSuperscale_4xNMKDSuperscale.pt"
)

CUSTOM_NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch"
    "https://github.com/chrisgoringe/cg-use-everywhere"
    "https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
    "https://github.com/glifxyz/ComfyUI-GlifNodes"
    "https://github.com/ChenDarYen/ComfyUI-NAG"
    "https://github.com/cubiq/ComfyUI_essentials"
)

ULTRA1_MODELS=(
    "https://huggingface.co/xingren23/comfyflow-models/resolve/976de8449674de379b02c144d0b3cfa2b61482f2/ultralytics/bbox/hand_yolov8s.pt"
    "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt"
)

ULTRA2_MODELS=(
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt"
)

SAMS_MODELS=(
    "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/sams/sam_vit_b_01ec64.pth"
)

# ---------- Helpers ------------------------------------------

download_file() {
    local url="$1"
    local dest_dir="$2"
    local filename
    filename="$(basename "$url" | cut -d'?' -f1)"

    mkdir -p "$dest_dir"

    if [ -f "$dest_dir/$filename" ]; then
        echo "  [skip] $filename"
        return 0
    fi

    echo "  [dl]   $filename"
    wget -q --show-progress -O "$dest_dir/$filename" "$url" \
        || { echo "  [ERR]  Failed: $url"; rm -f "$dest_dir/$filename"; }
}

download_list() {
    local dest_dir="$1"; shift
    local urls=("$@")
    [ ${#urls[@]} -eq 0 ] && return 0
    for url in "${urls[@]}"; do
        download_file "$url" "$dest_dir"
    done
}

install_node() {
    local url="$1"
    local repo_name
    repo_name="$(basename "$url" .git)"
    local dest="$NODES_DIR/$repo_name"

    if [ -d "$dest/.git" ]; then
        echo "  [update] $repo_name"
        git -C "$dest" pull --quiet
    else
        echo "  [clone]  $repo_name"
        git clone --depth=1 --quiet "$url" "$dest"
    fi
}

# ---------- Wait for ComfyUI dir to exist -------------------

echo "==> Waiting for $COMFY_DIR..."
for i in {1..30}; do
    [ -d "$COMFY_DIR" ] && break
    sleep 2
done
[ -d "$COMFY_DIR" ] || { echo "[FATAL] $COMFY_DIR not found. Exiting."; exit 1; }

# ---------- Custom nodes ------------------------------------

echo ""
echo "==> Installing custom nodes..."
for url in "${CUSTOM_NODES[@]}"; do
    install_node "$url"
done

# Install Python deps for nodes that have requirements.txt
for req in "$NODES_DIR"/*/requirements.txt; do
    [ -f "$req" ] || continue
    echo "  [pip] $(dirname "$req" | xargs basename)"
    pip install -q -r "$req"
done

# ---------- Patch ComfyUI-NAG -------------------------------

NAG_FILE="$NODES_DIR/ComfyUI-NAG/chroma/layers.py"
if [ -f "$NAG_FILE" ]; then
    echo ""
    echo "==> Patching ComfyUI-NAG..."
    sed -i '5s/.*/from comfy.ldm.flux.layers import DoubleStreamBlock, SingleStreamBlock/' "$NAG_FILE"
    echo "  [ok] layers.py patched"
fi

# ---------- Download models ---------------------------------

echo ""
echo "==> Downloading checkpoints..."
download_list "$CHECKPOINTS_DIR" "${CHECKPOINTS[@]}"

echo ""
echo "==> Downloading LoRAs..."
download_list "$LORAS_DIR" "${LORAS[@]}"

echo ""
echo "==> Downloading upscale models..."
download_list "$UPSCALE_DIR" "${UPSCALE_MODELS[@]}"

echo ""
echo "==> Downloading ultralytics/bbox..."
download_list "$ULTRA1_DIR" "${ULTRA1_MODELS[@]}"

echo ""
echo "==> Downloading ultralytics/segm..."
download_list "$ULTRA2_DIR" "${ULTRA2_MODELS[@]}"

echo ""
echo "==> Downloading SAM models..."
download_list "$SAMS_DIR" "${SAMS_MODELS[@]}"

echo ""
echo "==> All models installed successfully!"
