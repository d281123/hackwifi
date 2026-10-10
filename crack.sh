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

echo "[*] Menjalankan Wordlist & Brute Force secara paralel..."
hashcat -m 22000 target aryacrack --potfile-path hasil.potfile --logfile-disable &
hashcat -m 22000 -a 3 target ?d?d?d?d?d?d?d?d --potfile-path hasil.potfile --logfile-disable &
wait

echo ""
echo "[*] =============================================="
echo "[*] PROSES SELESAI. MENAMPILKAN HASIL DITEMUKAN:"
echo "[*] =============================================="
echo ""

hashcat -m 22000 target --show | awk -F: '{print NR " " $4 " = " $5}'

