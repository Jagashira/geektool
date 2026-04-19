#!/usr/bin/env zsh
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

normalize_size() {
  echo "$1" | sed -E 's/Gi/G/g; s/Ti/T/g; s/Mi/M/g; s/Ki/K/g; s/iB//g; s/Bytes?/B/g; s/([0-9])\.0([A-Za-z])/\1\2/'
}

compact_ip() {
  local value=$1
  if [[ ${#value} -le 18 ]]; then
    echo "$value"
  else
    echo "${value[1,18]}~"
  fi
}

cpu_cores=8
if command_exists sysctl; then
  cpu_cores=$(sysctl -n hw.logicalcpu 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 8)
fi
[[ "$cpu_cores" =~ '^[0-9]+$' ]] || cpu_cores=8
(( cpu_cores > 0 )) || cpu_cores=8

cpu="?"
if command_exists ps; then
  cpu=$(ps -A -o %cpu= 2>/dev/null | awk -v cores="$cpu_cores" '
    { sum += $1 }
    END {
      if (cores <= 0) cores = 1
      printf "%.1f", sum / cores
    }
  ' || echo "?")
fi

ram="?"
if command_exists vm_stat; then
  page_size=$(vm_stat 2>/dev/null | head -n1 | sed -E 's/.*page size of ([0-9]+) bytes.*/\1/' || echo 4096)
  total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  ram=$(vm_stat 2>/dev/null | awk -v page_size="$page_size" -v total_bytes="$total_bytes" '
    /Pages active/ {
      gsub("\\.", "", $3)
      active = $3
    }
    /Pages wired down/ {
      gsub("\\.", "", $4)
      wired = $4
    }
    /Pages occupied by compressor/ {
      gsub("\\.", "", $5)
      compressed = $5
    }
    END {
      used_pages = active + wired + compressed
      if (used_pages <= 0 || total_bytes <= 0 || page_size <= 0) {
        print "?"
        exit
      }
      printf "%.1f", (used_pages * page_size) / total_bytes * 100
    }
  ' || echo "?")
fi

# ===== Battery =====
line=$(pmset -g batt | awk 'NR==2')
pct=$(echo "$line" | grep -Eo '[0-9]+%' | head -n1 | tr -d '%' || true)
state=$(echo "$line" | awk -F';' '{print $2}' | xargs | tr '[:upper:]' '[:lower:]' || true)
pct=${pct:-"--"}
bpct_numeric=0
if [[ "$pct" =~ '^[0-9]+$' ]]; then
  bpct_numeric=$pct
fi
case "$state" in
  *charging*)
    bicon="⚡"
    bstate="charging"
    ;;
  *charged*)
    bicon="🟢"
    bstate="full"
    ;;
  *ac*attached*)
    if (( bpct_numeric >= 95 )); then
      bicon="🟢"
      bstate="full"
    else
      bicon="🔌"
      bstate="plugged"
    fi
    ;;
  *discharging*)
    if (( bpct_numeric <= 20 )); then
      bicon="🪫"
      bstate="low"
    else
      bicon="🔋"
      bstate="battery"
    fi
    ;;
  *)
    bicon="❔"
    bstate="unknown"
    ;;
esac

# ===== Disk =====
root_used="-"
root_total="-"
root_used_pct="-"
if command_exists diskutil; then
  disk_info=$(diskutil info /System/Volumes/Data 2>/dev/null || true)
  if [[ -n "$disk_info" ]]; then
    root_used=$(echo "$disk_info" | awk -F': *' '/Volume Used Space/ {print $2; exit}' | sed -E 's/^([0-9.]+) ([KMGTP])B.*/\1\2/')
    root_total=$(echo "$disk_info" | awk -F': *' '/Container Total Space/ {print $2; exit}' | sed -E 's/^([0-9.]+) ([KMGTP])B.*/\1\2/')
    root_used_bytes=$(echo "$disk_info" | awk -F'[()]' '/Volume Used Space/ {print $2; exit}' | awk '{print $1}')
    root_total_bytes=$(echo "$disk_info" | awk -F'[()]' '/Container Total Space/ {print $2; exit}' | awk '{print $1}')
    root_used=$(normalize_size "${root_used:-"-"}")
    root_total=$(normalize_size "${root_total:-"-"}")
    if [[ -n "${root_used_bytes:-}" && -n "${root_total_bytes:-}" ]]; then
      root_used_pct=$(awk -v used="$root_used_bytes" -v total="$root_total_bytes" 'BEGIN {
        if (total > 0) printf "%d%%", (used / total) * 100 + 0.5;
        else print "-";
      }')
    fi
  fi
