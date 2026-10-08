#!/bin/bash

# ---------------------------------------------------------
# 1. Tahap Persiapan
# ---------------------------------------------------------
echo "[*] Mengunduh file pendukung (wordlist)..."
curl -L -o aryacrack "https://files.catbox.moe/uavg2u.txt"
echo "[*] Unduhan selesai."
echo ""

# ---------------------------------------------------------
# 2. Tahap Input Target
# ---------------------------------------------------------
echo "Silakan paste isi data (hash) di bawah ini."
echo "(Jika sudah selesai, tekan kombinasi tombol CTRL + D):"
cat > target

echo ""
echo "[*] Data berhasil disimpan ke dalam file 'target'."
echo ""

# ---------------------------------------------------------
# 3. Tahap Pemilihan Menu
# ---------------------------------------------------------
echo "Pilih mode operasi yang ingin dijalankan:"
echo "1. Menggunakan Wordlist (aryacrack)"
echo "2. Menggunakan 8 Karakter Angka (?d?d?d?d?d?d?d?d)"
echo "3. Jalankan Keduanya secara berurutan"
read -p "Masukkan pilihan (1/2/3): " pilihan
echo ""

# ---------------------------------------------------------
# 4. Tahap Eksekusi Utama
# ---------------------------------------------------------
case $pilihan in
    1)
        echo "[*] Memulai Mode Wordlist..."
        hashcat -m 22000 target aryacrack
        ;;
    2)
        echo "[*] Memulai Mode 8 Karakter Angka..."
        hashcat -m 22000 -a 3 target ?d?d?d?d?d?d?d?d
        ;;
    3)
        echo "[*] Memulai Eksekusi Ganda..."
        
        echo "--> Menjalankan Mode Wordlist terlebih dahulu..."
        hashcat -m 22000 target aryacrack
        
        echo "--> Menjalankan Mode 8 Karakter Angka..."
        hashcat -m 22000 -a 3 target ?d?d?d?d?d?d?d?d
        ;;
    *)
        echo "[!] Pilihan tidak dikenali. Skrip dibatalkan."
        exit 1
        ;;
esac

# ---------------------------------------------------------
# 5. Tahap Pelaporan
# ---------------------------------------------------------
echo ""
echo "[*] =============================================="
echo "[*] PROSES SELESAI. MENAMPILKAN HASIL DITEMUKAN:"
echo "[*] =============================================="
echo ""

hashcat -m 22000 target --show

echo ""
echo "[*] Skrip otomasi telah selesai sepenuhnya."
