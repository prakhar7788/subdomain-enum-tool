#!/bin/bash

# ---------------
# Associated Domain Finder
# Input: Root domain (e.g. example.com)
# Output: List of associated domains
# ---------------

if [ -z "$1" ]; then
    echo "Usage: $0 <domain.com>"
    exit 1
fi

TARGET=$1
TARGET_IP=$(dig +short $TARGET | tail -n1)

echo "[*] Target Domain: $TARGET"
echo "[*] Resolving IP..."
echo "Resolved IP: $TARGET_IP"
echo

# --- Step 1: WHOIS registrant info ---
echo "[*] Extracting WHOIS registrant email..."
WHOIS_EMAIL=$(whois $TARGET | grep -Ei "Registrant Email|Admin Email|Tech Email" | head -n1 | awk '{print $NF}')

if [[ -z "$WHOIS_EMAIL" ]]; then
    echo "[!] No registrant email found (GDPR privacy likely)."
else
    echo "Registrant Email Found: $WHOIS_EMAIL"
    echo
    echo "[*] You can manually search this on:"
    echo "    https://viewdns.info/reversewhois/?q=$WHOIS_EMAIL"
    echo
fi

# --- Step 2: SSL Certificate Transparency Log (crt.sh) ---
echo "[*] Querying crt.sh for domains using same cert or name..."
curl -s "https://crt.sh/?q=%25$TARGET&output=json" | \
    jq -r '.[].name_value' | \
    sed 's/\*\.//g' | \
    sort -u | \
    grep -v "$TARGET" > temp_crt_domains.txt

echo
echo "[*] Possible associated domains from crt.sh:"
cat temp_crt_domains.txt

# --- Step 3: Reverse IP Lookup (optional) ---
if [[ -n "$TARGET_IP" ]]; then
    echo
    echo "[*] Reverse IP lookup: View this manually at:"
    echo "    https://viewdns.info/reverseip/?host=$TARGET_IP"
fi

# --- Final Output ---
echo
echo "[+] Finished."
echo "[+] Total potential associated domains found from crt.sh: $(wc -l < temp_crt_domains.txt)"

# Clean up
rm -f temp_crt_domains.txt
