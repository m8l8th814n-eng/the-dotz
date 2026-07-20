#!/bin/bash
#
# Sound Open Firmware SDK installer.
#
# This scripts install the SOF SDK in the users directory of choice and downloads
# and installs dependecies required to build and deploy firmware images, tooling
# and debug scripts.
#

# default workspace directory, can be overriden on script cmd line.
workspace="$HOME/work/sof"

# download and install system dependecies required for SDK, cmd line option.
install_system=false

# download and install staging modules. cmd line option.
install_staging=false

# download and build QEMU ace support. cmd line option.
install_qemu=false

# function to ask yes/no questions
ask_prompt() {
    local prompt_text="$1"
    local default_ans="$2"
    local response
    
    if [ "$default_ans" = "y" ]; then
        prompt_text="$prompt_text [Y/n]: "
    else
        prompt_text="$prompt_text [y/N]: "
    fi
    
    read -r -p "$prompt_text" response
    response_lower=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$response_lower" ]; then
        response_lower="$default_ans"
    fi
    
    if [ "$response_lower" = "y" ]; then
        return 0
    else
        return 1
    fi
}

# function to display help/usage information
usage() {
    echo "Usage: $0 [-w <workspace directory>]"
    echo "Options:"
    echo "  -w              Specify SOF workspace directory. $HOME/work/sof is default."
    echo "  -i              Install system package dependecies. Needs sudo."
    echo "  -s              Install staging source code dependecies into workspace."
    echo "  -q              Clone and build QEMU ace support."
    echo "  -h              Display this help message."
    echo "  -v              Reinstall python venv and west."
    exit 1
}

# clone all SOF SDK source repositories.
clone_repos() {
	echo "*** Setting up workspace and cloning repositories."
	mkdir -p ${workspace}
	cd ${workspace}
	if [ ! -d .git ]; then
		git clone --progress https://github.com/thesofproject/vscode-workspace.git tmp_workspace
		cp -r tmp_workspace/. . 2>/dev/null || true
		rm -rf tmp_workspace
	fi
	[ ! -d sof ] && git clone --progress --recursive https://github.com/thesofproject/sof.git
	[ ! -d sof-test ] && git clone --progress https://github.com/thesofproject/sof-test.git
	[ ! -d sof-docs ] && git clone --progress https://github.com/thesofproject/sof-docs.git
	[ ! -d sof-bin ] && git clone --progress https://github.com/thesofproject/sof-bin.git
}

# we also need to install a lot of python packages for SDK
install_venv() {
	echo "*** Setting up python virtual environment."
	python3 -m venv .venv
	source .venv/bin/activate

	# install python packages and setup west
	echo "*** Installing and initialising west and zephyr"
	pip install west
	west init .
	west zephyr-export
	west packages pip --install

	# install all the tooling required to build documentation
	echo "*** Install SOF documentation tooling."
	pip install -r sof-docs/scripts/requirements.txt

	# now that Zephyr west packages are installed, install SOF SDK
	echo "*** Install SOF SDK ingredients."
	rm -fr .west
	west init -l sof
	west update
}

# install the Zephyr SDK
install_zephyr_sdk() {
    local version="$1"
	echo "*** Installing Zephyr SDK Toolchain"
	cd zephyr
	if [ -n "$version" ]; then
	    west sdk install --version "$version"
	else
	    west sdk install
	fi
	cd ..
}

# SOF SDK needs an environment variable
setup_environment() {
	echo "*** Setting SOF_WORKSPACE environment variable."
	export SOF_WORKSPACE=${workspace}
}

# Clone and build QEMU for ace target
build_qemu() {
	echo "*** Setting up QEMU ace support."
	cd ${workspace}
	git clone -b intel_ace https://github.com/thesofproject/qemu.git
	cd qemu
	./configure --target-list=xtensa-softmmu
	make -j $(nproc)
	cd ..
}

# Test SDK install by building all SOF targets with Zephyr SDK
do_test_builds() {
	echo "*** Now building all platforms supported by Zephyr SDK."
	./sof/scripts/xtensa-build-zephyr.py -a

	# Now build SOF userspace tools.
	echo "***  Now Build tools."
	./sof/scripts/build-tools.sh -A
	./sof/scripts/build-tools.sh
	./sof/scripts/rebuild-testbench.sh
}

