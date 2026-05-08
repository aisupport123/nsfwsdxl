#!/usr/bin/env bash
set -euo pipefail

# =============================================================
#  LUSTIFY SDXL — startup script for Vast.ai
#  Путь установки: /workspace/startup.sh
# =============================================================

### НАСТРОЙКИ — меняй здесь ###
DOWNLOAD_LUSTIFY="${DOWNLOAD_LUSTIFY:-true}"
################################

WORKSPACE="${WORKSPACE:-/workspace}"
COMFYUI_DIR="$WORKSPACE/ComfyUI"
MODELS_DIR="$COMFYUI_DIR/models"
NODES_DIR="$COMFYUI_DIR/custom_nodes"

CHECKPOINTS_DIR="$MODELS_DIR/checkpoints"
DIFFUSION_DIR="$MODELS_DIR/diffusion_models"
UNET_DIR="$MODELS_DIR/unet"
VAE_DIR="$MODELS_DIR/vae"
CLIP_DIR="$MODELS_DIR/clip"
TEXT_ENCODERS_DIR="$MODELS_DIR/text_encoders"
CLIP_VISION_DIR="$MODELS_DIR/clip_vision"
LORAS_DIR="$MODELS_DIR/loras"
EMBEDDINGS_DIR="$MODELS_DIR/embeddings"
CONTROLNET_DIR="$MODELS_DIR/controlnet"
HYPERNETWORKS_DIR="$MODELS_DIR/hypernetworks"
STYLE_MODELS_DIR="$MODELS_DIR/style_models"
GLIGEN_DIR="$MODELS_DIR/gligen"
PHOTOMAKER_DIR="$MODELS_DIR/photomaker"
CLASSIFIERS_DIR="$MODELS_DIR/classifiers"
UPSCALE_DIR="$MODELS_DIR/upscale_models"
ONNX_DIR="$MODELS_DIR/detection"
ULTRA1_DIR="$MODELS_DIR/ultralytics/bbox"
ULTRA2_DIR="$MODELS_DIR/ultralytics/segm"
SAMS_DIR="$MODELS_DIR/sams"
SAM2_DIR="$MODELS_DIR/sam2"
PATCHES_DIR="$MODELS_DIR/model_patches"
RIFE_DIR="$MODELS_DIR/rife"
SEEDVR2_DIR="$MODELS_DIR/seedvr2"

# --- Пустые массивы ---
CHECKPOINTS=()
DIFFUSION_MODELS=()
UNET=()
VAE=()
CLIP=()
TEXT_ENCODERS=()
CLIP_VISION=()
LORAS=()
EMBEDDINGS=()
CONTROLNET=()
HYPERNETWORKS=()
STYLE_MODELS=()
GLIGEN=()
PHOTOMAKER=()
CLASSIFIERS=()
UPSCALE_MODELS=()
CUSTOM_NODES=()
ONNX_MODELS=()
ULTRA1_MODELS=()
ULTRA2_MODELS=()
SAMS_MODELS=()
SAM2_MODELS=()
PATCHES_MODELS=()
RIFE_MODELS=()
SEEDVR2_MODELS=()

# --- Модели и ноды ---
if [ "${DOWNLOAD_LUSTIFY,,}" = "true" ]; then

CHECKPOINTS+=(
    "https://civitai.red/api/download/models/2155386?token=5fb92c84c0160ed0c0f066ad329fccc5"
)

LORAS+=(
    "https://huggingface.co/tianweiy/DMD2/resolve/main/dmd2_sdxl_4step_lora.safetensors"
    "https://huggingface.co/minaiosu/silvermoong/resolve/main/748cmXL_NBVP1_lokr_V6311PZ.safetensors"
)

UPSCALE_MODELS+=(
    "https://huggingface.co/notkenski/upscalers/resolve/main/1xSkinContrast-High-SuperUltraCompact.pth"
    "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/1x-ITF-SkinDiffDetail-Lite-v1.pth"
    "https://huggingface.co/shubhdotai/upscaler/resolve/9b9bfba2a119bee0d175427cadb05283a3ed2fb1/4xNMKDSuperscale_4xNMKDSuperscale.pt"
)

