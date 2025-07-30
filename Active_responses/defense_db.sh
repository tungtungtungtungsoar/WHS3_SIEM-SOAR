#!/bin/bash

#109998

SRCIP="$1"
LOGFILE="/var/ossec/logs/active-responses.log"
RECOVERY_SCRIPT="/tmp/recover_db2.sh"

echo "$(date) [ALERT] DB2 MySQL에서 Admln 계정 로그인 확인됨. 자동 격리 시작: $SRCIP" >> "$LOGFILE"

# 1. 네트워크 인터페이스 차단
IFACE=$(ip route | grep default | awk '{print $5}')
if [ -n "$IFACE" ]; then
    echo "[INFO] Disabling interface: $IFACE" >> "$LOGFILE"
    ip link set "$IFACE" down
else
    echo "[ERROR] 인터페이스 자동 탐지 실패" >> "$LOGFILE"
fi

# 2. MySQL 서비스 중단
echo "[INFO] Stopping MySQL" >> "$LOGFILE"
systemctl stop mysql >> "$LOGFILE" 2>&1

# 3. 백도어 의심 프로세스 탐지 및 종료
SUSPICIOUS_PROCS=$(ps aux | egrep 'nc|netcat|chisel|python3?.*-m http.server|socat|bash -i|/dev/tcp|tmux|screen|perl.*socket' | grep -v 'grep')
if [ -n "$SUSPICIOUS_PROCS" ]; then
    echo "[ALERT] 의심 프로세스 발견:" >> "$LOGFILE"
    echo "$SUSPICIOUS_PROCS" >> "$LOGFILE"

    echo "[ACTION] 백도어 관련 프로세스 kill 시도" >> "$LOGFILE"
    echo "$SUSPICIOUS_PROCS" | awk '{print $2}' | xargs -r kill -9
else
    echo "[OK] 의심 프로세스 없음" >> "$LOGFILE"
fi

# 4. 로그인된 사용자 세션 강제 종료
USERS=$(who | awk '{print $1}' | sort -u)
if [ -n "$USERS" ]; then
    echo "[ACTION] 로그인 사용자 강제 종료" >> "$LOGFILE"
    echo "$USERS" | while read user; do
        pkill -KILL -u "$user"
        echo "[KICK] $user 세션 종료" >> "$LOGFILE"
    done
else
    echo "[INFO] 현재 로그인된 사용자 없음" >> "$LOGFILE"
fi

echo "[DONE] DB2 완전 격리 및 유저 세션 종료 완료" >> "$LOGFILE"

# 5. 복구 스크립트 생성
cat <<EOF > "$RECOVERY_SCRIPT"
#!/bin/bash
ip link set "$IFACE" up
systemctl start mysql
echo "\$(date) DB2 자동 복구 수행됨" >> "$LOGFILE"
EOF

chmod +x "$RECOVERY_SCRIPT"

# 6. 10분뒤 복구작업
at now + 10 minutes -f "$RECOVERY_SCRIPT"

echo "[INFO] DB2 격리 조치 완료 (10분 후 자동 복구)" >> "$LOGFILEAc"

