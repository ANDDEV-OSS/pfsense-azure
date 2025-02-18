#!/bin/sh

# File location
CONFIG_FILE="/cf/conf/config.xml"

# Check if the file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Backup the original file
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "Backup created at $BACKUP_FILE"

# Define a tab character
TAB="$(printf '\t')"

# Check if the <system> block exists
if grep -q "<system>" "$CONFIG_FILE"; then
    # Check if <enableserial></enableserial> exists
    if ! grep -q "<enableserial></enableserial>" "$CONFIG_FILE"; then
        # Insert <enableserial></enableserial> with proper tab and newline
        sed -i '' "/<system>/a\\
${TAB}${TAB}<enableserial></enableserial>\\
" "$CONFIG_FILE"
        echo "<enableserial></enableserial> added inside <system> block with proper indentation."
    fi

    # Check if <serialspeed>115200</serialspeed> exists
    if ! grep -q "<serialspeed>115200</serialspeed>" "$CONFIG_FILE"; then
        # Insert <serialspeed>115200</serialspeed> before <enableserial></enableserial> with proper tab and newline
        sed -i '' "/<enableserial><\/enableserial>/i\\
${TAB}${TAB}<serialspeed>115200</serialspeed>\\
" "$CONFIG_FILE"
        echo "<serialspeed>115200</serialspeed> added before <enableserial></enableserial> in <system> block with proper indentation."
    else
        echo "<serialspeed>115200</serialspeed> already exists in the <system> block."
    fi

    # Check if <nohttpreferercheck> exists
    if ! grep -q "<nohttpreferercheck></nohttpreferercheck>" "$CONFIG_FILE"; then
        # Insert <nohttpreferercheck></nohttpreferercheck> before </webgui> with proper tab and newline
        sed -i '' "/<\/webgui>/i\\
${TAB}${TAB}${TAB}<nohttpreferercheck></nohttpreferercheck>\\
" "$CONFIG_FILE"
        echo "<nohttpreferercheck></nohttpreferercheck> added before </webgui> in <system> block with proper indentation."
    else
        echo "<nohttpreferercheck></nohttpreferercheck> already exists in the <webgui> block."
    fi

else
    echo "Error: <system> block not found in $CONFIG_FILE"
    exit 1
fi