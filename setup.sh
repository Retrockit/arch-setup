#!/bin/bash
#
# Arch Linux System Setup Script
# ==============================
#
# Copyright (c) 2025 SolutionMonk
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# This script automates the installation of commonly used tools on Arch Linux.
# It is designed to be idempotent and maintainable, allowing easy addition and 
# removal of tools.
#
# CUSTOMIZATION GUIDE
# ------------------
#
# 1. PACKAGE ARRAYS - Customize What Gets Installed
#
#    The script uses arrays to define what packages to install. Find these arrays
#    near the top of the script (look for lines like "readonly SYSTEM_PACKAGES=(...)")
#    and add or remove items to customize your installation:
#
#    - SYSTEM_PACKAGES: Core system utilities
#    - DEV_PACKAGES: Development tools and libraries
#    - UTIL_PACKAGES: Utility programs and tools
#    - FLATPAK_APPS: Desktop applications from Flathub
#    - AUR_PACKAGES: Applications from Arch User Repository
#
#    Example: To remove GIMP from Flatpak installation, find FLATPAK_APPS and remove
#    the "org.gimp.GIMP" line.
#
# 2. DISABLING COMPONENTS - Skip What You Don't Need
#
#    To disable entire components, find the corresponding function call in the main() 
#    function and comment it out by adding # at the beginning:
#
#    Example: To skip Docker installation:
#    # install_docker
#    # configure_docker_post_install
#
# 3. ADDING NEW COMPONENTS
#
#    To add custom installations:
#    a. Create a new function for your component (use existing functions as templates)
#    b. Add a call to your function in the main() function
#
#    Example: For a custom app installation, add:
#    function install_my_custom_app() {
#      log "Installing my custom application"
#      # Your installation commands
#    }
#    
#    Then add in main(): install_my_custom_app
#
# USAGE
# -----
#
#   ./setup.sh              Run interactively
#   ./setup.sh --auto       Run in automatic mode (no prompts)
#   ./setup.sh --help       Show usage information
#   
# EXAMPLES
# --------
#
#   sudo ./setup.sh                     Regular installation with prompts
#   sudo ./setup.sh --auto              Fully automated installation 
#   wget -qO- URL | sudo bash -s -- --auto   Remote execution
#
# INSTALLED COMPONENTS
# -------------------
#
# System & Development:
# - Core system utilities and development tools
# - Docker and Podman container platforms
# - pyenv Python version manager
# - mise runtime version manager
# - Neovim editor with kickstart.nvim config
# - Lua and LuaRocks
# - KVM/QEMU virtualization
#
# Applications:
# - Visual Studio Code
# - JetBrains Toolbox
# - Google Chrome
# - 1Password (desktop & CLI)
# - Steam
# - Various Flatpak applications (see arrays for full list)
#
# Shell:
# - Fish shell configured as default
# - Developer-friendly shell configuration
#
# LOGS
# ----
#
# Installation logs are saved to: /tmp/{script-name}_{timestamp}.log
#
# MAINTAINER
# ----------
#
# Franklin J. Lee
# https://github.com/Retrockit/arch-setup
#

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Constants
AUTO_MODE="false"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/tmp/${SCRIPT_NAME%.sh}_$(date +%Y%m%d_%H%M%S).log"
readonly LOG_MARKER=">>>"
readonly CONTAINERS_REGISTRIES_CONF="/etc/containers/registries.conf"
readonly JETBRAINS_INSTALL_DIR="/home/$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")/.local/share/JetBrains/Toolbox/bin"
readonly JETBRAINS_SYMLINK_DIR="/home/$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")/.local/bin"
readonly PYENV_INSTALLER="https://pyenv.run"
readonly MISE_INSTALLER="https://mise.run"
readonly FLATHUB_REPO="https://flathub.org/repo/flathub.flatpakrepo"

# Package arrays - customize these according to your needs (Arch Linux package names)
readonly SYSTEM_PACKAGES=(
  "base-devel"
  "curl"
  "gnupg"
  "wget"
  "fuse2"  # For AppImage support
)

readonly DEV_PACKAGES=(
  "gcc"
  "git" 
  "python" 
  "python-pip"
  "readline"
)

# Pyenv build dependencies (Arch package names)
readonly PYENV_DEPENDENCIES=(
  "base-devel"
  "openssl"
  "zlib"
  "bzip2"
  "readline"
  "sqlite"
  "curl"
  "git"
  "ncurses"
  "xz"
  "tk"
  "libffi"
  "python-setuptools"
  "python-wheel"
  "python-pip"
)

readonly UTIL_PACKAGES=(
  "htop"
  "tmux"
  "tree"
  "unzip"
  "fish"
)

