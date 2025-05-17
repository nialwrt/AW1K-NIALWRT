#!/bin/bash

script_path="$(realpath "$0")"

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
        echo -e "${RED}${BOLD}ERROR:${NC} GIT IS REQUIRED."
        exit 1
    }
}

main_menu() {
    clear
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${MAGENTA}${BOLD}  AW1K-NIALWRT FIRMWARE BUILD         ${NC}"
    echo -e "${MAGENTA}${BOLD}  HTTPS://GITHUB.COM/NIALWRT          ${NC}"
    echo -e "${MAGENTA}${BOLD}  TELEGRAM: @NIALVPN                  ${NC}"
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
}

update_feeds() {
    echo -e "${CYAN}${BOLD}UPDATING FEEDS...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BLUE}${BOLD}EDIT FEEDS IF NEEDED, THEN PRESS ENTER: ${NC}"
    read
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -e "${GREEN}${BOLD}FEEDS UPDATED.${NC}"
}

select_target() {
    echo -e "${CYAN}${BOLD}SELECT BRANCH OR TAG:${NC}"
    git fetch --all --tags

    echo -e "${BLUE}${BOLD}BRANCHES:${NC}"
    git branch -r | sed 's|origin/||' | grep -v 'HEAD' | sort -u

    echo -e "${BLUE}${BOLD}TAGS:${NC}"
    git tag | sort -V

    while true; do
        prompt "${BLUE}${BOLD}ENTER BRANCH OR TAG: ${NC}" target_tag
        if git checkout "$target_tag" 2>/dev/null; then
            echo -e "${GREEN}${BOLD}CHECKED OUT TO $target_tag${NC}"
            break
        else
            echo -e "${RED}${BOLD}INVALID BRANCH/TAG: $target_tag${NC}"
        fi
    done
}

ensure_preset() {
    echo -e "${YELLOW}${BOLD}CLEANING OLD PRESET AND CONFIG...${NC}"
    rm -rf ./files .config "$preset_folder"
    echo -e "${BLUE}${BOLD}CLONING PRESET FROM $preset_repo...${NC}"
    git clone "$preset_repo" "$preset_folder" || { echo -e "${RED}${BOLD}FAILED TO CLONE PRESET.${NC}"; exit 1; }
    echo -e "${GREEN}${BOLD}PRESET CLONED.${NC}"
}

apply_preset() {
    echo -e "${BLUE}${BOLD}APPLYING PRESET FILES AND CONFIG...${NC}"
    cp -r "$preset_folder/files" ./
    cp "$preset_folder/config-upload" .config
}

run_menuconfig() {
    echo -e "${BLUE}${BOLD}RUNNING MENUCONFIG...${NC}"
    if make menuconfig; then
        echo -e "${GREEN}${BOLD}CONFIGURATION SAVED.${NC}"
    else
        echo -e "${RED}${BOLD}MENUCONFIG FAILED.${NC}"
    fi
}

start_build() {
    echo -e "${BLUE}${BOLD}BUILDING FIRMWARE WITH $(nproc) CORES...${NC}"
    local start_time=$(date +%s)
    if make -j"$(nproc)"; then
        local duration=$(( $(date +%s) - start_time ))
        printf "${GREEN}${BOLD}BUILD COMPLETED IN %02dh %02dm %02ds${NC}\n" $((duration/3600)) $(((duration%3600)/60)) $((duration%60))
        echo -e "${BLUE}${BOLD}OUTPUT: $(pwd)/bin/targets/${NC}"
    else
        echo -e "${RED}${BOLD}BUILD FAILED.${NC}"
    fi
}

cleanup() {
    echo -e "${YELLOW}${BOLD}CLEANING UP...${NC}"
    rm -f "$script_path"
    rm -rf "$preset_folder"
}

build_menu() {
    echo -e "${CYAN}${BOLD}CLONING REPO: $repo...${NC}"
    git clone "$repo" "$distro" || {
        echo -e "${RED}${BOLD}GIT CLONE FAILED.${NC}"
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
    echo -e "${BLUE}${BOLD}REBUILD OPTIONS:${NC}"
    echo "${BLUE}${BOLD}1) FIRMWARE & PACKAGE UPDATE${NC}"
    echo "${BLUE}${BOLD}2) FIRMWARE UPDATE${NC}"
    echo "${BLUE}${BOLD}3) EXISTING UPDATE${NC}"

    while true; do
        prompt "${YELLOW}${BOLD}CHOOSE OPTION [1/2/3]: ${NC}" opt
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
                echo -e "${RED}${BOLD}INVALID CHOICE.${NC}" ;;
        esac
    done
}

check_git
main_menu

echo -e "${CYAN}${BOLD}INSTALLING DEPENDENCIES...${NC}"
sudo apt update -y && sudo apt full-upgrade -y
sudo apt install -y "${deps[@]}"

if [ -d "$distro/.git" ]; then
    echo -e "${BLUE}${BOLD}FOUND EXISTING '$distro' DIRECTORY.${NC}"
    rebuild_menu
else
    build_menu
fi