# --- Option Parsing with getopts ---
while getopts "w:hiqsv" OPTION; do
    case "${OPTION}" in
        i)
            # Option -v (verbose)
            install_system=true
            echo "Installing system packages."
            ;;
        q)
            # Option -q (QEMU)
            install_qemu=true
            echo "Installing QEMU ace support."
            ;;
        s)
            # Option -f (force)
            install_staging=true
             echo "Installing staging sources."
            ;;
        w)
            # Option workspace
            workspace="${OPTARG}"
            ;;
        h)
            # Option -h (help)
            usage
            ;;
        v)
            # Option -v reinstall venv
            install_venv
            ;;
        \?)
            # Unknown option
            echo "Error: Invalid option: -${OPTARG}" >&2 # Output error to stderr
            usage
            ;;
    esac
done

# install system dependencies.
# TODO: this is for latest Ubuntu, but need similar list for RHEL/Fedora.
install_system_deps() {
    echo "*** Installing system dependencies (needs sudo)."
    sudo apt install --no-install-recommends git cmake ninja-build gperf \
        ccache dfu-util device-tree-compiler wget \
        python3-dev python3-pip python3-setuptools python3-tk python3-wheel xz-utils file \
        make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1 default-jre python3-venv \
         octave libssl-dev libtool gettext libncurses-dev
}

# Start of SDK installation
echo "*** SOF SDK installer. ***"

if ! ask_prompt "Use installation workspace (${workspace})?" "y"; then
    while true; do
        read -r -p "Enter new installation workspace path (or press Enter to exit): " new_workspace
        if [ -z "$new_workspace" ]; then
            echo "Exiting."
            exit 1
        fi
        # Expand ~ to $HOME
        workspace="${new_workspace/#\~/$HOME}"
        if ask_prompt "Is ${workspace} correct?" "y"; then
            break
        fi
    done
fi
echo "*** Installation workspace is set to: ${workspace}"

# 1. System dependencies
echo ""
echo "--- Step 1: System Dependencies ---"
echo "These are OS-level packages (cmake, ninja, dtc, python3, etc.) required to build the SOF firmware and tools."
echo "Installing them requires sudo privileges."
if command -v cmake >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1 && command -v dtc >/dev/null 2>&1; then
    if ask_prompt "System dependencies seem to be installed. Reinstall/Update?" "n"; then
        install_system_deps
    fi
else
    def_sys="y"
    [ "$install_system" = "true" ] && def_sys="y"
    if ask_prompt "System dependencies missing. Install now (needs sudo)?" "$def_sys"; then
        install_system_deps
    fi
fi

# 2. Workspace and Repos
echo ""
echo "--- Step 2: SOF Workspaces and Repositories ---"
echo "This step creates your local development environment (${workspace})."
echo "It clones the core SOF repositories (sof, sof-test, sof-docs, sof-bin) needed for firmware development."
mkdir -p "${workspace}"
cd "${workspace}"

if [ -d "sof" ] && [ -d "sof-test" ]; then
    if ask_prompt "SOF repositories already cloned in ${workspace}. Reinstall (will delete existing repos)?" "n"; then
        echo "*** Removing existing repositories in ${workspace}..."
        rm -rf "sof" "sof-test" "sof-docs" "sof-bin" ".vscode" ".git"
        clone_repos
    fi
else
    if ask_prompt "Clone SOF repositories to ${workspace}?" "y"; then
        clone_repos
    fi
fi

# 3. Python venv and Zephyr
echo ""
echo "--- Step 3: Python Environment & Zephyr ---"
echo "This creates an isolated Python virtual environment (.venv) to avoid polluting your system packages."
echo "It also installs 'west' (Zephyr's meta-tool) and initializes the Zephyr OS tree and its dependencies."
if [ -d ".venv" ] && [ -d "zephyr" ]; then
    if ask_prompt "Python venv and Zephyr workspace already exist. Reinstall?" "n"; then
        echo "*** Removing existing venv and Zephyr packages..."
        rm -rf .venv .west zephyr modules bootloader tools
        install_venv
    fi
else
    if ask_prompt "Install Python venv and Zephyr workspace?" "y"; then
        install_venv
    fi
fi