fi

if [[ "$root_used" == "-" || "$root_total" == "-" || "$root_used_pct" == "-" || -z "$root_used_pct" ]]; then
  if root_line=$(df -h /System/Volumes/Data 2>/dev/null | awk 'NR==2{print $3 "|" $2 "|" $5}'); then
    root_used=$(normalize_size "${root_line%%|*}")
    root_rest=${root_line#*|}
    root_total=$(normalize_size "${root_rest%%|*}")
    root_used_pct=${root_line##*|}
  fi
fi
vsize=$(test -d "$HOME/vault" && du -sh "$HOME/vault" 2>/dev/null | awk '{print $1}' || echo "-")
wsize=$(test -d "$HOME/work"  && du -sh "$HOME/work"  2>/dev/null | awk '{print $1}' || echo "-")
vsize=$(normalize_size "$vsize")
wsize=$(normalize_size "$wsize")

# ===== Network =====
wifi_device=""
if command_exists networksetup; then
  wifi_device=$(networksetup -listallhardwareports 2>/dev/null | awk '
    $0 == "Hardware Port: Wi-Fi" { getline; sub(/^Device: /, "", $0); print; exit }
    $0 == "Hardware Port: AirPort" { getline; sub(/^Device: /, "", $0); print; exit }
  ' || true)
fi
ssid="-"
if [[ -n "$wifi_device" ]] && command_exists networksetup; then
  ssid=$(networksetup -getairportnetwork "$wifi_device" 2>/dev/null | awk -F': ' '{print $2}' || echo "-")
fi
[[ -n "$ssid" ]] || ssid="-"
if [[ "$ssid" == "You are not associated with an AirPort network." ]]; then
  ssid="-"
fi
if [[ "$ssid" == "-" ]] && [[ -x /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport ]]; then
  ssid=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | awk -F': ' '
    /^[[:space:]]*SSID:/ { print $2; exit }
  ' || echo "-")
fi
[[ -n "$ssid" ]] || ssid="-"

lan="-"
for iface in "${wifi_device:-}" en0 en1; do
  [[ -n "$iface" ]] || continue
  if ip=$(ipconfig getifaddr "$iface" 2>/dev/null); then
    lan="$ip"
    break
  fi
done
if [[ "$ssid" == "-" && "$lan" != "-" ]]; then
  ssid="wired"
fi

wan="-"
for url in https://api.ipify.org https://ifconfig.me https://checkip.amazonaws.com; do
  if ip=$(curl -m 2 -fsS "$url" 2>/dev/null); then
    wan=${ip//$'\n'/}
    [[ -n "$wan" ]] && break
  fi
done

# ===== Print (揃える) =====
printf "%-4s %6s%%\n" "CPU" "$cpu"
printf "%-4s %6s%%\n" "RAM" "$ram"
echo
printf "%-4s %s %s\n" "BAT" "$bicon" "${pct}%"
echo
printf "%-5s %s/%s (%s)\n" "DISK" "$root_used" "$root_total" "$root_used_pct"
echo
printf "%-5s %4s\n" "VAULT" "$vsize"
printf "%-5s %4s\n" "WORK" "$wsize"
echo
printf "%-4s %s\n" "LAN" "$(compact_ip "$lan")"
printf "%-4s %s\n" "WAN" "$(compact_ip "$wan")"