# List of AUR packages to install
readonly AUR_PACKAGES=(
  "visual-studio-code-bin"
  "google-chrome"
  "jetbrains-toolbox"
  "1password"
  "1password-cli"
)

# Flatpak packages
readonly FLATPAK_PACKAGES=(
  "flatpak"
)

# list of Flatpak apps to install
readonly FLATPAK_APPS=(
  "info.smplayer.SMPlayer"             # SMPlayer
  "com.discordapp.Discord"             # Discord
  "com.slack.Slack"                    # Slack
  "org.telegram.desktop"               # Telegram
  "com.github.tchx84.Flatseal"         # Flatseal (Flatpak permissions manager)
  "org.gimp.GIMP"                      # GIMP
  "it.mijorus.gearlever"               # Gear Lever
  "org.duckstation.DuckStation"        # DuckStation
  "org.DolphinEmu.dolphin-emu"         # Dolphin Emulator
  "net.pcsx2.PCSX2"                    # PCSX2
  "io.github.mhogomchungu.media-downloader" # Media Downloader
)

# Steam dependencies (Arch package names)
readonly STEAM_DEPENDENCIES=(
  "lib32-nvidia-utils"       # For NVIDIA GPUs
  "lib32-mesa"               # For AMD/Intel GPUs
  "lib32-vulkan-icd-loader"  # Vulkan support
  "vulkan-icd-loader"        # Vulkan support
  "lib32-libva-mesa-driver"  # VA-API video acceleration
)

# Lua build dependencies
readonly LUA_DEPENDENCIES=(
  "base-devel"
  "readline"
)

# Docker and Podman packages
readonly DOCKER_PACKAGES=(
  "docker"
  "docker-buildx"
  "docker-compose"
)

readonly PODMAN_PACKAGES=(
    "podman"
)

# KVM/libvirt packages
readonly KVM_PACKAGES=(
  "qemu-full"
  "qemu-img"
  "libvirt"
  "virt-install"
  "virt-manager"
  "virt-viewer"
  "edk2-ovmf"
  "dnsmasq"
  "swtpm"
  "guestfs-tools"
  "libosinfo"
  "tuned"
)

# Helper functions
#######################################
# Log a message to both stdout and the log file
# Globals:
#   LOG_FILE
#   LOG_MARKER
# Arguments:
#   Message to log
#######################################
log() {
  local timestamp
  timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
  echo "[${timestamp}] ${LOG_MARKER} $*" | tee -a "${LOG_FILE}"
}

#######################################
# Log an error message and exit
# Globals:
#   LOG_FILE
# Arguments:
#   Error message
#######################################
err() {
  local timestamp
  timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
  echo "[${timestamp}] ERROR: $*" | tee -a "${LOG_FILE}" >&2
  exit 1
}

#######################################
# Check if a command exists
# Arguments:
#   Command to check
# Returns:
#   0 if command exists, 1 otherwise
#######################################
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#######################################
# Check if a package is installed (Arch version)
# Arguments:
#   Package name
# Returns:
#   0 if package is installed, 1 otherwise
#######################################
package_installed() {
  pacman -Qi "$1" &>/dev/null
}

