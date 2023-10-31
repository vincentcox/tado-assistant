#!/bin/bash
echo "WARNING: This script requires root privileges. Please review the script before proceeding."
# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run this script as root or with sudo privileges."
   exit 1
fi

# 1. Error Handling
set -e

# 2. Detect the default shell and its configuration file
SHELL_CONFIG="$HOME/.bashrc"
case $SHELL in
    */zsh)
        SHELL_CONFIG="$HOME/.zshrc"
        ;;
    */bash)
        SHELL_CONFIG="$HOME/.bashrc"
        ;;
    # Add other shells as needed
esac

# 1. Install Dependencies
install_dependencies() {
    echo "Installing dependencies..."

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Detecting the distribution
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
        fi

        # Check if curl and jq are installed
        if ! command -v curl &> /dev/null; then
            NEED_CURL=1
        fi
        if ! command -v jq &> /dev/null; then
            NEED_JQ=1
        fi

        case $DISTRO in
            debian|ubuntu)
                [[ $NEED_CURL ]] && sudo apt-get update && sudo apt-get install -y curl
                [[ $NEED_JQ ]] && sudo apt-get update && sudo apt-get install -y jq
                ;;
            fedora|centos|rhel)
                [[ $NEED_CURL ]] && sudo yum install -y curl
                [[ $NEED_JQ ]] && sudo yum install -y jq
                ;;
            arch|manjaro)
                [[ $NEED_CURL || $NEED_JQ ]] && sudo pacman -Sy
                [[ $NEED_CURL ]] && sudo pacman -S curl
                [[ $NEED_JQ ]] && sudo pacman -S jq
                ;;
            suse|opensuse*)
                [[ $NEED_CURL ]] && sudo zypper install curl
                [[ $NEED_JQ ]] && sudo zypper install jq
                ;;
            *)
                echo "Unsupported Linux distribution"
                exit 1
                ;;
        esac

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command -v brew &> /dev/null; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        if ! command -v curl &> /dev/null; then
            brew install curl
        fi
        if ! command -v jq &> /dev/null; then
            brew install jq
        fi
    else
        echo "Unsupported OS"
        exit 1
    fi
}

# 2. Set Environment Variables
set_env_variables() {
    echo "Setting up environment variables..."

    read -p "Enter TADO_USERNAME: " TADO_USERNAME
    read -p "Enter TADO_PASSWORD: " TADO_PASSWORD
    read -p "Enter CHECKING_INTERVAL (default: 10): " CHECKING_INTERVAL
    read -p "Enable log? (true/false, default: false): " ENABLE_LOG
    read -p "Enter log file path (default: /var/log/tado-assistant.log): " LOG_FILE

    # Avoid duplicating entries
    grep -q "TADO_USERNAME" "$SHELL_CONFIG" || echo "export TADO_USERNAME=$TADO_USERNAME" >> "$SHELL_CONFIG"
    grep -q "TADO_PASSWORD" "$SHELL_CONFIG" || echo "export TADO_PASSWORD=$TADO_PASSWORD" >> "$SHELL_CONFIG"
    grep -q "CHECKING_INTERVAL" "$SHELL_CONFIG" || echo "export CHECKING_INTERVAL=${CHECKING_INTERVAL:-10}" >> "$SHELL_CONFIG"
    grep -q "ENABLE_LOG" "$SHELL_CONFIG" || echo "export ENABLE_LOG=${ENABLE_LOG:-false}" >> "$SHELL_CONFIG"
    grep -q "LOG_FILE" "$SHELL_CONFIG" || echo "export LOG_FILE=${LOG_FILE:-/var/log/tado-assistant.log}" >> "$SHELL_CONFIG"
}

# 3. Set up as Service
setup_service() {
    echo "Setting up the service..."

    SCRIPT_PATH="/usr/local/bin/tado-assistant.sh"
    cp "$(dirname "$0")/tado-assistant.sh" "$SCRIPT_PATH"
    chmod +x $SCRIPT_PATH

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        SERVICE_CONTENT="[Unit]
Description=Tado Assistant Service

[Service]
ExecStart=$SCRIPT_PATH
User=$(whoami)
Restart=always

[Install]
WantedBy=multi-user.target"

        echo "$SERVICE_CONTENT" | sudo tee /etc/systemd/system/tado-assistant.service > /dev/null
        sudo systemctl enable tado-assistant.service
        sudo systemctl start tado-assistant.service

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        LAUNCHD_CONTENT="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>com.user.tadoassistant</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>"

        echo "$LAUNCHD_CONTENT" > ~/Library/LaunchAgents/com.user.tadoassistant.plist
        launchctl load ~/Library/LaunchAgents/com.user.tadoassistant.plist
    fi
}

install_dependencies
set_env_variables
setup_service
echo "Tado Assistant has been successfully installed and started!"