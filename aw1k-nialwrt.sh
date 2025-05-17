#!/bin/bash

script_path="$(realpath "$0")"

# Reset & style
RESET='\033[0m'
BOLD='\033[1m'
BLACK='\033[30m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'

# Gabungkan style dan warna jika perlu
BOLD_BLACK="${BOLD}${BLACK}"
BOLD_RED="${BOLD}${RED}"
BOLD_GREEN="${BOLD}${GREEN}"
BOLD_YELLOW="${BOLD}${YELLOW}"
BOLD_BLUE="${BOLD}${BLUE}"
BOLD_MAGENTA="${BOLD}${MAGENTA}"
BOLD_CYAN="${BOLD}${CYAN}"
BOLD_WHITE="${BOLD}${WHITE}"

# Distro & preset
distro="immortalwrt"
repo="https://github.com/immortalwrt/immortalwrt.git"
preset_folder="AW1K-NIALWRT"
preset_repo="https://github.com/nialwrt/AW1K-NIALWRT.git"

# Build dependencies
deps=(
    ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential
    bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext
    gcc-multilib g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1
    libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev
    libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev
    lld llvm lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3
    python3-pip python3-ply python3-docutils python3-pyelftools qemu-utils re2c rsync scons
    squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd
)

# Placeholder
choice=""
target_tag=""
opt=""

prompt() {
    echo -ne "$1"
    read -r "$2"
}

check_git() {
    command -v git &>/dev/null || {
        echo -e "${BOLD_RED}ERROR:${RESET} Git is required."
        exit 1
    }
}

main_menu() {
    clear
    echo -e "${BOLD_MAGENTA}--------------------------------------${RESET}"
    echo -e "${BOLD_MAGENTA}  AW1K-NIALWRT FIRMWARE BUILD          ${RESET}"
    echo -e "${BOLD_MAGENTA}  https://github.com/nialwrt            ${RESET}"
    echo -e "${BOLD_MAGENTA}  TELEGRAM: @NIALVPN                    ${RESET}"
    echo -e "${BOLD_MAGENTA}--------------------------------------${RESET}"
    echo -e "${BOLD_BLUE}BUILD MENU:${RESET}"
}

update_feeds() {
    echo -e "${BOLD_YELLOW}UPDATING FEEDS...${RESET}"
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BOLD_BLUE}EDIT FEEDS IF NEEDED, THEN PRESS ENTER: ${RESET}";
    read
    echo -e "${BOLD_YELLOW}UPDATING FEEDS...${RESET}"
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
     echo -e "${BOLD_GREEN}FEEDS UPDATED.${RESET}"
}

select_target() {
    echo -e "${BOLD_BLUE}SELECT BRANCH OR TAG:${RESET}"
    git fetch --all --tags
    echo -e "${BOLD_BLUE}BRANCHES:${RESET}"
    git branch -r | sed 's|origin/||' | grep -v 'HEAD' | sort -u
    echo -e "${BOLD_BLUE}TAGS:${RESET}"
    git tag | sort -V

    while true; do
        prompt "${BOLD_BLUE}ENTER BRANCH OR TAG: ${RESET}" target_tag
        git checkout "$target_tag" &>/dev/null && {
            echo -e "${BOLD_GREEN}CHECKED OUT TO $target_tag${RESET}"
            break
        } || echo -e "${BOLD_RED}INVALID BRANCH/TAG: $target_tag${RESET}"
    done
}

ensure_preset() {
    echo -e "${BOLD_YELLOW}CLEANING OLD PRESET AND CONFIG...${RESET}"
    rm -rf ./files .config "$preset_folder"
    echo -e "${BOLD_YELLOW}CLONING PRESET FROM $preset_repo...${RESET}"
    git clone "$preset_repo" "$preset_folder" && echo -e "${BOLD_GREEN}PRESET CLONED.${RESET}" || {
        echo -e "${BOLD_RED}FAILED TO CLONE PRESET.${RESET}"
        exit 1
    }
}

apply_preset() {
    echo -e "${BOLD_YELLOW}APPLYING PRESET FILES AND CONFIG...${RESET}"
    cp -r "$preset_folder/files" ./ 2>/dev/null
    cp "$preset_folder/config-upload" .config 2>/dev/null || echo -e "${BOLD_RED}WARNING: config-upload not found.${RESET}"
}

run_menuconfig() {
    echo -e "${BOLD_YELLOW}RUNNING MENUCONFIG...${RESET}"
    make menuconfig && echo -e "${BOLD_GREEN}CONFIGURATION SAVED.${RESET}" || echo -e "${BOLD_RED}MENUCONFIG FAILED.${RESET}"
}

start_build() {
    echo -e "${BOLD_YELLOW}BUILDING WITH $(nproc) CORES...${RESET}"
    local start=$(date +%s)
    if make -j"$(nproc)"; then
        local dur=$(( $(date +%s) - start ))
        printf "${BOLD_GREEN}BUILD COMPLETED IN %02dh %02dm %02ds${RESET}\n" $((dur / 3600)) $(((dur % 3600) / 60)) $((dur % 60))
        echo -e "${BOLD_BLUE}OUTPUT: $(pwd)/bin/targets/${RESET}"
    else
        echo -e "${BOLD_RED}BUILD FAILED.${RESET}"
    fi
}

cleanup() {
    echo -e "${BOLD_YELLOW}CLEANING UP...${RESET}"
    rm -rf "$preset_folder"
}

build_menu() {
    echo -e "${BOLD_BLUE}CLONING REPO: $repo...${RESET}"
    git clone "$repo" "$distro" || {
        echo -e "${BOLD_RED}GIT CLONE FAILED.${RESET}"
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
    clear
    cd "$distro" || exit 1

    clear
    echo -e "${BOLD_MAGENTA}--------------------------------------${RESET}"
    echo -e "${BOLD_MAGENTA}  AW1K-NIALWRT FIRMWARE BUILD          ${RESET}"
    echo -e "${BOLD_MAGENTA}  https://github.com/nialwrt            ${RESET}"
    echo -e "${BOLD_MAGENTA}  TELEGRAM: @NIALVPN                    ${RESET}"
    echo -e "${BOLD_MAGENTA}--------------------------------------${RESET}"
    echo -e "${BOLD_BLUE}REBUILD MENU:${RESET}"
    echo -e "1)FIRMWARE & PACKAGE UPDATE (FULL REBUILD)"
    echo -e "2)FIRMWARE UPDATE (FAST REBUILD)"
    echo -e "3)EXISTING UPDATE (NO CHANGES)"
    while true; do
        prompt "${BOLD_BLUE}CHOOSE OPTION [1/2/3]: ${RESET}" opt
        case "$opt" in
        1)
            make distclean
            update_feeds || exit 1
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
            echo -e "${BOLD_RED}INVALID CHOICE. PLEASE ENTER 1, 2, OR 3.${RESET}" ;;
        esac
    done
}

# Start process
check_git
main_menu

echo -e "${BOLD_YELLOW}INSTALLING DEPENDENCIES...${RESET}"
sudo apt update -y && sudo apt full-upgrade -y
sudo apt install -y "${deps[@]}"

if [ -d "$distro/.git" ]; then
    echo -e "${BOLD_BLUE}FOUND EXISTING '$distro' DIRECTORY.${RESET}"
    rebuild_menu
else
    build_menu
fi
