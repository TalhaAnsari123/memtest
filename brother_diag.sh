#!/bin/bash
# Brother HL-L2460DW recovery helper for macOS -- READ-ONLY.
# It sends nothing to the printer. It:
#   1. shows how macOS printing sees the printer over USB (address + device ID)
#   2. looks for firmware files the Brother tool may have left on this Mac
#   3. asks Brother's own update server which MAIN firmware file belongs to
#      HL-L2460DW, HL-L2465DW and HL-L2865DW (no serial number is sent)
# Run with:  bash brother_diag.sh
# Keep the printer on, plugged into this Mac by USB, showing "Retry Updating by USB".

echo "== 1. Printer as seen by macOS printing over USB =="
if [ -x /usr/libexec/cups/backend/usb ]; then
  /usr/libexec/cups/backend/usb 2>/dev/null | grep -i brother || echo "(no Brother printer listed - check cable and power)"
else
  echo "(USB printing backend not found)"
fi

echo
echo "== 2. Firmware files left on this Mac (.djf / .blf / .upd) =="
find "$HOME/Downloads" "$HOME/Library" "${TMPDIR:-/tmp}" /private/tmp \
  \( -iname "*.djf" -o -iname "*.blf" -o -iname "*.upd" \) -print 2>/dev/null | head -20
echo "(end of list)"

echo
echo "== 3. Firmware Brother's update server lists for each model =="
URL="https://firmverup.brother.co.jp/kne_bh7_update_nt_ssl/ifax2.asmx/fileUpdate"
SPECS="NONE 0001 0002 0003 0004 0005 0010 0011 0012 0020 0101 0102 0201 0301 0401 0402 0403 0501 0502 1001"

for base in HL-L2460DW HL-L2465DW HL-L2865DW; do
  hit=""
  for name in "$base series" "$base"; do
    for spec in $SPECS; do
      [ "$spec" = "NONE" ] && spec=""
      for ver in B0000000000 Z0000000000; do
        for drv in EWS ""; do
          body="<REQUESTINFO><FIRMUPDATETOOLINFO><FIRMCATEGORY>MAIN</FIRMCATEGORY><OS>LINUX</OS><INSPECTMODE>1</INSPECTMODE></FIRMUPDATETOOLINFO><FIRMUPDATEINFO><MODELINFO><SELIALNO></SELIALNO><NAME>$name</NAME><SPEC>$spec</SPEC><DRIVER>$drv</DRIVER><FIRMINFO><FIRM><ID>MAIN</ID><VERSION>$ver</VERSION></FIRM></FIRMINFO></MODELINFO><DRIVERCNT>1</DRIVERCNT><LOGNO>2</LOGNO><ERRBIT></ERRBIT><NEEDRESPONSE>1</NEEDRESPONSE></FIRMUPDATEINFO></REQUESTINFO>"
          resp=$(curl -s -m 15 -X POST -H "Content-Type: text/xml" --data "$body" "$URL")
          if grep -q "<VERSIONCHECK>0</VERSIONCHECK>" <<<"$resp"; then
            latest=$(grep -o "<LATESTVERSION>[^<]*" <<<"$resp" | sed 's/<LATESTVERSION>//')
            path=$(grep -o "<PATH>[^<]*" <<<"$resp" | sed 's/<PATH>//')
            echo "$base: name='$name' spec='${spec:-none}' -> version $latest"
            echo "    file: $path"
            hit=1
            break 4
          fi
        done
      done
    done
  done
  [ -z "$hit" ] && echo "$base: no match found"
done

echo
echo "Done. Nothing was sent to the printer. Paste this whole output back into the chat."