#######################################
# Install packages if they are not already installed
# Arguments:
#   List of packages to install
#######################################
install_packages() {
  local packages=("$@")
  local packages_to_install=()
  local pkg

  # Check which packages need to be installed
  for pkg in "${packages[@]}"; do
    if ! package_installed "${pkg}"; then
      packages_to_install+=("${pkg}")
    else
      log "Package ${pkg} is already installed"
    fi
  done

  # Install missing packages if any
  if (( ${#packages_to_install[@]} > 0 )); then
    log "Installing packages: ${packages_to_install[*]}"
    if ! pacman -S --noconfirm "${packages_to_install[@]}"; then
      err "Failed to install packages: ${packages_to_install[*]}"
    fi
    log "Successfully installed: ${packages_to_install[*]}"
  else
    log "All packages already installed, skipping"
  fi
}

#######################################
# Update system packages
# Globals:
#   None
# Arguments:
#   None
#######################################
update_system() {
  log "Updating package databases and system packages"
  if ! pacman -Syu --noconfirm; then
    err "Failed to update system packages"
  fi
  
  log "System update completed successfully"
}

#######################################
# Install AUR helper (yay)
# Globals:
#   None
# Arguments:
#   None
#######################################
install_aur_helper() {
  if command_exists yay; then
    log "yay AUR helper is already installed"
    return 0
  fi

  log "Installing yay AUR helper"
  
  # Install git and base-devel if not already installed
  install_packages "git" "base-devel"
  
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  local build_dir="/tmp/yay-build"
  
  log "Building yay from source"
  
  # Clean up existing directory if it exists
  rm -rf "${build_dir}"
  
  # Create build directory
  mkdir -p "${build_dir}"
  cd "${build_dir}" || err "Failed to enter ${build_dir} directory"
  
  # Clone the repository as the regular user (not root)
  if ! su -l "${current_user}" -c "git clone https://aur.archlinux.org/yay.git ${build_dir}"; then
    err "Failed to clone yay repository"
  fi
  
  # Build and install yay as the regular user
  if ! su -l "${current_user}" -c "cd ${build_dir} && makepkg -si --noconfirm"; then
    err "Failed to build and install yay"
  fi
  
  # Clean up build directory
  rm -rf "${build_dir}"
  
  # Verify installation
  if command_exists yay; then
    log "yay AUR helper installed successfully"
    return 0
  else
    err "yay AUR helper installation failed"
  fi
}

#######################################
# Install packages from AUR if they are not already installed
# Arguments:
#   List of packages to install
#######################################
install_aur_packages() {
  local packages=("$@")
  local packages_to_install=()
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  local pkg

  if ! command_exists yay; then
    install_aur_helper
  fi

  # Check which packages need to be installed
  for pkg in "${packages[@]}"; do
    if ! package_installed "${pkg}"; then
      packages_to_install+=("${pkg}")
    else
      log "AUR Package ${pkg} is already installed"
    fi
  done

  # Install missing packages if any
  if (( ${#packages_to_install[@]} > 0 )); then
    log "Installing AUR packages: ${packages_to_install[*]}"
    if ! su -l "${current_user}" -c "yay -S --noconfirm ${packages_to_install[*]}"; then
      err "Failed to install AUR packages: ${packages_to_install[*]}"
    fi
    log "Successfully installed AUR packages: ${packages_to_install[*]}"
  else
    log "All AUR packages already installed, skipping"
  fi
}

#######################################
# Install Flatpak with Flathub on Arch Linux
# Globals:
#   FLATPAK_PACKAGES
#   FLATHUB_REPO
# Arguments:
#   None
#######################################
install_flatpak() {
  log "Installing Flatpak on Arch Linux"
  
  # Install flatpak package
  install_packages "flatpak"
  
  # Add Flathub repository for the current user
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  log "Adding Flathub repository for user ${current_user}"
  su -l "${current_user}" -c "flatpak remote-add --user --if-not-exists flathub ${FLATHUB_REPO}"
  
  log "Flatpak with Flathub repository has been set up successfully"
}

#######################################
# Install Flatpak apps for the current user
# Globals:
#   FLATPAK_APPS
# Arguments:
#   None
#######################################
install_flatpak_apps() {
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  log "Installing Flatpak applications for user ${current_user}"
  
  # Make sure Flatpak is installed before proceeding
  if ! command_exists flatpak; then
    log "Flatpak is not installed. Installing it first."
    install_flatpak
  fi
  
  # Install each app in the FLATPAK_APPS array
  for app in "${FLATPAK_APPS[@]}"; do
    # Extract app name for logging (remove everything before the last dot)
    local app_name
    app_name=$(echo "$app" | sed 's/.*\.//')
    
    # Check if the app is already installed
    if su -l "${current_user}" -c "flatpak list --app | grep -q ${app}"; then
      log "Flatpak app ${app_name} is already installed"
    else
      log "Installing Flatpak app: ${app_name}"
      if ! su -l "${current_user}" -c "flatpak install --user -y flathub ${app}"; then
        log "Warning: Failed to install Flatpak app ${app_name}"
        # Continue with the next app instead of exiting
      else
        log "Flatpak app ${app_name} installed successfully"
      fi
    fi
  done
  
  log "Flatpak applications installation completed"
}

#######################################
# Install Docker on Arch Linux
# Globals:
#   DOCKER_PACKAGES
# Arguments:
#   None
#######################################
install_docker() {
  if command_exists docker && docker --version >/dev/null 2>&1; then
    log "Docker is already installed"
    return 0
  fi

  log "Installing Docker from official repositories"
  
  # Install Docker packages
  install_packages "${DOCKER_PACKAGES[@]}"

  # Start and enable Docker service
  log "Enabling Docker service to start on boot"
  systemctl enable --now docker.service

  log "Docker has been installed successfully"
}

#######################################
# Configure Docker post-installation
# Globals:
#   None
# Arguments:
#   None
#######################################
configure_docker_post_install() {
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")

  # Create docker group if it doesn't exist
  if ! getent group docker >/dev/null; then
    log "Creating docker group"
    groupadd docker
  fi

  # Add user to docker group if not already a member
  if ! getent group docker | grep -q "\b${current_user}\b"; then
    log "Adding user ${current_user} to docker group"
    usermod -aG docker "${current_user}"
    log "User added to docker group. Please log out and back in for changes to take effect."
    log "Alternatively, run 'newgrp docker' to activate the changes immediately."
  else
    log "User ${current_user} is already in the docker group"
  fi

  # Verify Docker installation
  if docker run --rm hello-world >/dev/null 2>&1; then
    log "Docker installation verified successfully"
  else
    log "Warning: Docker installation verification failed. Please check your installation."
  fi
}

#######################################
# Install Podman on Arch Linux
# Globals:
#   PODMAN_PACKAGES
# Arguments:
#   None
#######################################
install_podman() {
  if command_exists podman && podman --version >/dev/null 2>&1; then
    log "Podman is already installed"
    return 0
  fi

  log "Installing Podman from official repositories"
  
  # Install Podman packages
  install_packages "${PODMAN_PACKAGES[@]}"

  # Enable podman.socket service if applicable
  if systemctl list-unit-files | grep -q podman.socket; then
    log "Enabling podman.socket service"
    systemctl enable --now podman.socket
  fi

  log "Podman has been installed successfully"
  
  # Configure Podman registries
  configure_podman_registries
}

#######################################
# Configure Podman registries
# Globals:
#   CONTAINERS_REGISTRIES_CONF
# Arguments:
#   None
#######################################
configure_podman_registries() {
  local containers_conf_dir="/etc/containers"
  local registries_conf="${containers_conf_dir}/registries.conf"
  
  # Create system-wide containers config directory if it doesn't exist
  if [ ! -d "${containers_conf_dir}" ]; then
    log "Creating system-wide containers config directory: ${containers_conf_dir}"
    mkdir -p "${containers_conf_dir}"
  fi
  
  # Configure unqualified search registries if not already present
  if [ -f "${registries_conf}" ]; then
    if ! grep -q "unqualified-search-registries" "${registries_conf}"; then
      log "Adding unqualified search registries to ${registries_conf}"
      cat >> "${registries_conf}" << 'EOF'

# Added by setup script
[registries.search]
registries = ['docker.io', 'quay.io']
EOF
    else
      log "Unqualified search registries already configured"
    fi
  else
    log "Creating ${registries_conf} with unqualified search registries"
    cat > "${registries_conf}" << 'EOF'
# Registries configuration file - setup by installation script

[registries.search]
registries = ['docker.io', 'quay.io']
EOF
  fi
  
  log "Podman registries configured successfully"
}

#######################################
# Install pyenv for the current user
# Globals:
#   PYENV_DEPENDENCIES
#   PYENV_INSTALLER
# Arguments:
#   None
#######################################
install_pyenv() {
  log "Installing pyenv dependencies"
  install_packages "${PYENV_DEPENDENCIES[@]}"
  
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  log "Installing pyenv for user ${current_user}"
  
  # Check if pyenv is already installed
  if su -l "${current_user}" -c "command -v pyenv" >/dev/null 2>&1; then
    log "pyenv is already installed for user ${current_user}"
  else
    log "Installing pyenv using the installer script"
    su -l "${current_user}" -c "curl -fsSL ${PYENV_INSTALLER} | bash"
    
    # Set up shell integration for bash
    if [ -f "/home/${current_user}/.bashrc" ]; then
      if ! grep -q "pyenv init" "/home/${current_user}/.bashrc"; then
        log "Setting up pyenv in .bashrc"
        cat >> "/home/${current_user}/.bashrc" << 'EOF'

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF
      fi
    fi
    
    # Set up shell integration for fish
    local fish_config_dir="/home/${current_user}/.config/fish"
    local fish_config_file="${fish_config_dir}/config.fish"
    
    if [ ! -d "${fish_config_dir}" ]; then
      mkdir -p "${fish_config_dir}"
      chown "${current_user}:${current_user}" "${fish_config_dir}"
    fi
    
    if [ -f "${fish_config_file}" ]; then
      if ! grep -q "pyenv init" "${fish_config_file}"; then
        log "Setting up pyenv in fish config"
        cat >> "${fish_config_file}" << 'EOF'

# pyenv setup
set -gx PYENV_ROOT $HOME/.pyenv
fish_add_path $PYENV_ROOT/bin
pyenv init - | source
status --is-interactive; and pyenv virtualenv-init - | source
EOF
        chown "${current_user}:${current_user}" "${fish_config_file}"
      fi
    else
      log "Creating fish config with pyenv setup"
      cat > "${fish_config_file}" << 'EOF'
# pyenv setup
set -gx PYENV_ROOT $HOME/.pyenv
fish_add_path $PYENV_ROOT/bin
pyenv init - | source
status --is-interactive; and pyenv virtualenv-init - | source
EOF
      chown "${current_user}:${current_user}" "${fish_config_file}"
    fi
    
    log "pyenv installed successfully for user ${current_user}"
  fi
}

#######################################
# Install mise for the current user
# Globals:
#   MISE_INSTALLER
# Arguments:
#   None
#######################################
install_mise() {
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  local home_dir="/home/${current_user}"
  local fish_config_dir="${home_dir}/.config/fish"
  local fish_completions_dir="${fish_config_dir}/completions"
  
  log "Installing mise for user ${current_user}"
  
  # Check if mise is already installed
  if su -l "${current_user}" -c "command -v mise" >/dev/null 2>&1; then
    log "mise is already installed for user ${current_user}"
  else
    # Run the mise installer as the current user
    log "Running the mise installer script"
    su -l "${current_user}" -c "curl -fsSL ${MISE_INSTALLER} | sh"
    
    # Make sure the fish config directories exist
    if [ ! -d "${fish_completions_dir}" ]; then
      log "Creating fish completions directory"
      su -l "${current_user}" -c "mkdir -p '${fish_completions_dir}'"
    fi
    
    # Add mise activation to fish config
    local fish_config_file="${fish_config_dir}/config.fish"
    if [ -f "${fish_config_file}" ]; then
      if ! grep -q "mise activate" "${fish_config_file}"; then
        log "Adding mise activation to fish config"
        su -l "${current_user}" -c "echo '~/.local/bin/mise activate fish | source' >> '${fish_config_file}'"
      else
        log "mise activation already configured in fish config"
      fi
    else
      log "Creating fish config with mise activation"
      su -l "${current_user}" -c "mkdir -p '${fish_config_dir}'"
      su -l "${current_user}" -c "echo '~/.local/bin/mise activate fish | source' > '${fish_config_file}'"
    fi
    
    # Setup global usage
    log "Setting up mise global usage"
    su -l "${current_user}" -c "~/.local/bin/mise use -g deno node python ruby"
    
    # Generate mise completions for fish
    log "Generating mise completions for fish"
    su -l "${current_user}" -c "~/.local/bin/mise completion fish > '${fish_completions_dir}/mise.fish'"
    
    log "mise has been successfully installed and configured for user ${current_user}"
  fi
}

#######################################
# Install Neovim with kickstart.nvim
# Globals:
#   None
# Arguments:
#   None
#######################################
install_neovim() {
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  # Check if neovim is already installed
  if command_exists nvim; then
    log "Neovim is already installed"
  else
    log "Installing Neovim"
    install_packages "neovim" "make" "gcc" "ripgrep" "unzip" "git" "xclip"
  
    # Verify installation
    if command_exists nvim; then
      local nvim_version
      nvim_version=$(nvim --version | head -n 1)
      log "Neovim installed successfully: ${nvim_version}"
    else
      err "Neovim installation failed"
    fi
  fi
  
  # Set up kickstart.nvim configuration
  local nvim_config_dir="/home/${current_user}/.config/nvim"
  
  # Check if kickstart.nvim is already set up
  if [ -d "${nvim_config_dir}" ] && [ -f "${nvim_config_dir}/init.lua" ]; then
    log "kickstart.nvim configuration already exists"
  else
    log "Setting up kickstart.nvim for user ${current_user}"
    
    # Clone kickstart.nvim repository
    su -l "${current_user}" -c "git clone https://github.com/nvim-lua/kickstart.nvim.git ~/.config/nvim"
    
    if [ -d "${nvim_config_dir}" ] && [ -f "${nvim_config_dir}/init.lua" ]; then
      log "kickstart.nvim configured successfully"
    else
      log "Warning: kickstart.nvim configuration may have failed, please check manually"
    fi
  fi

  # Add aliases for vim and vi to use neovim
  log "Setting up aliases for vim and vi to use neovim"

  # For fish shell
  local fish_config_dir="/home/${current_user}/.config/fish"
  local fish_config_file="${fish_config_dir}/config.fish"
  
  if [ -f "${fish_config_file}" ]; then
    if ! grep -q "alias vim='nvim'" "${fish_config_file}" && ! grep -q "alias vi='nvim'" "${fish_config_file}"; then
      log "Adding vim and vi aliases to fish config"
      cat >> "${fish_config_file}" << 'EOF'
      
# Neovim aliases
alias vim='nvim'
alias vi='nvim'
EOF
      chown "${current_user}:${current_user}" "${fish_config_file}"
    else
      log "vim and vi aliases already exist in fish config"
    fi
  fi

  # For bash shell
  local bash_rc="/home/${current_user}/.bashrc"
  
  if [ -f "${bash_rc}" ]; then
    if ! grep -q "alias vim='nvim'" "${bash_rc}" && ! grep -q "alias vi='nvim'" "${bash_rc}"; then
      log "Adding vim and vi aliases to bash config"
      cat >> "${bash_rc}" << 'EOF'

# Neovim aliases
alias vim='nvim'
alias vi='nvim'
EOF
      chown "${current_user}:${current_user}" "${bash_rc}"
    else
      log "vim and vi aliases already exist in bash config"
    fi
  fi
  
  log "Neovim aliases have been set up successfully"
}

#######################################
# Install and configure fish shell as default
# Globals:
#   None
# Arguments:
#   None
#######################################
configure_fish_shell() {
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  # Check if fish is already installed
  if ! command_exists fish; then
    log "Installing fish shell"
    install_packages "fish"
  else
    log "Fish shell is already installed"
  fi
  
  # Get fish shell path
  local fish_path
  fish_path=$(which fish)
  
  #  Set fish as default shell for the current user
  if ! grep -q "${fish_path}" "/etc/passwd" | grep "${current_user}"; then
    log "Setting fish as the default shell for user ${current_user}"
    chsh -s "${fish_path}" "${current_user}"
  else
    log "Fish shell is already the default for user ${current_user}"
  fi
  
  # Create fish config directory if it doesn't exist
  local fish_config_dir="/home/${current_user}/.config/fish"
  if [ ! -d "${fish_config_dir}" ]; then
    log "Creating fish config directory"
    mkdir -p "${fish_config_dir}"
    chown "${current_user}:${current_user}" "${fish_config_dir}"
  fi
  
  # Create initial fish config if it doesn't exist
  local fish_config_file="${fish_config_dir}/config.fish"
  if [ ! -f "${fish_config_file}" ]; then
    log "Creating initial fish config file"
    cat > "${fish_config_file}" << 'EOF'
# Fish shell configuration

# Add user's private bin to PATH if it exists
if test -d "$HOME/bin"
   fish_add_path "$HOME/bin"
end

if test -d "$HOME/.local/bin"
   fish_add_path "$HOME/.local/bin"
end

# Set environment variables
set -gx EDITOR nvim

# Custom aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# Fish greeting
function fish_greeting
   echo "Welcome to Fish shell!"
end

# Load local config if exists
if test -f "$HOME/.config/fish/local.fish"
   source "$HOME/.config/fish/local.fish"
end
EOF
    chown "${current_user}:${current_user}" "${fish_config_file}"
  fi
  
  log "Fish shell has been configured successfully"
}

#######################################
# Install and configure KVM with libvirt on Arch Linux
# Globals:
#   KVM_PACKAGES
# Arguments:
#   None
#######################################
install_kvm_libvirt() {
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  log "Installing KVM and libvirt packages for Arch Linux"
  
  # Install KVM and libvirt packages with the exact recommended packages
  install_packages "${KVM_PACKAGES[@]}"
  
  # Enable and start the libvirtd service
  log "Enabling and starting libvirtd service"
  systemctl enable libvirtd
  systemctl start libvirtd
  
  # Add user to the kvm and libvirt groups
  log "Adding user ${current_user} to kvm and libvirt groups"
  if ! getent group kvm | grep -q "\b${current_user}\b"; then
    usermod -aG kvm "${current_user}"
  fi
  
  if ! getent group libvirt | grep -q "\b${current_user}\b"; then
    usermod -aG libvirt "${current_user}"
  fi
  
  # Start and enable default NAT network
  log "Starting and enabling default NAT network"
  if ! virsh net-info default >/dev/null 2>&1; then
    log "Defining default network"
    virsh net-define /etc/libvirt/qemu/networks/default.xml >/dev/null 2>&1 || log "Default network may already be defined"
  fi
  
  if ! virsh net-info default | grep -q "Active:.*yes"; then
    virsh net-start default >/dev/null 2>&1 || log "Default network may already be running"
  fi
  
  virsh net-autostart default >/dev/null 2>&1
  
  # Verify installation
  if command_exists virsh && virsh -c qemu:///system list >/dev/null 2>&1; then
    log "KVM and libvirt installed and configured successfully"
  else
    log "Warning: KVM and libvirt installation may not be complete. Please check manually."
  fi
}

#######################################
# Install Steam on Arch Linux
# Globals:
#   STEAM_DEPENDENCIES
# Arguments:
#   None
#######################################
install_steam() {
  log "Installing Steam on Arch Linux"
  
  # Check if Steam is already installed
  if package_installed "steam"; then
    log "Steam is already installed"
    return 0
  fi
  
  # Install Steam dependencies
  log "Installing Steam dependencies"
  install_packages "${STEAM_DEPENDENCIES[@]}"
  
  # Install Steam
  log "Installing Steam package"
  install_packages "steam"
  
  # Verify installation
  if package_installed "steam"; then
    log "Steam installed successfully"
  else
    log "Warning: Steam installation may have failed. Please verify manually."
  fi
}

#######################################
# Install and configure Lua from repos
# Globals:
#   LUA_DEPENDENCIES
# Arguments:
#   None
#######################################
install_lua_and_luarocks() {
  log "Installing Lua and LuaRocks from repositories"
  
  # Install Lua and LuaRocks packages
  install_packages "${LUA_DEPENDENCIES[@]}" "lua" "luarocks"
  
  # Verify installation
  if command_exists lua && command_exists luarocks; then
    local lua_version
    lua_version=$(lua -v 2>&1)
    local luarocks_version
    luarocks_version=$(luarocks --version)
    
    log "Lua installation successful: ${lua_version}"
    log "LuaRocks installation successful: ${luarocks_version}"
  else
    log "Warning: Lua and/or LuaRocks installation may have failed. Please check manually."
  fi
}

#######################################
# Install JetBrains Toolbox from AUR
# Globals:
#   JETBRAINS_INSTALL_DIR
#   JETBRAINS_SYMLINK_DIR
# Arguments:
#   None
#######################################
install_jetbrains_toolbox() {
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  # Check if JetBrains Toolbox is already installed from AUR
  if package_installed "jetbrains-toolbox"; then
    log "JetBrains Toolbox is already installed"
    return 0
  fi
  
  log "Installing JetBrains Toolbox from AUR"
  install_aur_packages "jetbrains-toolbox"
  
  # Verify installation
  if command_exists jetbrains-toolbox; then
    log "JetBrains Toolbox installed successfully"
  else
    log "Warning: JetBrains Toolbox may not have installed correctly. Please check manually."
  fi
}

#######################################
# Install Msty.app from AUR
# Globals:
#   None
# Arguments:
#   None
#######################################
install_msty_app() {
  log "Installing Msty.app from AUR"
  
  # Ensure AUR helper is installed
  if ! command_exists yay; then
    install_aur_helper
  fi
  
  # Check if Msty is already installed
  if package_installed "msty-bin"; then
    log "Msty.app is already installed"
    return 0
  fi
  
  # Install msty-bin from AUR
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  log "Installing msty-bin from AUR"
  if ! su -l "${current_user}" -c "yay -S --noconfirm msty-bin"; then
    log "Warning: Failed to install msty-bin from AUR"
    return 1
  fi
  
  log "Msty.app installed successfully"
  return 0
}

#######################################
# Install PowerShell from AUR
# Globals:
#   None
# Arguments:
#   None
#######################################
install_powershell() {
  log "Installing PowerShell from AUR"
  
  # Check if PowerShell is already installed
  if command_exists pwsh; then
    log "PowerShell is already installed"
    return 0
  fi
  
  # Ensure AUR helper is installed
  if ! command_exists yay; then
    install_aur_helper
  fi
  
  local current_user
  current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
  
  log "Installing powershell-bin from AUR using yay"
  
  # Use the NOPASSWD option for the specific user temporarily
  local sudoers_tmp="/etc/sudoers.d/10_${current_user}_temp"
  echo "${current_user} ALL=(ALL) NOPASSWD: /usr/bin/pacman" > "${sudoers_tmp}"
  chmod 440 "${sudoers_tmp}"
  
  # Build the package with yay (with --noconfirm to avoid prompts)
  if ! su -l "${current_user}" -c "yay -S powershell-bin --noconfirm"; then
    log "Standard yay installation failed, attempting alternative approach"
    
    # Alternative: Download only and then install as root
    if su -l "${current_user}" -c "cd /tmp && yay -G powershell-bin && cd /tmp/powershell-bin && makepkg -s --noconfirm"; then
      # Find the built package
      local pkg_file
      pkg_file=$(find /tmp/powershell-bin -name "*.pkg.tar.zst" | head -n 1)
      
      if [ -n "${pkg_file}" ]; then
        log "Installing built package: ${pkg_file}"
        pacman -U --noconfirm "${pkg_file}"
      else
        log "Failed to find built package file"
      fi
    else
      log "Failed to build powershell-bin package"
    fi
  fi
  
  # Remove the temporary sudoers file
  rm -f "${sudoers_tmp}"
  
  # Verify installation
  if command_exists pwsh; then
    local installed_version
    installed_version=$(pwsh --version | head -n 1)
    log "PowerShell installed successfully: ${installed_version}"
    return 0
  else
    log "Warning: PowerShell installation verification failed"
    return 1
  fi
}

#######################################
# Install 1Password from AUR
# Globals:
#   None
# Arguments:
#   None
#######################################
install_1password() {
  log "Installing 1Password from AUR"
  
  # Ensure AUR helper is installed
  if ! command_exists yay; then
    install_aur_helper
  fi
  
  # Check if 1Password is already installed
  if package_installed "1password"; then
    log "1Password is already installed"
  else
    # Install 1Password from AUR
    local current_user
    current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
    
    log "Installing 1password from AUR"
    if ! su -l "${current_user}" -c "yay -S --noconfirm 1password"; then
      log "Warning: Failed to install 1password from AUR"
    fi
  fi
  
  # Check if 1Password CLI is already installed
  if package_installed "1password-cli"; then
    log "1Password CLI is already installed"
  else
    # Install 1Password CLI from AUR
    local current_user
    current_user=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
    
    log "Installing 1password-cli from AUR"
    if ! su -l "${current_user}" -c "yay -S --noconfirm 1password-cli"; then
      log "Warning: Failed to install 1password-cli from AUR"
    fi
  fi
  
  # Verify installation
  if package_installed "1password" && package_installed "1password-cli"; then
    log "1Password and 1Password CLI installed successfully"
  else
    log "Warning: 1Password and/or 1Password CLI may not have installed correctly. Please check manually."
  fi
}

#######################################
# Perform final system update
# Globals:
#   None
# Arguments:
#   None
#######################################
perform_final_update() {
  log "Performing final system update"
  
  # Update package database and upgrade all packages
  log "Updating and upgrading all packages"
  if ! pacman -Syu --noconfirm; then
    log "Warning: Final system update encountered some issues, but continuing"
  fi
  
  # Clean up package cache (equivalent to apt-get clean)
  log "Cleaning package cache"
  if ! pacman -Sc --noconfirm; then
    log "Warning: Package cache cleanup encountered issues"
  fi
  
  log "Final system update completed"
}

#######################################
# Check if the script is being run as root
# Arguments:
#   None
# Returns:
#   0 if script is run as root, exits otherwise
#######################################
check_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root. Please use sudo."
  fi
}

#######################################
# Prompt for system restart unless auto mode is enabled
# Globals:
#   AUTO_MODE
# Arguments:
#   None
#######################################
prompt_for_restart() {
  if [[ "${AUTO_MODE}" == "true" ]]; then
    log "Running in automatic mode. System will restart in 10 seconds."
    log "Press Ctrl+C to cancel restart."
    sleep 10
    reboot
    return 0
  fi
  
  local response
  
  log "All installations and configurations are complete."
  log "It is recommended to restart your system to ensure all changes take effect."
  
  read -p "Would you like to restart now? (y/n): " -r response
  
  if [[ "${response,,}" =~ ^(y|yes)$ ]]; then
    log "System will restart in 10 seconds. Press Ctrl+C to cancel."
    sleep 10
    reboot
  else
    log "Restart skipped. Remember to restart your system later for all changes to take effect."
  fi
}

#######################################
# Main function
# Globals:
#   SYSTEM_PACKAGES
#   DEV_PACKAGES
#   UTIL_PACKAGES
#   AUR_PACKAGES
# Arguments:
#   None
#######################################
main() {
  log "Starting Arch Linux system setup script"
  
  check_root
  
  # Parse command line options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --auto|-a)
        AUTO_MODE="true"
        log "Automatic mode enabled - no interactive prompts will be shown"
        shift
        ;;
      --help|-h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --auto, -a    Run in automatic mode (no interactive prompts)"
        echo "  --help, -h    Show this help message"
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
  
  # Now make AUTO_MODE readonly after argument parsing
  readonly AUTO_MODE
  
  # Update system
  update_system
  
  # Install system packages
  log "Installing system packages"
  install_packages "${SYSTEM_PACKAGES[@]}"
  
  # Install development packages
  log "Installing development packages"
  install_packages "${DEV_PACKAGES[@]}"
  
  # Install utility packages
  log "Installing utility packages"
  install_packages "${UTIL_PACKAGES[@]}"
  
  # Install AUR helper
  install_aur_helper
  
  # Install Flatpak
  install_flatpak
  
  # Install Flatpak apps
  install_flatpak_apps
  
  # Install Docker
  install_docker
  
  # Configure Docker post-installation
  configure_docker_post_install
  
  # Install Podman
  install_podman
  
  # Install PowerShell
  install_powershell
  
  # Install and configure Lua
  install_lua_and_luarocks
  
  # Install Steam
  install_steam
  
  # Install Msty app
  install_msty_app
  
  # Install 1Password
  install_1password
  
  # Install JetBrains Toolbox
  install_jetbrains_toolbox
  
  # Install pyenv
  install_pyenv
  
  # Install mise
  install_mise
  
  # Install Neovim
  install_neovim
  
  # Configure fish shell
  configure_fish_shell
  
  # Install and Configure KVM/QEMU for virtualization
  install_kvm_libvirt
  
  # Perform final system update
  perform_final_update
  
  log "Arch Linux system setup completed successfully"
  log "Note: You may need to log out and back in for the following changes to take effect:"
  log "- Docker group membership"
  log "- pyenv initialization"
  log "- mise initialization"
  log "- Default shell change to fish"
  
  # Prompt for restart
  prompt_for_restart
}

# Execute main function
main "$@"
