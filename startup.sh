#!/bin/bash
set -euo pipefail

# ============================================================
#  ComfyUI startup & model installation script
# ============================================================

# ---------- Directory paths ---------------------------------
MODELS_DIR="/root/ComfyUI/models"
NODES_DIR="/root/ComfyUI/custom_nodes"

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

# ---------- Model lists -------------------------------------

CHECKPOINTS=(
    "https://huggingface.co/Kutches/XL/resolve/main/lustifySDXLNSFW_ggwpV7.safetensors"
)

DIFFUSION_MODELS=()
UNET=()
VAE=()
CLIP=()
TEXT_ENCODERS=()
CLIP_VISION=()

LORAS=(
    "https://huggingface.co/tianweiy/DMD2/resolve/main/dmd2_sdxl_4step_lora.safetensors"
    "https://huggingface.co/minaiosu/silvermoong/resolve/main/748cmXL_NBVP1_lokr_V6311PZ.safetensors"
)

EMBEDDINGS=()
CONTROLNET=()
HYPERNETWORKS=()
STYLE_MODELS=()
GLIGEN=()
PHOTOMAKER=()
CLASSIFIERS=()

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

ONNX_MODELS=()

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

PATCHES_MODELS=()
SAM2_MODELS=()
RIFE_MODELS=()
SEEDVR2_MODELS=()

# ---------- Helper functions --------------------------------

# Download a file into a target directory (skip if already exists)
download_file() {
    local url="$1"
    local dest_dir="$2"
    local filename
    filename="$(basename "$url" | cut -d'?' -f1)"

    mkdir -p "$dest_dir"

    if [ -f "$dest_dir/$filename" ]; then
        echo "  [skip] $filename already exists"
        return 0
    fi

    echo "  [dl]   $filename"
    wget -q --show-progress \
         --content-disposition \
         -O "$dest_dir/$filename" \
         "$url" \
    || { echo "  [err]  Failed to download $url"; return 1; }
}

# Download a list of URLs into a directory
download_list() {
    local dest_dir="$1"
    shift
    local urls=("$@")
    [ ${#urls[@]} -eq 0 ] && return 0
    mkdir -p "$dest_dir"
    for url in "${urls[@]}"; do
        download_file "$url" "$dest_dir"
    done
}

# Clone or update a git repo into NODES_DIR
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

# ---------- Create all directories --------------------------

echo "==> Creating model directories..."
mkdir -p \
    "$CHECKPOINTS_DIR" "$DIFFUSION_DIR" "$UNET_DIR" "$VAE_DIR" \
    "$CLIP_DIR" "$TEXT_ENCODERS_DIR" "$CLIP_VISION_DIR" \
    "$LORAS_DIR" "$EMBEDDINGS_DIR" "$CONTROLNET_DIR" \
    "$HYPERNETWORKS_DIR" "$STYLE_MODELS_DIR" "$GLIGEN_DIR" \
    "$PHOTOMAKER_DIR" "$CLASSIFIERS_DIR" "$UPSCALE_DIR" \
    "$ONNX_DIR" "$ULTRA1_DIR" "$ULTRA2_DIR" \
    "$SAMS_DIR" "$SAM2_DIR" "$PATCHES_DIR" \
    "$RIFE_DIR" "$SEEDVR2_DIR" "$NODES_DIR"

# ---------- Install custom nodes ----------------------------

echo ""
echo "==> Installing custom nodes..."
for node_url in "${CUSTOM_NODES[@]}"; do
    install_node "$node_url"
done

# ---------- Apply patches -----------------------------------

echo ""
echo "==> Applying patches..."

NAG_FILE="$NODES_DIR/ComfyUI-NAG/chroma/layers.py"
if [ -f "$NAG_FILE" ]; then
    echo "  [patch] ComfyUI-NAG layers.py line 5"
    sed -i '5s/.*/from comfy.ldm.flux.layers import DoubleStreamBlock, SingleStreamBlock/' "$NAG_FILE"
else
    echo "  [skip]  $NAG_FILE not found (will retry after node install)"
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
echo "==> Downloading ultralytics bbox models..."
download_list "$ULTRA1_DIR" "${ULTRA1_MODELS[@]}"

echo ""
echo "==> Downloading ultralytics segm models..."
download_list "$ULTRA2_DIR" "${ULTRA2_MODELS[@]}"

echo ""
echo "==> Downloading SAM models..."
download_list "$SAMS_DIR" "${SAMS_MODELS[@]}"

# Optional / currently empty groups – uncomment if you add URLs later
# download_list "$DIFFUSION_DIR"    "${DIFFUSION_MODELS[@]}"
# download_list "$UNET_DIR"         "${UNET[@]}"
# download_list "$VAE_DIR"          "${VAE[@]}"
# download_list "$CLIP_DIR"         "${CLIP[@]}"
# download_list "$TEXT_ENCODERS_DIR" "${TEXT_ENCODERS[@]}"
# download_list "$CLIP_VISION_DIR"  "${CLIP_VISION[@]}"
# download_list "$EMBEDDINGS_DIR"   "${EMBEDDINGS[@]}"
# download_list "$CONTROLNET_DIR"   "${CONTROLNET[@]}"
# download_list "$HYPERNETWORKS_DIR" "${HYPERNETWORKS[@]}"
# download_list "$STYLE_MODELS_DIR" "${STYLE_MODELS[@]}"
# download_list "$GLIGEN_DIR"       "${GLIGEN[@]}"
# download_list "$PHOTOMAKER_DIR"   "${PHOTOMAKER[@]}"
# download_list "$CLASSIFIERS_DIR"  "${CLASSIFIERS[@]}"
# download_list "$ONNX_DIR"         "${ONNX_MODELS[@]}"
# download_list "$SAM2_DIR"         "${SAM2_MODELS[@]}"
# download_list "$PATCHES_DIR"      "${PATCHES_MODELS[@]}"
# download_list "$RIFE_DIR"         "${RIFE_MODELS[@]}"
# download_list "$SEEDVR2_DIR"      "${SEEDVR2_MODELS[@]}"

# ---------- Done --------------------------------------------

echo ""
echo "==> All done. Starting ComfyUI..."
cd /root/ComfyUI
python main.py --listen 0.0.0.0
