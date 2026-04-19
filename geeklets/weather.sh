#!/usr/bin/env zsh
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

LAT="${WEATHER_LAT:-35.930807}"
LON="${WEATHER_LON:-139.890211}"

if ! command -v curl >/dev/null 2>&1; then
  printf "%s\n" "--  --.-C  --%"
  exit 0
fi

wttr_url="https://wttr.in/${LAT},${LON}?format=%c+%t+%h"
wttr=$(curl -A 'geektool-weather/1.0' -m 5 -fsS "$wttr_url" 2>/dev/null || true)
if [[ -n "$wttr" ]]; then
  wttr=${wttr//$'\n'/}
  wttr=${wttr//+ /}
  wttr=${wttr//+/}
  printf "%s\n" "$wttr"
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  url="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,weather_code&timezone=auto"
  json=$(curl -m 3 -fsS "$url" 2>/dev/null || true)
  if [[ -n "$json" ]]; then
    temp=$(echo "$json" | jq -r '.current.temperature_2m // empty')
    hum=$( echo "$json" | jq -r '.current.relative_humidity_2m // empty')
    code=$(echo "$json" | jq -r '.current.weather_code // empty')
    icon="☁️"
    case "$code" in 0) icon="☀️";; 1|2|3) icon="⛅";; 45|48) icon="🌫";; 51|53|55|56|57) icon="🌦";; 61|63|65|80|81|82) icon="🌧";; 71|73|75|77|85|86) icon="❄️";; 95|96|99) icon="⛈";; esac
    printf "%s  %s°C  %s%%\n" "$icon" "${temp:-?}" "${hum:-?}"
    exit 0
  fi
fi

printf "%s\n" "--  --.-C  --%"
