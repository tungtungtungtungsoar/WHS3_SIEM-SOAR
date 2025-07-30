#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import sys
try:
    import requests
except Exception:
    print("No module 'requests' found. Install with: pip install requests")
    sys.exit(1)

# Exit codes
ERR_BAD_ARGUMENTS = 2
ERR_FILE_NOT_FOUND = 6
ERR_INVALID_JSON = 7

# Paths & args
pwd = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
LOG_FILE = f'{pwd}/logs/integrations.log'
ALERT_INDEX = 1
WEBHOOK_INDEX = 3

def main(args):
    if len(args) < 4:
        log(f"ERROR: Wrong arguments: {args}")
        sys.exit(ERR_BAD_ARGUMENTS)
    log(" ".join(args[1:5]))
    process_args(args)

def log(msg):
    with open(LOG_FILE, 'a') as f:
        f.write(msg + "\n")

def process_args(args):
    alert_file = args[ALERT_INDEX]
    webhook = args[WEBHOOK_INDEX]
    
    alert = load_json(alert_file)
    msg = generate_msg(alert)
    send_msg(msg, webhook)

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        log(f"ERROR: Alert file not found: {path}")
        sys.exit(ERR_FILE_NOT_FOUND)
    except json.JSONDecodeError:
        log(f"ERROR: Invalid JSON in alert file: {path}")
        sys.exit(ERR_INVALID_JSON)

def generate_msg(alert):
    level = alert['rule']['level']
    if level <= 4:
        color = 'good'
    elif level <= 7:
        color = 'warning'
    else:
        color = 'danger'

    pre = alert['rule'].get('description', 'N/A')
    agent = alert.get('agent', {})
    agent_val = f"({agent.get('id','?')}) – {agent.get('name','?')}"
    rule_id = f"{alert['rule'].get('id','?')} (Level {level})"
    
    attachment = {
        "color": color,
        "pretext": "WAZUH Alert",
        "title": pre,
        "fields": [
            {"title": "Agent", "value": agent_val, "short": True},
            {"title": "Rule ID", "value": rule_id, "short": True}
        ],
        "ts": alert.get('id')
    }
    return json.dumps({"attachments": [attachment]})

def send_msg(msg, url):
    headers = {'Content-Type': 'application/json'}
    resp = requests.post(url, data=msg, headers=headers, timeout=10)
    log(f"Slack response: {resp.status_code} {resp.text}")

if __name__ == "__main__":
    main(sys.argv)
