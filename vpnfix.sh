#!/usr/bin/env bash
#
# Usage: [dry_run=1] [debug=1] [interface=tunsnx] docker-fix-snx
#
# Credits to: https://github.com/docker/for-linwux/issues/288#issuecomment-825580160
#
# Env Variables:
#   interface - Defaults to tunsnx
#   dry_run - Set to 1 to have a dry run, just printing out the iptables command
#   debug   - Set to 1 to see bash substitutions

set -eu

_log_stderr() {
  echo "$*" >&2
}

if [ "${debug:=0}" = 1 ]; then
  set -x
  dry_run=${dry_run:=1}
fi

: ${dry_run:=0}
: ${interface:=tunsnx}

data=($(ip -o address show "$interface" | awk -F ' +' '{print $4 " " $6 " " $8}'))

LOCAL_ADDRESS_INDEX=0
PEER_ADDRESS_INDEX=1
SCOPE_INDEX=2

if [ "$dry_run" = 1 ]; then
  echo "[-] DRY-RUN MODE"
fi

if [ "${data[$SCOPE_INDEX]}" == "global" ]; then
  echo "[+] Interface ${interface} is already set to global scope. Skip!"
  exit 0
else
  echo "[+] Interface ${interface} is set to scope ${data[$SCOPE_INDEX]}."

  tmpfile=$(mktemp --suffix=snxwrapper-routes)
  echo "[+] Saving current IP routing table..."
  if [ "$dry_run" = 0 ]; then
    sudo ip route save >$tmpfile
  fi

  echo "[+] Deleting current interface ${interface}..."
  if [ "$dry_run" = 0 ]; then
    sudo ip address del ${data[$LOCAL_ADDRESS_INDEX]} peer ${data[$PEER_ADDRESS_INDEX]} dev ${interface}
  fi

  echo "[+] Recreating interface ${interface} with global scope..."
  if [ "$dry_run" = 0 ]; then
    sudo ip address add ${data[$LOCAL_ADDRESS_INDEX]} dev ${interface} peer ${data[$PEER_ADDRESS_INDEX]} scope global
  fi

  echo "[+] Restoring routing table..."
  if [ "$dry_run" = 0 ]; then
    sudo ip route restore <$tmpfile 2>/dev/null
  fi

  echo "[+] Cleaning temporary files..."
  rm $tmpfile

  echo "[+] Interface ${interface} is set to global scope. Done!"
  if [ "$dry_run" = 0 ]; then
    echo "[+] Result:"
    ip -o address show "tunsnx" | awk -F ' +' '{print $4 " " $6 " " $8}'
  fi
  exit 0
fi

[ "$debug" = 1 ] && set +x
