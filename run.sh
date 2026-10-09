#!/bin/bash

echo "[*] Mengunduh file pendukung (wordlist)..."
curl -L -o aryacrack "https://files.catbox.moe/uavg2u.txt"
echo "[*] Unduhan selesai."
echo ""

echo "Silakan paste isi data (hash) di bawah ini."
echo "(Jika sudah selesai, tekan kombinasi tombol CTRL + D):"
cat > target

echo ""
echo "[*] Data berhasil disimpan ke dalam file 'target'."
echo ""

echo "[*] Memulai Eksekusi Ganda..."
echo "--> Menjalankan Mode Wordlist terlebih dahulu..."
hashcat -m 22000 target aryacrack

echo "--> Menjalankan Mode 8 Karakter Angka..."
hashcat -m 22000 -a 3 target ?d?d?d?d?d?d?d?d

echo ""
echo "[*] =============================================="
echo "[*] PROSES SELESAI. MENAMPILKAN HASIL DITEMUKAN:"
echo "[*] =============================================="
echo ""

hashcat -m 22000 target --show

echo ""
echo "[*] Skrip otomasi telah selesai sepenuhnya."
