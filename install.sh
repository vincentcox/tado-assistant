#!/bin/bash
echo "WARNING: This script requires root privileges. Please review the script before proceeding."
# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run this script as root or with sudo privileges."
   exit 1
fi

# 1. Install Dependencies
install_dependencies() {
    echo "Installing dependencies..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
        fi

        # We need curl + jq
        NEED_CURL=0
        NEED_JQ=0
        if ! command -v curl &> /dev/null; then
            NEED_CURL=1
        fi
        if ! command -v jq &> /dev/null; then
            NEED_JQ=1
        fi

        case $DISTRO in
            debian|ubuntu|raspbian)
                if [[ $NEED_CURL -eq 1 ]] || [[ $NEED_JQ -eq 1 ]]; then
                    sudo apt-get update
                fi
                [[ $NEED_CURL -eq 1 ]] && sudo apt-get install -y curl
                [[ $NEED_JQ -eq 1 ]] && sudo apt-get install -y jq
                ;;
            fedora|centos|rhel|ol)
                [[ $NEED_CURL -eq 1 ]] && sudo yum install -y curl
                [[ $NEED_JQ -eq 1 ]] && sudo yum install -y jq
                ;;
            arch|manjaro)
                [[ $NEED_CURL -eq 1 || $NEED_JQ -eq 1 ]] && sudo pacman -Sy
                [[ $NEED_CURL -eq 1 ]] && sudo pacman -S curl
                [[ $NEED_JQ -eq 1 ]] && sudo pacman -S jq
                ;;
            suse|opensuse*)
                [[ $NEED_CURL -eq 1 ]] && sudo zypper install -y curl
                [[ $NEED_JQ -eq 1 ]] && sudo zypper install -y jq
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

