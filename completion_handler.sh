#!/bin/bash
# Completion Handler - タスク完了を監視してstate.jsonを更新

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$PROJECT_ROOT/.orchestrator/state.json"
COMPLETIONS_FILE="$PROJECT_ROOT/.orchestrator/completions.jsonl"
LOG_FILE="$PROJECT_ROOT/logs/completion_handler.log"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🔔 Completion Handler 起動"

# completions.jsonlが存在しない場合は作成
touch "$COMPLETIONS_FILE"

# 進捗率を計算して更新する関数
update_progress() {
    TOTAL=$(jq '.tasks | length' "$STATE_FILE")
    if [ "$TOTAL" -eq 0 ]; then
        return
    fi
    
    COMPLETED=$(jq '[.tasks[] | select(.status=="completed")] | length' "$STATE_FILE")
    PROGRESS=$((COMPLETED * 100 / TOTAL))
    
    jq ".progress = $PROGRESS" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    log "📊 Progress updated: $PROGRESS% ($COMPLETED/$TOTAL)"
}

# タスク完了を処理する関数
process_completion() {
    local line=$1
    
    TASK_ID=$(echo "$line" | jq -r '.task_id')
    AGENT=$(echo "$line" | jq -r '.agent')
    STATUS=$(echo "$line" | jq -r '.status')
    TIMESTAMP=$(echo "$line" | jq -r '.timestamp')
    
    log "📬 Received completion: Task $TASK_ID | Agent: $AGENT | Status: $STATUS"
    
    # state.jsonを更新
    if [ "$STATUS" = "completed" ]; then
        jq "(.tasks[] | select(.id==\"$TASK_ID\")).status = \"completed\" | 
            (.tasks[] | select(.id==\"$TASK_ID\")).completed_at = \"$TIMESTAMP\"" \
            "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        
        log "✅ Task $TASK_ID marked as completed"
        
        # 進捗率を更新
        update_progress
        
        # 依存タスクのチェック（このタスクに依存していたタスクをアンロック）
        # orchestrator.shが自動的に検知して起動するので、ここでは特に何もしない
        
    elif [ "$STATUS" = "failed" ]; then
        jq "(.tasks[] | select(.id==\"$TASK_ID\")).status = \"failed\" | 
            (.tasks[] | select(.id==\"$TASK_ID\")).failed_at = \"$TIMESTAMP\"" \
            "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        
        log "❌ Task $TASK_ID marked as failed"
    fi
}

# メインループ - completions.jsonlを監視
log "👀 Monitoring $COMPLETIONS_FILE for completions..."

# 既存の行を処理（再起動時のため）
if [ -s "$COMPLETIONS_FILE" ]; then
    log "📜 Processing existing completions..."
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            process_completion "$line"
        fi
    done < "$COMPLETIONS_FILE"
fi

# 新しい行を監視
tail -f -n 0 "$COMPLETIONS_FILE" | while IFS= read -r line; do
    if [ -n "$line" ]; then
        process_completion "$line"
    fi
done
