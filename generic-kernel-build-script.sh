#!/bin/bash

# Generic automated compilation script for kernels
# This script uses two toolchains(San-gcc/Neutron-clang) based on os environment
# Change CROSS_COMPILE_ARM32 to CROSS_COMPILE_COMPACT if compiling 4.19 or other upstream kernel sources sources
# By @user_why_red

# Reminder to source the script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Please source this script instead of executing it:"
    echo "source $0"
    exit 1
fi

# Function to install dependencies on Debian-based systems
install_debian_dependencies() {
    echo "Installing dependencies on Debian-based system..."
    sudo apt update
    sudo apt install -y cpio flex bison bc libarchive-tools zstd wget curl

    if [[ $? -ne 0 ]]; then
        echo "Failed to install dependencies on Debian-based system"
        exit 1
    fi
    echo "Dependencies installed successfully on Debian-based system"
}

# Function to install dependencies on Arch-based systems
install_arch_dependencies() {
    echo "Installing dependencies on Arch-based system..."
    sudo pacman -Sy
    sudo pacman -S --needed cpio flex bison bc libarchive zstd wget curl

    if [[ $? -ne 0 ]]; then
        echo "Failed to install dependencies on Arch-based system"
        exit 1
    fi
    echo "Dependencies installed successfully on Arch-based system"
}

# Function to export PATH for SAN-GCC
export_san_gcc_path() {
    echo "Exporting PATH for san-gcc..."
    export PATH="$HOME/toolchains/san-gcc/bin:$PATH"
    echo "Exported PATH for san-gcc"
}

# Function to download and extract SAN-GCC release package
download_san_release_package() {
    echo "Downloading SAN-GCC from releases..."
    local url="https://github.com/user-why-red/san_gcc_toolchain_x86_64/releases/download/20231221/san-gcc-toolchain-x86_64-20231221.tar.gz"
    wget "$url" -O "$HOME/san-gcc-toolchain-x86_64-20231221.tar.gz"

    if [[ $? -ne 0 ]]; then
        echo "Failed to download release package"
        exit 1
    fi
    echo "Release package downloaded successfully"
    echo "Extracting downloaded tarball..."
    tar -xvf "$HOME/san-gcc-toolchain-x86_64-20231221.tar.gz" -C "$HOME"
    if [[ $? -ne 0 ]]; then
        echo "Failed to extract release package"
        exit 1
    fi
    echo "Extraction completed!"
    echo "Setting up toolchain path..."
    export_san_gcc_path
}

# Function to patch glibc using Neutron Clang
patch_glibc() {
    echo "Patching glibc using Neutron Clang..."
    cd "$HOME/toolchains/neutron-clang"
    ./antman --patch=glibc
    if [[ $? -ne 0 ]]; then
        echo "Failed to patch glibc"
        exit 1
    fi
    cd "$HOME"
    echo "glibc patched successfully"
}

# Function to export PATH for Neutron Clang
export_neutron_clang_path() {
    echo "Exporting PATH for Neutron Clang..."
    export PATH="$HOME/toolchains/neutron-clang/bin:$PATH"
    echo "Exported PATH for Neutron Clang"
}

# Function to install Neutron Clang
install_neutron_clang() {
    echo "Installing Neutron Clang..."
    rm -rf "$HOME/toolchains"
    local version
    read -p "Enter Neutron release tag to download (e.g., 05012024): " version
    mkdir -p "$HOME/toolchains/neutron-clang"
    cd "$HOME/toolchains/neutron-clang"
    curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
    chmod +x antman
    ./antman -S="$version"
    if [[ $? -ne 0 ]]; then
        echo "Failed to install Neutron Clang"
        exit 1
    fi
    echo "Neutron Clang installed successfully"
    export_neutron_clang_path
    patch_glibc
}

