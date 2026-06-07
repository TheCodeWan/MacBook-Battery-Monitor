#!/bin/bash
cat > ~/battery_monitor.sh << 'ENDOFSCRIPT'
#!/bin/bash
if [[ "$1" != "--daemon" ]]; then
    sudo -v || exit 1
    nohup "$0" --daemon > /dev/null 2>&1 &
    echo "✅ Battery monitor started in background. Updates iCloud file every minute."
    echo "Stop it later with: pkill -f battery_monitor.sh"
    exit 0
fi

OUTPUT_FILE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Mac_Battery_Status.txt"
UPDATE_INTERVAL=60

if pgrep -f "$(basename "$0")" | grep -v $$ > /dev/null; then exit 0; fi

if [[ "$EUID" -eq 0 ]]; then
    REAL_USER=$(stat -f %Su /dev/console)
    OUTPUT_FILE="/Users/$REAL_USER/Library/Mobile Documents/com~apple~CloudDocs/Mac_Battery_Status.txt"
fi

get_battery_info() {
    local batt; batt=$(pmset -g batt 2>/dev/null)
    PERCENT=$(echo "$batt" | grep -o '[0-9]*%' | head -1)
    STATUS=$(echo "$batt" | grep 'InternalBattery' | sed -E 's/.*[0-9]+%; *([^;]+);.*/\1/' | xargs)
    [[ -z "$STATUS" ]] && STATUS=$(echo "$batt" | grep -oE 'discharging|charging|charged|not charging|AC attached' | head -1)
    if [[ "$PERCENT" == "100%" || "$STATUS" == "charged" ]]; then TIME_LINE="Fully charged"
    elif [[ "$STATUS" == "discharging" ]]; then REMAINING=$(echo "$batt" | grep -o '[0-9]*:[0-9]* remaining' | head -1); TIME_LINE="Battery life remaining: $REMAINING"
    elif [[ "$STATUS" == "charging" ]]; then REMAINING=$(echo "$batt" | grep -o '[0-9]*:[0-9]* remaining' | head -1); TIME_LINE="Time to full: $REMAINING"
    else TIME_LINE=""; fi
}

get_power_draw() {
    local info vol amp; info=$(ioreg -w 0 -f -r -c AppleSmartBattery 2>/dev/null)
    vol=$(echo "$info" | grep '"Voltage" = ' | grep -oE '[0-9]+' | head -1)
    amp=$(echo "$info" | grep '"Amperage" = ' | grep -oE '[0-9]+' | head -1)
    if [[ -n "$vol" && -n "$amp" && "$vol" -gt 0 ]]; then
        [[ "$amp" -gt $((2**63)) ]] && amp=$((amp - 2**64))
        if [[ "$amp" -eq 0 ]]; then POWER_W="0 (AC)"; else
            amp_abs=${amp#-}; POWER_W=$(echo "scale=1; $vol * $amp_abs / 1000000" | bc 2>/dev/null)
            [[ -z "$POWER_W" || "$POWER_W" == "0.0" ]] && POWER_W="0 (AC)"
        fi
    else POWER_W=""; fi
    if [[ -z "$POWER_W" ]]; then
        if [[ "$EUID" -eq 0 ]]; then
            POWER_W=$(powermetrics --samplers cpu_power,gpu_power,ane_power --sample-count 1 2>/dev/null | awk '/ mW/ {sum += $(NF-1)} END {if (sum > 0) printf "%.1f", sum/1000; else print "N/A"}')
        else
            POWER_W=$(sudo -n powermetrics --samplers cpu_power,gpu_power,ane_power --sample-count 1 2>/dev/null | awk '/ mW/ {sum += $(NF-1)} END {if (sum > 0) printf "%.1f", sum/1000; else print "N/A"}')
        fi
        [[ -z "$POWER_W" ]] && POWER_W="N/A"
    fi
}

get_thermal() {
    TEMP_C=$(powermetrics --samplers smc --sample-count 1 2>/dev/null | grep -i "die temperature" | head -1 | awk '{print $(NF-1)}' | tr -d 'C')
    if [[ -n "$TEMP_C" && "$TEMP_C" =~ ^[0-9.]+$ ]]; then
        TEMP_F=$(echo "scale=1; $TEMP_C * 9/5 + 32" | bc 2>/dev/null); TEMP_DISPLAY="${TEMP_F}°F"
    else
        TEMP_DISPLAY=$(powermetrics --samplers thermal --sample-count 1 2>/dev/null | grep -i "pressure level" | head -1 | awk -F': ' '{print $2}' | xargs)
        [[ -z "$TEMP_DISPLAY" ]] && TEMP_DISPLAY="N/A"
    fi
}

while true; do
    TIMESTAMP=$(date "+%Y-%m-%d %I:%M:%S %p")
    get_battery_info; get_power_draw; get_thermal
    LOW_POWER=$(pmset -g 2>/dev/null | awk '/lowpowermode/ {print $2}')
    LOW_POWER_STATUS=$([[ "$LOW_POWER" == "1" ]] && echo "On" || echo "Off")
    cat > "$OUTPUT_FILE" << EOF
Last Updated: $TIMESTAMP
• Battery: $PERCENT
• Status: $STATUS
• Power Draw: ${POWER_W} W
• Temperature: $TEMP_DISPLAY
• Low Power Mode: $LOW_POWER_STATUS
EOF
    [[ -n "$TIME_LINE" ]] && { echo "" >> "$OUTPUT_FILE"; echo "• $TIME_LINE" >> "$OUTPUT_FILE"; }
    if [[ "$EUID" -eq 0 ]]; then
        REAL_USER=$(stat -f %Su /dev/console); chown "$REAL_USER:staff" "$OUTPUT_FILE" 2>/dev/null
    else
        chown "$USER:staff" "$OUTPUT_FILE" 2>/dev/null
    fi
    chmod 644 "$OUTPUT_FILE" 2>/dev/null
    sleep $UPDATE_INTERVAL
done
ENDOFSCRIPT

chmod +x ~/battery_monitor.sh
~/battery_monitor.sh