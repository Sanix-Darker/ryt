#!/bin/bash

# Set your OAuth 2.0 client ID and client secret
CLIENT_ID="YOUR_CLIENT_ID"
CLIENT_SECRET="YOUR_CLIENT_SECRET"

# Function to install yt-dlp
function install_yt_dlp() {
    if ! command -v yt-dlp &> /dev/null; then
        echo "Installing yt-dlp..."
        cd /tmp || exit
        wget https://github.com/yt-dlp/yt-dlp/releases/download/2023.12.30/yt-dlp_linux
        sudo chmod +x ./yt-dlp_linux && sudo mv ./yt-dlp_linux /usr/bin/yt-dlp
        cd - || exit
    else
        echo "yt-dlp is already installed."
    fi
}

# Install required packages if not already installed
function install_dependencies() {

    local packages=("rofi" "jq" "curl" "mpv")
    local missing_packages=()

    for package in "${packages[@]}"; do
        if ! dpkg -s "$package" &> /dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        sudo apt-get update -y
        sudo apt-get install "${missing_packages[@]}" -y
    fi

    # Install yt-dlp
    install_yt_dlp
}

# Get access token using OAuth 2.0
function get_access_token() {
    local response
    response=$(curl -s -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$REFRESH_TOKEN&grant_type=refresh_token" https://www.googleapis.com/oauth2/v4/token)
    export YT_ACCESS_TOKEN=$(jq -r '.access_token' <<< "$response")
}

# Get YouTube recommendations
function get_recommendations() {
    local response
    response=$(curl -s "https://www.googleapis.com/youtube/v3/videos?part=snippet&myRating=like&maxResults=10&access_token=$YT_ACCESS_TOKEN")
    echo "$response"
}

# Extract video titles and thumbnails
function parse_videos() {
    local data="$1"
    jq -r '.items[] | "\(.snippet.title) | \(.snippet.thumbnails.default.url)"' <<< "$data"
}

# Main function
function main() {
    get_access_token
    local videos
    videos=$(get_recommendations)
    local selected_video
    selected_video=$(parse_videos "$videos" | rofi -dmenu -i -p "Select a video:")

    if [[ -n "$selected_video" ]]; then
        local video_url
        video_url=$(echo "$selected_video" | awk -F ' | ' '{print $NF}')
        yt-dlp -o - "$video_url" | mpv -
    fi
}

install_dependencies && main