CUSTOM_NODES+=(
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

ULTRA1_MODELS+=(
    "https://huggingface.co/xingren23/comfyflow-models/resolve/976de8449674de379b02c144d0b3cfa2b61482f2/ultralytics/bbox/hand_yolov8s.pt"
    "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/detection/bbox/face_yolov8m.pt"
)

ULTRA2_MODELS+=(
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt"
)

SAMS_MODELS+=(
    "https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/sams/sam_vit_b_01ec64.pth"
)

fi

# --- Хелперы ---

log() { echo "[startup] $*"; }

download_file() {
    local url="$1"
    local dir="$2"
    local filename
    filename="$(basename "${url%%\?*}")"
    local final="$dir/$filename"
    local tmp="$final.part"

    mkdir -p "$dir"

    if [ -f "$final" ] && [ -s "$final" ]; then
        log "Exists: $filename"
        return 0
    fi

    log "Downloading: $filename"
    wget -O "$tmp" --content-disposition --show-progress -e dotbytes=4M "$url"

    if [ ! -f "$tmp" ] || [ ! -s "$tmp" ]; then
        log "ERROR: Download failed: $filename"
        rm -f "$tmp"
        return 1
    fi

    mv "$tmp" "$final"
}

download_list() {
    local dir="$1"; shift
    local urls=("$@")
    [ ${#urls[@]} -eq 0 ] && return 0
    for url in "${urls[@]}"; do
        download_file "$url" "$dir"
    done
}

install_node() {
    local url="$1"
    local name
    name="$(basename "$url" .git)"
    local path="$NODES_DIR/$name"

    if [ -d "$path/.git" ]; then
        log "Node exists: $name"
    else
        log "Cloning node: $name"
        git clone --depth=1 --recursive "$url" "$path" || { log "Clone failed: $url"; return 1; }
    fi

    if [ -f "$path/requirements.txt" ]; then
        log "Installing deps: $name"
        pip install -q -r "$path/requirements.txt" || log "pip failed for $name"
    fi
}

# --- Создать папки ---
mkdir -p \
    "$CHECKPOINTS_DIR" "$DIFFUSION_DIR" "$UNET_DIR" "$VAE_DIR" \
    "$CLIP_DIR" "$TEXT_ENCODERS_DIR" "$CLIP_VISION_DIR" \
    "$LORAS_DIR" "$EMBEDDINGS_DIR" "$CONTROLNET_DIR" \
    "$HYPERNETWORKS_DIR" "$STYLE_MODELS_DIR" "$GLIGEN_DIR" \
    "$PHOTOMAKER_DIR" "$CLASSIFIERS_DIR" "$UPSCALE_DIR" \
    "$ONNX_DIR" "$ULTRA1_DIR" "$ULTRA2_DIR" \
    "$SAMS_DIR" "$SAM2_DIR" "$PATCHES_DIR" \
    "$RIFE_DIR" "$SEEDVR2_DIR" "$NODES_DIR"

echo
echo "##############################################"
echo "#        LUSTIFY SDXL startup                #"
echo "##############################################"
echo

# --- Ноды ---
log "Installing custom nodes..."
for url in "${CUSTOM_NODES[@]}"; do
    install_node "$url"
done

# --- Патч NAG ---
NAG_FILE="$NODES_DIR/ComfyUI-NAG/chroma/layers.py"
if [ -f "$NAG_FILE" ]; then
    log "Patching ComfyUI-NAG..."
    sed -i '5s/.*/from comfy.ldm.flux.layers import DoubleStreamBlock, SingleStreamBlock/' "$NAG_FILE"
    log "Patch applied"
fi

# --- Модели (параллельно) ---
log "Downloading models..."

download_list "$CHECKPOINTS_DIR"  "${CHECKPOINTS[@]}"    &
download_list "$LORAS_DIR"        "${LORAS[@]}"          &
download_list "$UPSCALE_DIR"      "${UPSCALE_MODELS[@]}" &
download_list "$ULTRA1_DIR"       "${ULTRA1_MODELS[@]}"  &
download_list "$ULTRA2_DIR"       "${ULTRA2_MODELS[@]}"  &
download_list "$SAMS_DIR"         "${SAMS_MODELS[@]}"    &

wait
log "All done!"

echo
log "Starting ComfyUI..."
cd "$COMFYUI_DIR"
exec python main.py --listen 0.0.0.0 --port 8188
