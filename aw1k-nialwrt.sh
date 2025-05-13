#!/bin/bash

# Define colors (Ubuntu-like)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

folder="immortalwrt"
preset_folder="AW1K-NIALWRT"
script_file="$(basename "$0")"

# Check for --clean argument
if [[ "$1" == "--clean" ]]; then
    echo -e "${BLUE}${BOLD}Cleaning up directories and script...${NC}"
    if [ -d "$folder" ]; then
        echo -e "${BLUE}Removing '$folder' directory...${NC}"
    fi
    if [ -d "$preset_folder" ]; then
        echo -e "${BLUE}Removing '$preset_folder' directory...${NC}"
    fi
    if [ -f "$script_file" ]; then
        echo -e "${BLUE}Removing script file '$script_file'...${NC}"
    fi
    exit 0
fi

clear
echo -e "${BLUE}${BOLD}AW1K-NIALWRT Firmware Builder${NC}"
echo ""

# Install dependencies
echo -e "${BLUE}Installing required dependencies for ImmortalWrt...${NC}"
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

# Remove existing ImmortalWrt directory if present
if [ -d "$folder" ]; then
    echo -e "${BLUE}Removing existing '$folder' directory...${NC}"
fi

# Clone ImmortalWrt repository
repo="https://github.com/immortalwrt/immortalwrt.git"
echo -e "${BLUE}Cloning ImmortalWrt repository...${NC}"
git clone "$repo" "$folder"

# Clone preset repository
if [ -d "$preset_folder" ]; then
    echo -e "${BLUE}Removing existing '$preset_folder' directory...${NC}"
fi
preset_repo="https://github.com/nialwrt/AW1K-NIALWRT.git"
echo -e "${BLUE}Cloning preset repository...${NC}"
git clone "$preset_repo"

# Enter ImmortalWrt directory
cd "$folder"

# Initial feeds setup
echo -e "${BLUE}Setting up feeds...${NC}"
./scripts/feeds update -a && ./scripts/feeds install -a

# Prompt for custom feeds
echo -e "${BLUE}You may now add custom feeds manually if needed.${NC}"
read -p "Press Enter to continue..." temp

# Re-run feeds in loop if error
while true; do
    ./scripts/feeds update -a && ./scripts/feeds install -a && break
    echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed. Please address the issue, then press Enter to retry...${NC}"
    read -r
done

# List available branches and tags
echo -e "${BLUE}Available branches:${NC}"
git branch -a
echo -e "${BLUE}Available tags:${NC}"
git tag | sort -V

# Prompt user for target branch or tag
while true; do
    echo -ne "${BLUE}Enter the target branch or tag to checkout: ${NC}"
    read TARGET_TAG
    if git checkout "$TARGET_TAG"; then
        break
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Invalid selection. Please try again.${NC}"
    fi
done

# Copy preset files and config
echo -e "${BLUE}Copying preset files and configuration...${NC}"
cp -r "../$preset_folder/files" ./
cp "../$preset_folder/config-upload" .config

# Run defconfig
echo -e "${BLUE}Applying default configuration...${NC}"
make defconfig

# Ask if user wants to open menuconfig
echo -ne "${BLUE}Do you want to open '${BOLD}make menuconfig${NC}${BLUE}' to customize the build? (y/n): ${NC}"
read answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    echo -e "${BLUE}Launching ${BOLD}menuconfig${NC}${BLUE}...${NC}"
    make menuconfig
else
    echo -e "${BLUE}Skipping menuconfig step.${NC}"
fi

# Start build loop
while true; do
    echo -e "${BLUE}Starting build process...${NC}"
    start_time=$(date +%s)

    if make -j"$(nproc)"; then
        echo -e "${GREEN}${BOLD}Build completed successfully.${NC}"
        break
    else
        echo -e "${RED}${BOLD}Error:${NC} ${RED}Build failed. Running '${BOLD}make V=s${NC}${RED}' for detailed output...${NC}"
        make -j1 V=s

        echo -e "${RED}Please identify and resolve the error, then press Enter to continue...${NC}"
        read -r

        # Feeds recovery
        while true; do
            ./scripts/feeds update -a && ./scripts/feeds install -a && break
            echo -e "${RED}${BOLD}Error:${NC} ${RED}Feeds update/install failed. Please fix the issue and press Enter to retry...${NC}"
            read -r
        done

        echo -e "${BLUE}Applying default configuration again...${NC}"
        make defconfig

        # Ask if user wants to open menuconfig again
        read -p "$(echo -e ${BLUE}Do you want to open ${BOLD}menuconfig${NC}${BLUE} again? [y/N]: ${NC})" mc
        if [[ "$mc" == "y" || "$mc" == "Y" ]]; then
            make menuconfig
        fi
    fi

    # Build duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    hours=$((duration / 3600))
    minutes=$(((duration % 3600) / 60))
    echo -e "${BLUE}Build duration: ${BOLD}${hours} hour(s)${NC}${BLUE} and ${BOLD}${minutes} minute(s)${NC}${BLUE}.${NC}"
done

# Go back to parent directory
cd ..

# Cleanup preset folder
if [ -d "$preset_folder" ]; then
    echo -e "${BLUE}Removing preset folder '$preset_folder'...${NC}"
fi

# Cleanup this script file
if [ -f "$script_file" ]; then
    echo -e "${BLUE}Removing script file '$script_file'...${NC}"
fi
