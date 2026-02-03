#!/bin/bash

# ---------------------------
# Infrastructure Recon Script
# Tools: assetfinder, subfinder, sublist3r, crt.sh, reverse IP, dnsx, httpx, gobuster
# Optional Wordlist Brute Force
# ---------------------------

if [ -z "$1" ]; then
    echo "Usage: $0 <domain> [optional: /path/to/wordlist.txt]"
    exit 1
fi

TARGET=$1
WORDLIST=$2
DEFAULT_WORDLIST="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"

if [ -z "$WORDLIST" ]; then
    if [ -f "$DEFAULT_WORDLIST" ]; then
        WORDLIST="$DEFAULT_WORDLIST"
    else
        WORDLIST=""
    fi
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="infra_recon_${TARGET}_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"
RESULT_FILE="$OUTPUT_DIR/result.txt"
UNIQUE_FILE="$OUTPUT_DIR/unique_subdomains.txt"

echo "[+] Starting Recon on: $TARGET"
echo "[+] Output will be saved in: $RESULT_FILE"
echo "Infrastructure Recon Report for $TARGET" > "$RESULT_FILE"
echo "Generated on: $(date)" >> "$RESULT_FILE"
echo "----------------------------------------" >> "$RESULT_FILE"

# Step 1: Resolve IP address
echo "[*] Resolving IP address..."
IP=$(dig +short "$TARGET" | tail -n1)
echo -e "\n[IP Address]" >> "$RESULT_FILE"
if [ -z "$IP" ]; then
    echo "[-] Could not resolve IP address for $TARGET"
    echo "Unresolved" >> "$RESULT_FILE"
else
    echo "$IP" >> "$RESULT_FILE"
fi

# Step 2: Reverse IP Lookup
if [ -n "$IP" ]; then
    echo "[*] Reverse IP Lookup (ViewDNS)..."
    curl -s "https://viewdns.info/reverseip/?host=${IP}&t=1" -o "$OUTPUT_DIR/viewdns.html"
    DOMAINS=$(grep -oP '(?<=<td>)[a-zA-Z0-9.-]+\.[a-z]{2,}(?=</td>)' "$OUTPUT_DIR/viewdns.html" | sort -u)
    echo -e "\n[Reverse IP Domains]" >> "$RESULT_FILE"
    echo "$DOMAINS" >> "$RESULT_FILE"
    echo "$DOMAINS" > "$OUTPUT_DIR/reverseip.txt"
fi

# Step 3: crt.sh Certificates
echo "[*] Checking Certificate Transparency Logs (crt.sh)..."
curl -s "https://crt.sh/?q=%25.${TARGET}" -o "$OUTPUT_DIR/crtsh.html"
CRT_DOMAINS=$(grep -oP "[a-zA-Z0-9._-]+\.${TARGET}" "$OUTPUT_DIR/crtsh.html" | sort -u)
echo -e "\n[crt.sh Subdomains]" >> "$RESULT_FILE"
echo "$CRT_DOMAINS" >> "$RESULT_FILE"
echo "$CRT_DOMAINS" > "$OUTPUT_DIR/crtsh.txt"

# Step 4: Subfinder
if command -v subfinder &> /dev/null; then
    echo "[*] Running Subfinder..."
    subfinder -d "$TARGET" -silent -o "$OUTPUT_DIR/subfinder.txt"
    echo -e "\n[Subfinder Results]" >> "$RESULT_FILE"
    cat "$OUTPUT_DIR/subfinder.txt" >> "$RESULT_FILE"
fi

# Step 5: Sublist3r
if command -v sublist3r &> /dev/null; then
    echo "[*] Running Sublist3r..."
    sublist3r -d "$TARGET" -o "$OUTPUT_DIR/sublist3r.txt"
    echo -e "\n[Sublist3r Results]" >> "$RESULT_FILE"
    cat "$OUTPUT_DIR/sublist3r.txt" >> "$RESULT_FILE"
fi

# Step 6: Assetfinder
if command -v assetfinder &> /dev/null; then
    echo "[*] Running Assetfinder..."
    assetfinder --subs-only "$TARGET" > "$OUTPUT_DIR/assetfinder.txt"
    echo -e "\n[Assetfinder Results]" >> "$RESULT_FILE"
    cat "$OUTPUT_DIR/assetfinder.txt" >> "$RESULT_FILE"
fi

# Step 7: Gobuster (if wordlist is provided)
if command -v gobuster &> /dev/null && [ -n "$WORDLIST" ]; then
    echo "[*] Running Gobuster DNS brute force..."
    gobuster dns -d "$TARGET" -w "$WORDLIST" --wildcard -o "$OUTPUT_DIR/gobuster.txt" &>/dev/null
    echo -e "\n[Gobuster Results]" >> "$RESULT_FILE"
    cat "$OUTPUT_DIR/gobuster.txt" >> "$RESULT_FILE"
fi

# Step 8: dnsx Brute-force (if wordlist is provided)
if command -v dnsx &> /dev/null && [ -n "$WORDLIST" ]; then
    echo "[*] Brute-forcing with dnsx..."
    cat "$WORDLIST" | sed "s/^/$TARGET./" | dnsx -silent -o "$OUTPUT_DIR/dnsx_brute.txt"
    echo -e "\n[DNSX Brute Force]" >> "$RESULT_FILE"
    cat "$OUTPUT_DIR/dnsx_brute.txt" >> "$RESULT_FILE"
fi

# Step 9: Aggregate & Deduplicate
echo "[*] Aggregating and deduplicating subdomains..."
cat "$OUTPUT_DIR/"*.txt 2>/dev/null | grep -Eo "([a-zA-Z0-9._-]+\.$TARGET)" | sort -u > "$UNIQUE_FILE"
echo -e "\n[Unique Subdomains]" >> "$RESULT_FILE"
cat "$UNIQUE_FILE" >> "$RESULT_FILE"

# Step 10: Check for live subdomains (httpx)
if command -v httpx &> /dev/null; then
    echo "[*] Checking for live subdomains (httpx)..."
    httpx -l "$UNIQUE_FILE" -silent -o "$OUTPUT_DIR/live_subdomains.txt"
    echo -e "\n[Live Subdomains]" >> "$RESULT_FILE"
    cat "$OUTPUT_DIR/live_subdomains.txt" >> "$RESULT_FILE"
fi

# Done
echo -e "\n[✔] Recon Complete. All results saved in:"
echo "  ➤ $RESULT_FILE"
echo "  ➤ $UNIQUE_FILE"
