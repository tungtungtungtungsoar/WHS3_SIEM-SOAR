#!/usr/bin/env python3
import subprocess
import json
import sys
import datetime
import os
import traceback

YARA_RULE = "/opt/yara_rules/webshell_rules.yar"
DEBUG_LOG = "/var/ossec/logs/yara_debug.log"
HITS_LOG = "/var/ossec/logs/yara_hits.log"

def log_debug(msg):
    with open(DEBUG_LOG, "a") as f:
        f.write(f"[DEBUG] {msg}\n")
        f.flush()

log_debug("=== Script started ===")

try:
    alert_input = sys.stdin.readline()
    log_debug(f"Raw input: {alert_input}")

    alert = json.loads(alert_input)
    log_debug("Parsed alert JSON.")

    filepath = alert.get("parameters", {}).get("alert", {}).get("syscheck", {}).get("path", "")
    log_debug(f"Extracted filepath: {filepath}")

    if filepath and os.path.exists(filepath):
        log_debug("File exists. Running yara scan...")
        result = subprocess.run(['yara', YARA_RULE, filepath], capture_output=True, text=True)

        log_debug(f"YARA STDOUT: {result.stdout.strip()}")
        log_debug(f"YARA STDERR: {result.stderr.strip()}")

        if result.stdout.strip():
            rule_name = result.stdout.strip().split()[0]

            with open(HITS_LOG, 'a') as f:
                f.write(f"[!] YARA MATCH: {filepath}\n{result.stdout}\n")
                f.flush()

            message = f"Rule={rule_name} File={filepath}"
            subprocess.run(["logger", "-t", "yara_detected", message])

            print(f"Rule={rule_name} File={filepath}")
            print(f"[!] YARA MATCH:\n{result.stdout}")
        else:
            print(f"[OK] No match for {filepath}")
    else:
        log_debug(f"[ERROR] File not found or invalid path: {filepath}")
        print(f"[ERROR] File not found or invalid path: {filepath}")

except Exception as e:
    log_debug(f"[EXCEPTION] {str(e)}")
    log_debug(traceback.format_exc())
    print(f"[EXCEPTION] {str(e)}")
