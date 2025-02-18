#!/bin/sh

# File to edit
FILE="/etc/devd/hyperv.conf"

# Backup the original file
cp "$FILE" "${FILE}.bak"

# Use awk to selectively comment out matching blocks
awk '
BEGIN {in_block = 0; buffer = ""; match_required = 0;}
/^notify 10 {/ {
    in_block = 1;
    buffer = "";
    match_required = 0; # Reset match flag for the new block
}
in_block {
    buffer = buffer $0 "\n"; # Accumulate lines in the buffer
    if ($0 ~ /hyperv\/hyperv_vfattach/ || $0 ~ /hyperv\/hyperv_vfup/) {
        match_required = 1; # Set the flag if the block matches the requirement
    }
    if ($0 ~ /^};/) { # End of block
        if (match_required) {
            # Comment out the block if it contains the required match
            split(buffer, lines, "\n");
            for (i in lines) {
                if (lines[i] != "") {
                    printf "#%s\n", lines[i];
                }
            }
        } else {
            # Print the block as-is
            printf "%s", buffer;
        }
        buffer = ""; # Reset buffer
        in_block = 0;
    }
    next;
}
{ print; } # Print lines outside blocks
' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"

echo "Relevant blocks commented out in $FILE. Original file backed up as ${FILE}.bak."