# 2. Prompt user for # of tado° accounts. Device code flow for each.
set_env_variables() {
    echo "Setting up environment variables for multiple Tado accounts..."

    read -rp "Enter the number of Tado accounts: " NUM_ACCOUNTS
    echo "export NUM_ACCOUNTS=$NUM_ACCOUNTS" > /etc/tado-assistant.env

    # For each account, we will:
    #   1) Request a device code from tado°
    #   2) Prompt user to visit the verification link
    #   3) Poll until success => store refresh_token in /etc/tado-assistant.env
    # We do NOT store username/password.

    i=1
    while [ "$i" -le "$NUM_ACCOUNTS" ]; do
        echo ""
        echo "==========================="
        echo "Configuring tado° account $i via Device Code Flow..."
        echo "Requesting device code from tado°..."

        # request device code from new endpoint:
        #   https://login.tado.com/oauth2/device_authorize
        # client_id is 1bb50063-6b0c-4d11-bd99-387f4a91cc46
        device_response=$(curl -s -X POST "https://login.tado.com/oauth2/device_authorize" \
            -d "client_id=1bb50063-6b0c-4d11-bd99-387f4a91cc46" \
            -d "scope=offline_access")

        device_code=$(echo "$device_response" | jq -r '.device_code')
        user_code=$(echo "$device_response" | jq -r '.user_code')
        verification_uri_complete=$(echo "$device_response" | jq -r '.verification_uri_complete')
        interval=$(echo "$device_response" | jq -r '.interval')
        expires_in=$(echo "$device_response" | jq -r '.expires_in')

        if [[ "$device_code" == "null" || -z "$device_code" ]]; then
            echo "Error: Unable to get device_code from tado°. Response:"
            echo "$device_response"
            exit 1
        fi

        echo "Account $i: Please open the following URL in your browser to authorize:"
        echo "  $verification_uri_complete"
        echo "User code (should auto-fill on that page): $user_code"
        echo "You have about $expires_in seconds to complete it before the code expires."

        # Wait for user to press enter (optional, but friendlier)
        read -rp "Press ENTER once you've approved access in the browser..."

        echo "Polling tado° for the token. Polling every $interval seconds until success..."

        access_token=""
        refresh_token=""
        pollStart=$(date +%s)

        # We poll for up to 'expires_in' seconds
        while :; do
            pollResponse=$(curl -s -X POST "https://login.tado.com/oauth2/token" \
                -d "client_id=1bb50063-6b0c-4d11-bd99-387f4a91cc46" \
                -d "device_code=$device_code" \
                -d "grant_type=urn:ietf:params:oauth:grant-type:device_code")

            errorVal=$(echo "$pollResponse" | jq -r '.error // empty')
            if [ "$errorVal" == "authorization_pending" ]; then
                # Not authorized yet; wait and poll again
                sleep "$interval"
            elif [ "$errorVal" == "access_denied" ]; then
                echo "You denied the request or took too long. Try again."
                exit 1
            else
                # Possibly success
                access_token=$(echo "$pollResponse" | jq -r '.access_token // empty')
                refresh_token=$(echo "$pollResponse" | jq -r '.refresh_token // empty')
                if [ -n "$access_token" ] && [ "$access_token" != "null" ]; then
                    echo "Received Access Token + Refresh Token!"
                    break
                fi
                # Some other error
                echo "Error from tado°: $pollResponse"
                exit 1
            fi

            # Timeout if user is not done in e.g. expires_in + 30
            now=$(date +%s)
            elapsed=$(( now - pollStart ))
            if [ "$elapsed" -ge $(( expires_in + 30 )) ]; then
                echo "Timed out waiting for user to authorize. Exiting."
                exit 1
            fi
        done

        # Now we have an access_token + refresh_token
        # We only truly *need* the refresh_token for ongoing operation,
        # because the script can always refresh on startup.
        # We'll store both in /etc/tado-assistant.env
        echo "export TADO_ACCESS_TOKEN_$i='$access_token'"    >> /etc/tado-assistant.env
        echo "export TADO_REFRESH_TOKEN_$i='$refresh_token'"  >> /etc/tado-assistant.env

        # Ask user for optional config (interval, logs, etc.) as before:
        read -rp "Enter CHECKING_INTERVAL for account $i (default: 15): " CHECKING_INTERVAL
        read -rp "Enter MAX_OPEN_WINDOW_DURATION for account $i (in seconds): " MAX_OPEN_WINDOW_DURATION
        read -rp "Enable geofencing check for account $i? (true/false, default: true): " ENABLE_GEOFENCING
        read -rp "Enable log for account $i? (true/false, default: false): " ENABLE_LOG
        read -rp "Enter log file path for account $i (default: /var/log/tado-assistant.log): " LOG_FILE

        echo "export CHECKING_INTERVAL_$i='${CHECKING_INTERVAL:-15}'"          >> /etc/tado-assistant.env
        echo "export MAX_OPEN_WINDOW_DURATION_$i='${MAX_OPEN_WINDOW_DURATION}'" >> /etc/tado-assistant.env
        echo "export ENABLE_GEOFENCING_$i='${ENABLE_GEOFENCING:-true}'"         >> /etc/tado-assistant.env
        echo "export ENABLE_LOG_$i='${ENABLE_LOG:-false}'"                      >> /etc/tado-assistant.env
        echo "export LOG_FILE_$i='${LOG_FILE:-/var/log/tado-assistant.log}'"    >> /etc/tado-assistant.env

        i=$((i+1))
    done

    chmod 600 /etc/tado-assistant.env
    echo "All accounts configured. Device Code Flow tokens saved to /etc/tado-assistant.env."
}

# 3. Service setup (unchanged from your original) - just ensure you replace references to old script if needed
setup_service() {
    echo "Setting up the service..."

    SCRIPT_PATH="/usr/local/bin/tado-assistant.sh"
    cp "$(dirname "$0")/tado-assistant.sh" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"

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
        sudo systemctl restart tado-assistant.service

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

# 4. Optionally: logic for --update or --force-update can remain as is.
#    Just ensure your remote git has the updated code with device-flow.

if [[ "$1" == "--update" ]] || [[ "$1" == "--force-update" ]]; then
    echo "Update logic here (unchanged from your original)."
    exit 0
fi

install_dependencies
set_env_variables
setup_service
echo "Tado Assistant has been successfully installed (device code flow)."
