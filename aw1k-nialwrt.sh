#!/bin/bash

script_file="$(basename "$0")"

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Distro and preset configuration
distro="immortalwrt"
repo="https://github.com/immortalwrt/immortalwrt.git"
preset_folder="AW1K-NIALWRT"
preset_repo="https://github.com/nialwrt/AW1K-NIALWRT.git"
deps=(ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential
    bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib
    g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev
    libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev
    libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano
    ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils
    python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs
    upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd)

choice=""
target_tag=""
opt=""

prompt() {
    echo -ne "$1"
    read -r REPLY
    eval "$2=\"\$REPLY\""
}

check_git() {
    command -v git &>/dev/null || {
        echo -e "${RED}${BOLD}ERROR:${NC} Git is required."
        exit 1
    }
}

main_menu() {
    clear
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${MAGENTA}${BOLD}  AW1K-NIALWRT Firmware Build  ${NC}"
    echo -e "${MAGENTA}  https://github.com/nialwrt          ${NC}"
    echo -e "${MAGENTA}  Telegram: @NIALVPN                  ${NC}"
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
}

update_feeds() {
    echo -e "${CYAN}Updating feeds...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "Edit feeds if needed, then press Enter: "
    read
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -e "${GREEN}Feeds updated.${NC}"
}

select_target() {
    echo -e "${CYAN}Select branch or tag:${NC}"
    git fetch --all --tags

    echo -e "Branches:"
    git branch -r | sed 's|origin/||' | grep -v 'HEAD' | sort -u
    
    echo -e "Tags:"
    git tag | sort -V

    while true; do
        prompt "Enter branch or tag: " target_tag
        if git checkout "$target_tag" 2>/dev/null; then
            echo -e "${GREEN}Checked out to $target_tag${NC}"
            break
        else
            echo -e "${RED}Invalid branch/tag: $target_tag${NC}"
        fi
    done
}

ensure_preset() {
    echo -e "${YELLOW}Cleaning old preset and config...${NC}"
    rm -rf ./files .config "$preset_folder"
    echo -e "Cloning preset from $preset_repo..."
    git clone "$preset_repo" "$preset_folder" || { echo -e "${RED}Failed to clone preset.${NC}"; exit 1; }
    echo -e "${GREEN}Preset cloned.${NC}"
}

apply_preset() {
    echo -e "Applying preset files and config..."
    cp -r "$preset_folder/files" ./
    cp "$preset_folder/config-upload" .config
}

run_menuconfig() {
    echo -e "Running menuconfig..."
    if make menuconfig; then
        echo -e "${GREEN}Configuration saved.${NC}"
    else
        echo -e "${RED}menuconfig failed.${NC}"
    fi
}

start_build() {
    echo -e "Building firmware with $(nproc) cores..."
    local start_time=$(date +%s)
    if make -j"$(nproc)"; then
        local duration=$(( $(date +%s) - start_time ))
        printf "${GREEN}Build completed in %02dh %02dm %02ds${NC}\n" $((duration/3600)) $(((duration%3600)/60)) $((duration%60))
        echo -e "Output: $(pwd)/bin/targets/"
    else
        echo -e "${RED}Build failed.${NC}"
    fi
}

cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -f "$script_file"
    rm -rf "$preset_folder"
}

build_menu() {
    echo -e "${CYAN}Cloning repo: $repo..."
    git clone "$repo" "$distro" || {
        echo -e "${RED}Git clone failed.${NC}"
        exit 1
    }

    cd "$distro" || exit 1
    update_feeds || exit 1
    select_target
    ensure_preset
    apply_preset
    make defconfig
    run_menuconfig
    start_build
    cleanup
}

rebuild_menu() {
    cd "$distro" || exit 1
    echo -e "${BLUE}Rebuild Options:${NC}"
    echo "1) Fresh Rebuild (clean)"
    echo "2) Rebuild with New Config"
    echo "3) Continue with Existing Config"

    while true; do
        prompt "${YELLOW}Choose option [1/2/3]: ${NC}" opt
        case "$opt" in
            1)
                make distclean
                update_feeds || return 1
                select_target
                ensure_preset
                apply_preset
                make defconfig
                run_menuconfig
                start_build
                cleanup
                break
                ;;
            2)
                select_target
                ensure_preset
                apply_preset
                make defconfig
                run_menuconfig
                start_build
                cleanup
                break
                ;;
            3)
                start_build
                cleanup
                break
                ;;
            *)
                echo -e "${RED}Invalid choice.${NC}" ;;
        esac
    done
}

check_git
main_menu

echo -e "${CYAN}Installing dependencies...${NC}"
sudo apt update -y && sudo apt full-upgrade -y
sudo apt install -y "${deps[@]}"

if [ -d "$distro/.git" ]; then
    echo -e "${BLUE}Found existing '$distro' directory.${NC}"
    rebuild_menu
else
    build_menu
fi
