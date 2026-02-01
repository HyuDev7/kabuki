#!/bin/bash
# Kabuki Orchestrator - Zellij統合版
# state.jsonを監視してエージェントを自動起動

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$PROJECT_ROOT/.orchestrator/state.json"
LOG_FILE="$PROJECT_ROOT/logs/orchestrator.log"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🎭 Kabuki Orchestrator 起動"

# jqのチェック
if ! command -v jq &> /dev/null; then
    log "❌ jq がインストールされていません"
    exit 1
fi

# 既に起動中のエージェントを追跡（スペース区切りの文字列）
RUNNING_AGENTS=""

# エージェントを起動する関数
launch_agent() {
    local task_id=$1
    local agent_type=$2

    log "🚀 Launching $agent_type for task $task_id"

    # Zellijの新しいペインでエージェントを起動
    # ペイン名を設定して見分けやすく
    zellij --session kabuki action new-pane --name "${agent_type}-${task_id}" --cwd "$PROJECT_ROOT" -- \
        bash -c "./agents/launch_agent.sh '$agent_type' '$task_id'"

    RUNNING_AGENTS="$RUNNING_AGENTS $task_id"
    
    # state.jsonのステータスを更新
    jq "(.tasks[] | select(.id==\"$task_id\")).status = \"running\"" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    
    log "✅ Agent $agent_type (task $task_id) launched in new pane"
}

# メインループ
log "👀 Monitoring $STATE_FILE for pending tasks..."

while true; do
    # pending状態のタスクを取得
    PENDING_TASKS=$(jq -r '.tasks[] | select(.status=="pending") | .id' "$STATE_FILE" 2>/dev/null || echo "")
    
    for task_id in $PENDING_TASKS; do
        # 既に起動中ならスキップ
        if echo "$RUNNING_AGENTS" | grep -q " $task_id"; then
            continue
        fi
        
        # タスク情報を取得
        AGENT_TYPE=$(jq -r ".tasks[] | select(.id==\"$task_id\") | .agent_type" "$STATE_FILE")
        
        # 依存関係をチェック
        DEPENDENCIES=$(jq -r ".tasks[] | select(.id==\"$task_id\") | .dependencies[]?" "$STATE_FILE")
        ALL_DEPS_COMPLETED=true
        
        for dep in $DEPENDENCIES; do
            DEP_STATUS=$(jq -r ".tasks[] | select(.id==\"$dep\") | .status" "$STATE_FILE")
            if [ "$DEP_STATUS" != "completed" ]; then
                ALL_DEPS_COMPLETED=false
                log "⏸️  Task $task_id waiting for dependency $dep (status: $DEP_STATUS)"
                break
            fi
        done
        
        # 依存関係が全て完了していればエージェントを起動
        if [ "$ALL_DEPS_COMPLETED" = true ]; then
            # implementerの場合、タスクファイルの存在を確認（最大30秒待機）
            if [ "$AGENT_TYPE" = "implementer" ]; then
                TASK_FILE="$PROJECT_ROOT/tasks/queue/task_${task_id}.md"
                WAIT_COUNT=0
                while [ ! -f "$TASK_FILE" ] && [ $WAIT_COUNT -lt 6 ]; do
                    log "⏳ Task $task_id waiting for task file: $TASK_FILE (attempt $((WAIT_COUNT + 1))/6)"
                    sleep 5
                    WAIT_COUNT=$((WAIT_COUNT + 1))
                done

                if [ ! -f "$TASK_FILE" ]; then
                    log "❌ Task $task_id: Task file not created after 30 seconds, skipping"
                    continue
                fi
            fi

            launch_agent "$task_id" "$AGENT_TYPE"
        fi
    done
    
    sleep 5
done
