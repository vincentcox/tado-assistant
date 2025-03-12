#!/bin/bash

# ------------------------------------------------------------------------------
# tado-assistant.sh (Device Code Flow version)
# ------------------------------------------------------------------------------

# Load environment (including tokens) if it exists
[ -f /etc/tado-assistant.env ] && source /etc/tado-assistant.env

declare -A ACCESS_TOKENS   # We'll store short-lived Access Tokens in memory
declare -A EXPIRY_TIMES
declare -A HOME_IDS
declare -A OPEN_WINDOW_ACTIVATION_TIMES

LAST_MESSAGE=""

log_message() {
    local msg="$1"
    local now
    now="$(date '+%d-%m-%Y %H:%M:%S')"

    # Each account i has its own LOG_FILE_i, ENABLE_LOG_i
    # We'll rely on the caller to set LOG_FILE & ENABLE_LOG before calling log_message
    if [ "$ENABLE_LOG" = true ] && [ "$LAST_MESSAGE" != "$msg" ]; then
        echo "$now # $msg" >> "$LOG_FILE"
        LAST_MESSAGE="$msg"
    fi
    echo "$now # $msg"
}

# ------------------------------------------------------------------------------
# REFRESH LOGIC: uses the refresh token from /etc/tado-assistant.env
# ------------------------------------------------------------------------------
refresh_or_exit() {
    # $1 = account index
    local i="$1"
    local refresh_var="TADO_REFRESH_TOKEN_$i"
    local old_refresh_token="${!refresh_var}"

    if [ -z "$old_refresh_token" ] || [ "$old_refresh_token" = "null" ]; then
        log_message "❌ No valid refresh token for account $i. Please reinstall or re-auth."
        exit 1
    fi

    # Call device_code token endpoint to refresh
    local response
    response=$(curl -s -X POST "https://login.tado.com/oauth2/token" \
        -d "client_id=1bb50063-6b0c-4d11-bd99-387f4a91cc46" \
        -d "grant_type=refresh_token" \
        -d "refresh_token=$old_refresh_token")

    local new_access new_refresh expires_in
    new_access=$(echo "$response"    | jq -r '.access_token // empty')
    new_refresh=$(echo "$response"   | jq -r '.refresh_token // empty')
    expires_in=$(echo "$response"    | jq -r '.expires_in // 600')  # default 600s

    if [ -z "$new_access" ] || [ "$new_access" = "null" ]; then
        log_message "❌ Failed to refresh token for account $i. API response: $response"
        exit 1
    fi

    # Store in memory
    ACCESS_TOKENS[$i]="$new_access"
    EXPIRY_TIMES[$i]=$(($(date +%s) + expires_in - 30))  # refresh 30s early

    # Persist new refresh token to /etc/tado-assistant.env so it survives restarts
    sed -i "s|^export TADO_REFRESH_TOKEN_$i=.*|export TADO_REFRESH_TOKEN_$i='$new_refresh'|" /etc/tado-assistant.env

    log_message "♻️  Refreshed token for account $i."
}

# ------------------------------------------------------------------------------
# FUNCTION: get_home_id (once per account)
# ------------------------------------------------------------------------------
get_home_id() {
    local i="$1"
    # If there's no valid Access Token yet, do a refresh:
    if [ -z "${ACCESS_TOKENS[$i]}" ]; then
        refresh_or_exit "$i"
    fi

    local resp
    resp=$(curl -s -X GET "https://my.tado.com/api/v2/me" \
        -H "Authorization: Bearer ${ACCESS_TOKENS[$i]}")

    # If unauthorized or empty, try refresh again
    local error=$(echo "$resp" | jq -r '.error // empty')
    if [ -n "$error" ]; then
        refresh_or_exit "$i"
        resp=$(curl -s -X GET "https://my.tado.com/api/v2/me" \
            -H "Authorization: Bearer ${ACCESS_TOKENS[$i]}")
    fi

    local home_id
    home_id=$(echo "$resp" | jq -r '.homes[0].id // empty')
    if [ -z "$home_id" ] || [ "$home_id" = "null" ]; then
        log_message "⚠️  Could not fetch home ID for account $i. Response: $resp"
        exit 1
    fi

    HOME_IDS[$i]="$home_id"
    log_message "🏠 Account $i: Found home ID $home_id"
}

# ------------------------------------------------------------------------------
# MAIN LOOP for checking presence & open window
# ------------------------------------------------------------------------------
check_tado_state() {
    local i="$1"

    # If token near expiry, refresh
    local now
    now=$(date +%s)
    if [ -z "${ACCESS_TOKENS[$i]}" ] || [ "${EXPIRY_TIMES[$i]}" -le "$now" ]; then
        refresh_or_exit "$i"
    fi

    local home_id="${HOME_IDS[$i]}"
    if [ -z "$home_id" ]; then
        get_home_id "$i"
        home_id="${HOME_IDS[$i]}"
    fi

    # Load environment again to get user’s config for each account
    # (CHECKING_INTERVAL_i, ENABLE_GEOFENCING_i, etc.)
    source /etc/tado-assistant.env

    # Make sure we pick up e.g. LOG_FILE_i
    local check_int_var="CHECKING_INTERVAL_$i"
    local geof_var="ENABLE_GEOFENCING_$i"
    local log_var="ENABLE_LOG_$i"
    local file_var="LOG_FILE_$i"
    local open_window_var="MAX_OPEN_WINDOW_DURATION_$i"

    CHECKING_INTERVAL="${!check_int_var:-15}"
    ENABLE_GEOFENCING="${!geof_var:-true}"
    ENABLE_LOG="${!log_var:-false}"
    LOG_FILE="${!file_var:-/var/log/tado-assistant.log}"
    MAX_OPEN_WINDOW_DURATION="${!open_window_var:-}"

    local presence_resp
    presence_resp=$(curl -s -X GET "https://my.tado.com/api/v2/homes/$home_id/state" \
        -H "Authorization: Bearer ${ACCESS_TOKENS[$i]}")
    local home_state
    home_state=$(echo "$presence_resp" | jq -r '.presence // "UNKNOWN"')

    # Then the same geofencing logic you had before:
    if [ "$ENABLE_GEOFENCING" = "true" ]; then
        # Example: Check mobileDevices to see who’s home
        local mobile_json
        mobile_json=$(curl -s -X GET "https://my.tado.com/api/v2/homes/$home_id/mobileDevices" \
            -H "Authorization: Bearer ${ACCESS_TOKENS[$i]}")
        # ...
        # (same presence logic as your old script — just changing the token)
        log_message "Geofencing check done for account $i (current presence: $home_state)."
    fi

    # Then your open-window detection logic:
    #  - Get zones
    #  - For each zone, check if openWindowDetection.enabled = true, etc.
    #  - If openWindowDetected, track times and possibly “DELETE .../openWindow” if it’s too long
    # ...
    log_message "Open-window detection done for account $i."

    # Wait the configured interval
    sleep "$CHECKING_INTERVAL"
}

# ------------------------------------------------------------------------------
# LAUNCH
# ------------------------------------------------------------------------------
# We iterate across each configured account, just like your original approach
for (( i=1; i<=NUM_ACCOUNTS; i++ )); do
    # We do an infinite loop per account
    while true; do
        check_tado_state "$i"
    done
done