# 4. Zephyr SDK
echo ""
echo "--- Step 4: Zephyr SDK Toolchain ---"
echo "The Zephyr SDK provides the cross-compilers and host tools required to build firmware for target architectures."
zephyr_sdk_installed=false
installed_sdk_version=""

if [ -n "$ZEPHYR_SDK_INSTALL_DIR" ] && [ -d "$ZEPHYR_SDK_INSTALL_DIR" ] && [ -f "$ZEPHYR_SDK_INSTALL_DIR/sdk_version" ]; then
    zephyr_sdk_installed=true
    installed_sdk_version=$(cat "$ZEPHYR_SDK_INSTALL_DIR/sdk_version")
else
    # Find highest version installed
    installed_sdk_version=$(
        for dir in ~/zephyr-sdk-* ~/.local/zephyr-sdk-* /opt/zephyr-sdk-*; do
            if [ -f "$dir/sdk_version" ]; then
                cat "$dir/sdk_version"
            fi
        done | sort -V | tail -n1
    )
    if [ -n "$installed_sdk_version" ]; then
        zephyr_sdk_installed=true
    fi
fi

echo "*** Checking for latest Zephyr SDK version..."
# Fetch the latest version from GitHub API
latest_sdk_json=$(curl -s https://api.github.com/repos/zephyrproject-rtos/sdk-ng/releases/latest || echo "")
latest_sdk_version=$(echo "$latest_sdk_json" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/' || echo "")
if [ -z "$latest_sdk_version" ]; then
    latest_sdk_version="unknown"
    echo "Could not fetch latest Zephyr SDK version from GitHub."
fi

if [ "$zephyr_sdk_installed" = true ]; then
    echo "Installed Zephyr SDK version: $installed_sdk_version"
    echo "Latest Zephyr SDK version   : $latest_sdk_version"
    
    if [ "$latest_sdk_version" != "unknown" ]; then
        highest=$(printf "%s\n%s" "$installed_sdk_version" "$latest_sdk_version" | sort -V | tail -n1)
        if [ "$highest" = "$latest_sdk_version" ] && [ "$installed_sdk_version" != "$latest_sdk_version" ]; then
            if ask_prompt "A newer Zephyr SDK ($latest_sdk_version) is available. Install it?" "y"; then
                install_zephyr_sdk "$latest_sdk_version"
            fi
        else
            if ask_prompt "Zephyr SDK ($installed_sdk_version) is up-to-date. Reinstall?" "n"; then
                install_zephyr_sdk "$installed_sdk_version"
            fi
        fi
    else
        if ask_prompt "Zephyr SDK ($installed_sdk_version) is installed. Reinstall?" "n"; then
            install_zephyr_sdk "$installed_sdk_version"
        fi
    fi
else
    echo "Latest Zephyr SDK version   : $latest_sdk_version"
    if ask_prompt "Install Zephyr SDK Toolchain?" "y"; then
        if [ "$latest_sdk_version" != "unknown" ]; then
            install_zephyr_sdk "$latest_sdk_version"
        else
            install_zephyr_sdk
        fi
    fi
fi

# 5. Environment
echo ""
echo "--- Step 5: Environment Setup ---"
echo "This exports necessary environment variables (like SOF_WORKSPACE) for the build scripts."
setup_environment

# 6. QEMU
echo ""
echo "--- Step 6: QEMU Ace Support ---"
echo "QEMU allows you to simulate and test firmware execution locally without needing physical hardware."
echo "This step clones and builds a specialized QEMU fork (intel_ace) for SOF testing."
if [ -d "qemu" ]; then
    if ask_prompt "QEMU already exists in workspace. Rebuild?" "n"; then
        echo "*** Removing existing QEMU..."
        rm -rf qemu
        build_qemu
    fi
else
    def_qemu="y"
    [ "$install_qemu" = "true" ] && def_qemu="y"
    if ask_prompt "Clone and build QEMU ace support?" "$def_qemu"; then
        build_qemu
    fi
fi

# 7. Test Builds
echo ""
echo "--- Step 7: Test Builds ---"
echo "This final step verifies your installation by compiling the firmware for several target platforms and building the SOF userspace tools."
echo "It effectively ensures that your environment is fully working."
if ask_prompt "Do test builds (build all platforms & userspace tools)?" "y"; then
    do_test_builds
fi

# Complete !
echo "*** All done !"
