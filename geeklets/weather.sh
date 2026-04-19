#!/usr/bin/env zsh
# 例: 東京 35.68, 139.76 に変更してね
LAT="${WEATHER_LAT:-35.930807}"
LON="${WEATHER_LON:-139.890211}"
url="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,relative_humidity_2m,weather_code&timezone=auto"
json=$(curl -m 3 -s "$url")
[ -z "$json" ] && { echo "Weather  -"; exit 0; }
temp=$(echo "$json" | jq -r '.current.temperature_2m // empty')
hum=$( echo "$json" | jq -r '.current.relative_humidity_2m // empty')
code=$(echo "$json" | jq -r '.current.weather_code // empty')
icon="☁️"
case "$code" in 0) icon="☀️";; 1|2|3) icon="⛅";; 45|48) icon="🌫";; 51|53|55|56|57) icon="🌦";; 61|63|65|80|81|82) icon="🌧";; 71|73|75|77|85|86) icon="❄️";; 95|96|99) icon="⛈";; esac
printf "%s  %s°C  %s%%\n" "$icon" "${temp:-?}" "${hum:-?}"
