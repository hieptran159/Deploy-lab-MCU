#!/usr/bin/env bash
# Ký một CSR bằng CA nội bộ của lab (ca.key / ca.crt trong cùng thư mục này).
# Usage: ./sign-csr.sh <ten-file.csr> [so-ngay-hieu-luc, mac dinh 825]
#
# Vi du:
#   ./sign-csr.sh singleCert.csr
#   -> tao ra singleCert.crt (chi cert node) va singleCert-chain.crt (fullchain: cert + CA)
#
set -euo pipefail
cd "$(dirname "$0")"

CSR="${1:?Cần truyền tên file CSR, ví dụ: ./sign-csr.sh singleCert.csr}"
DAYS="${2:-825}"
BASE="$(basename "${CSR%.csr}")"
OUT_CRT="${BASE}.crt"
OUT_CHAIN="${BASE}-chain.crt"
EXT_TMP="./.${BASE}.ext.tmp"

if [ ! -f "$CSR" ]; then
  echo "Không tìm thấy file: $CSR" >&2
  exit 1
fi

# Lấy danh sách Subject Alternative Name đã yêu cầu trong CSR (do lệnh `pki csr` trên CMS/Expressway sinh ra)
SAN_LINE="$(openssl req -in "$CSR" -noout -text \
  | awk '/X509v3 Subject Alternative Name/{getline; print; exit}' \
  | sed 's/^[ 	]*//; s/IP Address:/IP:/g')"

{
  echo "basicConstraints=CA:FALSE"
  echo "keyUsage=digitalSignature,keyEncipherment"
  echo "extendedKeyUsage=serverAuth,clientAuth"
  if [ -n "$SAN_LINE" ]; then
    echo "subjectAltName=${SAN_LINE}"
  fi
} > "$EXT_TMP"

echo "--- Extensions sẽ áp dụng ---"
cat "$EXT_TMP"
echo "-----------------------------"

openssl x509 -req -in "$CSR" \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out "$OUT_CRT" -days "$DAYS" -sha256 \
  -extfile "$EXT_TMP"

cat "$OUT_CRT" ca.crt > "$OUT_CHAIN"
rm -f "$EXT_TMP"

echo
echo "Đã ký xong:"
echo "  - $OUT_CRT        (upload làm 'singleCert.crt' trên CMS)"
echo "  - $OUT_CHAIN  (dùng làm full-chain cho webbridge3 / c2w, và làm ca-bundle nếu cần)"
echo
openssl x509 -in "$OUT_CRT" -noout -subject -ext subjectAltName -dates
