#!/usr/bin/env bash
set -Eeuo pipefail

source /venv/main/bin/activate

WORKSPACE="${WORKSPACE:-/workspace}"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"
STATE_DIR="${WORKSPACE}/.startup_state"
mkdir -p "$STATE_DIR"

UPDATE_COMFYUI="${UPDATE_COMFYUI:-0}"
UPDATE_NODES="${UPDATE_NODES:-0}"
INSTALL_NODE_REQS="${INSTALL_NODE_REQS:-1}"
INSTALL_BASE_REQS="${INSTALL_BASE_REQS:-1}"
PIP_DISABLE_CACHE="${PIP_DISABLE_CACHE:-0}"

PIP_ARGS=()
if [[ "$PIP_DISABLE_CACHE" == "1" ]]; then
  PIP_ARGS+=(--no-cache-dir)
fi

APT_PACKAGES=()
PIP_PACKAGES=()

NODES=(
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

log() { echo "[startup] $*"; }

repo_dir_name() {
  local name; name="$(basename "$1")"; printf '%s\n' "${name%.git}"
}

provisioning_get_apt_packages() {
  [[ ${#APT_PACKAGES[@]} -eq 0 ]] && return
  log "Installing apt packages..."
  sudo apt-get update && sudo apt-get install -y "${APT_PACKAGES[@]}"
}

provisioning_clone_comfyui() {
  if [[ ! -d "$COMFYUI_DIR/.git" ]]; then
    log "Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
  elif [[ "$UPDATE_COMFYUI" == "1" ]]; then
    log "Updating ComfyUI..."; git -C "$COMFYUI_DIR" pull --ff-only || true
  else
    log "ComfyUI already exists, skip update"
  fi
}

provisioning_install_base_reqs() {
  [[ "$INSTALL_BASE_REQS" == "1" ]] || return
  local req_file="$COMFYUI_DIR/requirements.txt"
  local stamp_file="$STATE_DIR/comfyui_requirements.sha256"
  [[ -f "$req_file" ]] || return
  local current_hash; current_hash="$(sha256sum "$req_file" | awk '{print $1}')"
  local saved_hash=""; [[ -f "$stamp_file" ]] && saved_hash="$(cat "$stamp_file")"
  if [[ "$current_hash" == "$saved_hash" ]]; then log "Base requirements unchanged, skip"; return; fi
  log "Installing base requirements..."
  pip install "${PIP_ARGS[@]}" -r "$req_file"
  printf '%s\n' "$current_hash" > "$stamp_file"
}

provisioning_get_pip_packages() {
  [[ ${#PIP_PACKAGES[@]} -eq 0 ]] && return
  log "Installing extra pip packages..."
  pip install "${PIP_ARGS[@]}" "${PIP_PACKAGES[@]}"
}

provisioning_get_nodes() {
  mkdir -p "$CUSTOM_NODES_DIR"
  local -A seen=()
  local repo dir path requirements current_commit stamp_file stamped_commit

  for repo in "${NODES[@]}"; do
    [[ -n "${seen[$repo]+x}" ]] && continue
    seen[$repo]=1
    dir="$(repo_dir_name "$repo")"
    path="$CUSTOM_NODES_DIR/$dir"

    if [[ ! -d "$path/.git" ]]; then
      log "Cloning node: $dir"
      git clone --recursive "$repo" "$path" || { log "Clone failed: $repo"; continue; }
    elif [[ "$UPDATE_NODES" == "1" ]]; then
      log "Updating node: $dir"
      (cd "$path" && git pull --ff-only --recurse-submodules || {
        git fetch --all --tags
        branch="$(git rev-parse --abbrev-ref HEAD)"
        git reset --hard "origin/$branch"
        git submodule update --init --recursive
      })
    else
      log "Node exists, skip: $dir"
    fi

    [[ "$INSTALL_NODE_REQS" == "1" ]] || continue
    requirements="$path/requirements.txt"
    [[ -f "$requirements" ]] || continue
    current_commit="$(git -C "$path" rev-parse HEAD 2>/dev/null || echo no-git)"
    stamp_file="$path/.requirements_installed_for_commit"
    stamped_commit=""; [[ -f "$stamp_file" ]] && stamped_commit="$(cat "$stamp_file")"
    if [[ "$current_commit" == "$stamped_commit" ]]; then
      log "Deps already installed for $dir @ $current_commit"; continue
    fi
    log "Installing deps for $dir..."
    if pip install "${PIP_ARGS[@]}" -r "$requirements"; then
      printf '%s\n' "$current_commit" > "$stamp_file"
    else
      log "pip requirements failed for $dir"
    fi
  done
}

provisioning_get_files() {
  [[ $# -lt 2 ]] && return
  local dir="$1"; shift
  local files=("$@")
  local url filename tmp_path final_path
  mkdir -p "$dir"
  log "Checking ${#files[@]} file(s) in $dir"
  for url in "${files[@]}"; do
    filename="$(basename "${url%%\?*}")"
    final_path="$dir/$filename"
    tmp_path="$final_path.part"
    if [[ -f "$final_path" && -s "$final_path" ]]; then log "Exists: $filename"; continue; fi
    log "Downloading: $filename"
    if [[ -n "${HF_TOKEN:-}" && "$url" =~ huggingface\.co ]]; then
      wget --header="Authorization: Bearer $HF_TOKEN" \
        -O "$tmp_path" --content-disposition --show-progress -e dotbytes=4M "$url"
    else
      wget -O "$tmp_path" --content-disposition --show-progress -e dotbytes=4M "$url"
    fi
    if [[ ! -f "$tmp_path" || ! -s "$tmp_path" ]]; then
      log "Download failed: $filename"; rm -f "$tmp_path"; exit 1
    fi
    mv "$tmp_path" "$final_path"
  done
}

provisioning_patch_nag() {
  local nag_file="$CUSTOM_NODES_DIR/ComfyUI-NAG/chroma/layers.py"
  if [[ -f "$nag_file" ]]; then
    log "Patching ComfyUI-NAG layers.py..."
    sed -i '5s/.*/from comfy.ldm.flux.layers import DoubleStreamBlock, SingleStreamBlock/' "$nag_file"
    log "Patch applied"
  fi
}

provisioning_start() {
  echo
  echo "##############################################"
  echo "#        LUSTIFY SDXL startup                #"
  echo "##############################################"
  echo

  provisioning_get_apt_packages
  provisioning_clone_comfyui
  provisioning_install_base_reqs
  provisioning_get_nodes
  provisioning_get_pip_packages
  provisioning_patch_nag

  # Модели качаем параллельно
  log "Starting parallel model downloads..."

  provisioning_get_files "$COMFYUI_DIR/models/checkpoints"      "${CHECKPOINTS[@]}"      &
  provisioning_get_files "$COMFYUI_DIR/models/loras"            "${LORAS[@]}"            &
  provisioning_get_files "$COMFYUI_DIR/models/upscale_models"   "${UPSCALE_MODELS[@]}"   &
  provisioning_get_files "$COMFYUI_DIR/models/ultralytics/bbox" "${ULTRA1_MODELS[@]}"    &
  provisioning_get_files "$COMFYUI_DIR/models/ultralytics/segm" "${ULTRA2_MODELS[@]}"    &
  provisioning_get_files "$COMFYUI_DIR/models/sams"             "${SAMS_MODELS[@]}"      &

  wait
  log "All models downloaded!"

  echo
  log "Provisioning complete. Starting ComfyUI..."
  echo
}

if [[ ! -f /.noprovisioning ]]; then
  provisioning_start
fi

cd "$COMFYUI_DIR"
exec python main.py --listen 0.0.0.0 --port 8188
