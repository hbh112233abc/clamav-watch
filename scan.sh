#!/bin/bash

# 从环境变量读取配置（带默认值）
WATCH_DIR="${WATCH_DIR:-/scans}"
QUARANTINE_DIR="${QUARANTINE_DIR:-/quarantine}"
LOG_FILE="${LOG_FILE:-/var/log/clamav-scan.log}"
SCAN_DELAY="${SCAN_DELAY:-0.1}"

# 创建必要目录
mkdir -p "$QUARANTINE_DIR" "$(dirname "$LOG_FILE")"

echo "[$(date)] ClamAV Real-time Scanner Started" | tee -a "$LOG_FILE"
echo "Monitoring: $WATCH_DIR" | tee -a "$LOG_FILE"
echo "Quarantine: $QUARANTINE_DIR" | tee -a "$LOG_FILE"

# 每天更新病毒库（后台运行）
update_virus_db() {
    while true; do
        echo "[$(date)] Updating virus database..." >> "$LOG_FILE"
        freshclam >> "$LOG_FILE" 2>&1
        sleep 86400
    done
}
update_virus_db &

# 首次全量扫描（可选）
if [ "${SCAN_AT_STARTUP:-1}" = "1" ]; then
    echo "[$(date)] Performing initial scan..." | tee -a "$LOG_FILE"
    clamscan --recursive --infected --move="$QUARANTINE_DIR" "$WATCH_DIR" >> "$LOG_FILE" 2>&1
fi

# 实时监控文件变化
inotifywait -m -e create,moved_to --format '%w%f' "$WATCH_DIR" | while read FILE
do
    # 跳过临时文件
    if [[ "$FILE" =~ \.(part|tmp|swp|crdownload)$ ]] || [[ "$FILE" =~ /\. ]]; then
        continue
    fi

    # 短暂延迟，确保文件写入完成
    sleep "$SCAN_DELAY"

    # 检查文件是否还存在（可能已被移动）
    [ ! -f "$FILE" ] && continue

    # 扫描文件
    RESULT=$(clamscan --no-summary --infected --move="$QUARANTINE_DIR" "$FILE" 2>/dev/null)

    if echo "$RESULT" | grep -q "FOUND"; then
        VIRUS=$(echo "$RESULT" | awk -F': ' '{print $2}')
        echo "[$(date)] 🦠 VIRUS DETECTED: $FILE -> $VIRUS (moved to quarantine)" | tee -a "$LOG_FILE"
        
        # 可选：发送告警（需要额外配置 mail 或 curl）
        # echo "Virus detected: $VIRUS in $FILE" | mail -s "ClamAV Alert" admin@example.com
    else
        echo "[$(date)] ✅ CLEAN: $FILE" >> "$LOG_FILE"
    fi
done