# Function to check glibc version
check_glibc_version() {
    echo "Checking glibc version..."
    local host_glibc
    host_glibc=$(ldd --version | head -n1 | grep -oE '[^ ]+$')

    # Check glibc version is < 2.36
    if (( $(echo "$host_glibc <= 2.35" | bc -l) )); then
        echo "glibc version: $host_glibc"
        echo "glibc version $host_glibc is less than required glibc for SAN-GCC and Neutron Clang"
        echo "You can't use SAN-GCC, so installing Neutron Clang and patching host glibc"
        install_neutron_clang
    else
        download_san_release_package
    fi
}

# Function to prompt for kernel source GitHub link
prompt_kernel_source_link() {
    read -p "Enter the GitHub link for the kernel source: " kernel_source_link
    echo "Kernel source link: $kernel_source_link"
    prompt_clone_options "$kernel_source_link"
}

# Function to get the default branch of the repo
repo_url="$kernel_source_link"
get_default_branch() {
    owner_repo=$(echo "$repo_url" | awk -F'/' '{print $4 "/" $5}')
    default_branch=$(curl -s "https://api.github.com/repos/$owner_repo" | grep -oP '(?<="default_branch": ")[^"]+')

    echo "Default branch of $repo_url is $default_branch"
}

# Function to prompt for shallow or full clone and directory name
prompt_clone_options() {
    local kernel_source_link=$1
    read -p "Do you want to perform a shallow clone? (y/n): " shallow_clone
    read -p "Need to clone specific branch of the kernel source?(type default to clone main branch): " specific_branch
    if [ "$shallow_clone" == "y" ]; then
        echo "Shallow cloning kernel source..."
	    if [ "$specific_branch" == "default" ]; then
		specific_branch="$default_branch"
	    fi
            git clone --single-branch --branch="$specific_branch" "$kernel_source_link" --depth=1 "$HOME/kernel"

    elif [ "$shallow_clone" == "n" ]; then
        echo "Full cloning kernel source..."
	    if [ "$specific_branch" == "default "]; then
	        specific_branch="$default_branch"
	    if
            git clone --single-branch --branch="$specific_branch" "$kernel_source_link" "$HOME/kernel"
    else
        echo "Invalid input. Please type 'y' or 'n'."
        exit 1
    fi
    cd "$HOME/kernel"
    echo "Kernel sources synced!"
}

# Function to prompt if user wants to build the kernel
prompt_build_kernel() {
    read -p "Do you want to compile the kernel now? (y/n): " compile_kernel
    if [ "$compile_kernel" == "y" ]; then
        read -p "Enter defconfig path: " config_path
        echo "Writing configuration..."
        local host_glibc
        host_glibc=$(ldd --version | head -n1 | grep -oE '[^ ]+$')

        # Use neutron clang environmental variables if glibc is <= 2.35
        if (( $(echo "$host_glibc <= 2.35" | bc -l) )); then
            make -j$(nproc) ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 "$config_path" O=out
            echo "Compilation started..."
            make -j$(nproc) ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1 O=out
        else
            # Use san gcc environmental variables if host glibc is already latest/compatible
            make -j$(nproc) ARCH=arm64 CC=aarch64-linux-gcc CROSS_COMPILE=aarch64-linux- CROSS_COMPILE_ARM32=arm-linux-gnueabi- "$config_path" O=out
            echo "Compilation started..."
            make -j$(nproc) ARCH=arm64 CC=aarch64-linux-gcc CROSS_COMPILE=aarch64-linux- CROSS_COMPILE_ARM32=arm-linux-gnueabi- O=out
        fi
    else
        echo "Exiting script..."
        exit 0
    fi
}

# Detect the distribution and call the appropriate function
read -p "Is your system Debian-based or Arch-based? (Type 'debian' or 'arch'): " system

case "$system" in
    debian)
        echo "Your system is Debian-based."
        install_debian_dependencies
        ;;
    arch)
        echo "Your system is Arch-based."
        install_arch_dependencies
        ;;
    *)
        echo "Invalid input. Please type 'debian' or 'arch'."
        exit 1
        ;;
esac

check_glibc_version
prompt_kernel_source_link
prompt_build_kernel
