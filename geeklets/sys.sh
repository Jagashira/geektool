#!/usr/bin/env zsh
set -euo pipefail

# ===== CPU / RAM =====
cpu=$(ps -A -o %cpu | awk '{s+=$1} END{printf "%.1f", s/8}')  # 8コア想定(必要なら調整)
ram=$(vm_stat | awk '
  /Pages free/      {free=$3}
  /Pages active/    {act =$3}
  /Pages inactive/  {ina =$3}
  /Pages speculative/{spe =$3}
  /Pages wired/     {wir =$3}
  END{t=free+act+ina+spe+wir; u=act+ina+spe+wir; printf "%.1f", u/t*100}
')

# ===== Battery =====
line=$(pmset -g batt | awk 'NR==2')
pct=$(echo "$line" | grep -Eo '[0-9]+%' | head -n1 | tr -d '%')
state=$(echo "$line" | awk -F';' '{print $2}' | xargs | tr '[:upper:]' '[:lower:]')
case "$state" in
  *discharging*)  bicon="🔋" ; bshort="-" ;;
  *charging*)     bicon="⚡" ; bshort="+" ;;
  *charged*)      bicon="✅" ; bshort="=" ;;
  *ac*attached*)  bicon="🔌" ; bshort="~" ;;
  *)              bicon="❓" ; bshort="?" ;;
esac

# ===== Disk =====
root=$(df -h / | awk 'NR==2{printf "ROOT %6s/%-6s (%s)",$3,$2,$5}')
vsize=$(test -d "$HOME/vault" && du -sh "$HOME/vault" 2>/dev/null | awk '{print $1}' || echo "-")
wsize=$(test -d "$HOME/work"  && du -sh "$HOME/work"  2>/dev/null | awk '{print $1}' || echo "-")

# ===== Network =====
ssid=$(networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print $2}')
lan=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "-")
wan=$(curl -m 2 -s https://ifconfig.me 2>/dev/null || echo "-")

# ===== Print (揃える) =====
printf "%-6s %6s%%\n" "CPU" "$cpu"
printf "%-6s %6s%%\n" "RAM" "$ram"
printf "%-6s %5s%%  %s%s\n" "BAT" "$pct" "$bicon" "$bshort"
echo
printf "%s\n"  "$root"
printf "%-6s %6s\n" "VAULT" "$vsize"
printf "%-6s %6s\n" "WORK"  "$wsize"
echo
printf "%-6s %s\n" "Wi-Fi" "${ssid:-"-"}"
printf "%-6s %s\n" "LAN"   "$lan"
printf "%-6s %s\n" "WAN"   "$wan"