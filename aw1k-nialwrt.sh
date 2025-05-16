#!/bin/bash

script_file="$(basename "$0")"

# Color codes
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m'
BOLD='\033[1m'

# Distro and preset configuration
distro="immortalwrt"
repo="https://github.com/immortalwrt/immortalwrt.git"
preset_folder="AW1K-NIALWRT"
preset_repo="https://github.com/nialwrt/AW1K-NIALWRT.git"

# Logging functions
log_info() { echo -e "${CYAN}>> ${NC}$1"; }
log_warning() { echo -e "${YELLOW}${BOLD}>> WARNING:${NC} ${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}${BOLD}>> ERROR:${NC} ${RED}${BOLD}$1${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}>> SUCCESS:${NC} ${GREEN}${BOLD}$1${NC}"; }
log_step() { echo -e "${BLUE}${BOLD}>> STEP:${NC} ${BLUE}${BOLD}$1${NC}"; }

prompt() {
    echo -ne "$1"
    read -r REPLY
    eval "$2=\"\$REPLY\""
}

check_git() {
    command -v git &>/dev/null || {
        log_error "Git is required."
        exit 1
    }
}

main_menu() {
    clear
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${MAGENTA}${BOLD}  AW1K-NIALWRT Firmware Build  ${NC}"
    echo -e "${MAGENTA}  github.com/nialwrt        ${NC}"
    echo -e "${MAGENTA}  Telegram: @NIALVPN                  ${NC}"
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
}

update_feeds() {
    log_step "Updating package lists (feeds)..."
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BLUE}Press Enter after editing custom feeds... ${NC}"; read
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    log_success "Package lists updated."
}

select_target() {
    log_step "Selecting target branch/tag..."
    echo -e "${YELLOW}Branches:${NC}"; git branch -a
    echo -e "${YELLOW}Tags:${NC}"; git tag | sort -V
    while true; do
        prompt "${BLUE}Enter branch/tag to checkout: ${NC}" target_tag
        git checkout "$target_tag" && { log_success "Checked out to: $target_tag"; break; }
        log_error "Invalid branch/tag."
    done
}

run_menuconfig() {
    log_step "Running menuconfig..."
    make menuconfig && log_success "Configuration saved." || log_error "Configuration failed."
}

show_output_location() {
    log_info "Firmware output: ${YELLOW}$(pwd)/bin/targets/${NC}"
}

start_build() {
    log_step "Building firmware..."
    local MAKE_J=$(nproc)
    log_info "Using make -j${MAKE_J}"

    while true; do
        local start_time=$(date +%s)
        make -j"${MAKE_J}" && {
            local duration=$(( $(date +%s) - start_time ))
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            local seconds=$((duration % 60))

            log_success "Build finished in ${hours}h ${minutes}m ${seconds}s."
            show_output_location
            break
        }

        log_error "Build failed. Debugging with verbose output..."
        make -j1 V=s
        echo -ne "${RED}Fix errors, then press Enter to retry... ${NC}"
        read

        make distclean
        update_feeds || return 1
        select_target
        run_menuconfig

        local retry_start=$(date +%s)
        make -j"${MAKE_J}" && {
            local retry_duration=$(( $(date +%s) - retry_start ))
            local rh=$((retry_duration / 3600))
            local rm=$(((retry_duration % 3600) / 60))
            local rs=$((retry_duration % 60))

            log_success "Rebuild (after fallback) finished in ${rh}h ${rm}m ${rs}s."
            show_output_location
        } || log_error "Build still failed after fallback."

        break
    done
}

build_menu() {
    log_step "Starting first-time build..."
    git clone "$repo" "$distro" || { log_error "Git clone failed."; exit 1; }
    git clone "$preset_repo" "$preset_folder" || { log_error "Git clone preset failed."; exit 1; }
    pushd "$distro" > /dev/null || exit 1
    update_feeds || exit 1
    select_target
    cp -r "../$preset_folder/files" ./
    cp "../$preset_folder/config-upload" .config
    make defconfig
    run_menuconfig
    start_build
    popd > /dev/null
}

rebuild_menu() {
    pushd "$distro" > /dev/null || exit 1
    echo -e "${BLUE}${BOLD}Rebuild Options:${NC}"
    echo "1) Fresh Rebuild (clean and reconfigure)"
    echo "2) Configure and Rebuild (new .config)"
    echo "3) Existing Rebuild (use current config)"

    while true; do
        prompt "${YELLOW}Select option [1/2/3]: ${NC}" opt
        case "$opt" in
            1)
                log_step "Performing fresh rebuild..."
                make distclean
                update_feeds || return 1
                select_target
                log_step "Copying preset files and configuration..."
                cp -r "../$preset_folder/files" ./
                cp "../$preset_folder/config-upload" .config
                make defconfig
                run_menuconfig
                start_build
                break
                ;;
            2)
                log_step "Configuring and rebuilding (new .config)..."
                log_step "deleting preset files and configuration..."
                rm -rf "./files"
                rm -f ".config"
                log_step "restore preset files and configuration..."
                cp -r "../$preset_folder/files" ./
                cp "../$preset_folder/config-upload" .config
                make defconfig
                run_menuconfig
                start_build
                break
                ;;
            3)
                log_step "Rebuilding with existing settings..."
                make -j"$(nproc)" && {
                    log_success "Rebuild success."
                    show_output_location
                    break
                } || {
                    log_error "Rebuild failed. Consider a fresh rebuild."
                }
                break
                ;;
            *) log_error "Invalid selection."; ;;
        esac
    done

    popd > /dev/null
}

cleanup() {
    log_step "Cleaning up directories and files..."
    rm -rf "$distro" && log_info "Directory '$distro' removed."
    rm -rf "$preset_folder" && log_info "Directory '$preset_folder' removed."
    rm -f "$script_file" && log_info "Script removed."
    log_success "Cleanup complete."
}

# Check for --clean argument
if [[ "$1" == "--clean" ]]; then
    cleanup
    exit 0
fi

check_git
main_menu

# Install dependencies
log_step "Installing dependencies required for ImmortalWrt..."
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
    bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
    g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
    libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
    libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
    ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
    python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
    upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd

if [ -d "$distro" ]; then
    echo -e "${BLUE}${BOLD}Directory '$distro' exists.${NC}"
    rebuild_menu
else
    build_menu
fi

log_info "Script done."
cleanup
log_success "Self-cleaned successfully."
