#!/bin/bash

# Script to update IP address in HTML file
# Usage: ./update-ip.sh <IP_ADDRESS>

if [ -z "$1" ]; then
    echo "Usage: $0 <IP_ADDRESS>"
    echo "Example: $0 44.202.9.175"
    exit 1
fi

IP_ADDRESS="$1"

# Create backup
cp index.html index.html.backup

# Update IP in HTML (in case JavaScript doesn't work)
sed -i "s/&lt;EC2-PUBLIC-IP&gt;/$IP_ADDRESS/g" index.html

echo "✅ Updated IP address to: $IP_ADDRESS"
echo "📁 Backup created: index.html.backup"
EOF

chmod +x app/update-ip.sh