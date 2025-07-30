#!/bin/bash

NOW="$(date '+%Y-%m-%d %H:%M:%S')"


echo "$@" >> /var/ossec/logs/AR_debug.log
timeout 1 cat - >> /var/ossec/logs/AR_debug.log
echo "$NOW" >> /var/ossec/logs/ar-debug.log

LOG="/var/ossec/logs/AR_debug.log"
OSSEC="/var/ossec/logs/ossec.log"
PHP_FILE=$(jq -r '.parameters.alert.syscheck.path' "$LOG" |tail -n 1)


echo "$PHP_FILE" >> /var/ossec/logs/ar-debug.log

LOGFILE="/var/ossec/logs/evalhook.log"
ACTLOG="/var/ossec/logs/evalhook_active_response.log"


php "$PHP_FILE" >> "$LOGFILE"
echo "evalhook-scan $PHP_FILE" >> "$ACTLOG"
echo "evalhook-scan $PHP_FILE" >> "$OSSEC"

PATTERNS=$(awk -v file="$PHP_FILE" '
    BEGIN {
        split("", pattern_map)
    }

    $0 ~ /^=+\[webshell_summary\]=+/ {
        in_summary = 1;
        current_pattern = "";
    }

    in_summary && /^!!Pattern_matched:/ {
        sub(/^!!Pattern_matched:/, "", $0);
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0);
        current_pattern = $0;
    }

    in_summary && /^⚠️Suspicious_file:/ {
        suspicious_file = $0;
        gsub(/^⚠️Suspicious_file:/, "", suspicious_file);
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", suspicious_file);
        if (suspicious_file == file) {
            n = split(current_pattern, arr, /[[:space:]]*,[[:space:]]*/);
            for (i = 1; i <= n; i++) {
                pattern_map[arr[i]] = 1;
            }
        }
    }

    $0 ~ /^=+$/ { in_summary = 0 }

    END {
        out = "";
        for (p in pattern_map) {
            if (out == "") {
                out = p;
            } else {
                out = out "," p;
            }
        }
        print out;
    }
' "$LOGFILE")


if [[ -n "$PATTERNS" ]]; then
    echo "evalhook-detect FILE=$PHP_FILE PATTERNS=$PATTERNS" >> "$ACTLOG"
else
    echo "[OK] No suspicious pattern in: $PHP_FILE" >> "$ACTLOG"
fi