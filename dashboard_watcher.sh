#!/bin/bash
# Dashboard Watcher - リアルタイムでstate.jsonを監視してダッシュボードを表示

STATE_FILE=".orchestrator/state.json"

# 色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

update_dashboard() {
    clear
    echo -e "${BOLD}🎭 Kabuki Dashboard${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ ! -f "$STATE_FILE" ]; then
        echo -e "${RED}⚠️  state.json が見つかりません${NC}"
        return
    fi
    
    # プロジェクト情報
    PROJECT=$(jq -r '.project' "$STATE_FILE")
    STATUS=$(jq -r '.overall_status' "$STATE_FILE")
    PROGRESS=$(jq -r '.progress' "$STATE_FILE")
    
    echo -e "${BOLD}プロジェクト:${NC} $PROJECT"
    echo -e "${BOLD}ステータス:${NC} $STATUS"
    echo -e "${BOLD}進捗:${NC} ${PROGRESS}%"
    
    # プログレスバー
    FILLED=$((PROGRESS / 5))
    EMPTY=$((20 - FILLED))
    echo -n "["
    for i in $(seq 1 $FILLED); do echo -n "█"; done
    for i in $(seq 1 $EMPTY); do echo -n "░"; done
    echo "]"
    echo ""
    
    # タスク統計
    TOTAL_TASKS=$(jq '.tasks | length' "$STATE_FILE")
    COMPLETED=$(jq '[.tasks[] | select(.status=="completed")] | length' "$STATE_FILE")
    RUNNING=$(jq '[.tasks[] | select(.status=="running")] | length' "$STATE_FILE")
    PENDING=$(jq '[.tasks[] | select(.status=="pending")] | length' "$STATE_FILE")
    FAILED=$(jq '[.tasks[] | select(.status=="failed")] | length' "$STATE_FILE")
    
    echo -e "${BOLD}タスク統計:${NC}"
    echo -e "  総数: $TOTAL_TASKS"
    echo -e "  ${GREEN}✓ 完了: $COMPLETED${NC}"
    echo -e "  ${YELLOW}⏳ 実行中: $RUNNING${NC}"
    echo -e "  ${BLUE}□ 待機中: $PENDING${NC}"
    if [ "$FAILED" -gt 0 ]; then
        echo -e "  ${RED}✗ 失敗: $FAILED${NC}"
    fi
    echo ""
    
    # アクティブなタスク
    if [ "$RUNNING" -gt 0 ]; then
        echo -e "${BOLD}${YELLOW}⏳ 実行中のタスク:${NC}"
        jq -r '.tasks[] | select(.status=="running") | "  ID: \(.id) | \(.type) | Agent: \(.agent_type)"' "$STATE_FILE"
        echo ""
    fi
    
    # 直近完了したタスク
    if [ "$COMPLETED" -gt 0 ]; then
        echo -e "${BOLD}${GREEN}✓ 直近の完了タスク (最大5件):${NC}"
        jq -r '.tasks[] | select(.status=="completed") | "  ID: \(.id) | \(.type) | 完了: \(.completed_at // "不明")"' "$STATE_FILE" | tail -5
        echo ""
    fi
    
    # 次のタスク
    if [ "$PENDING" -gt 0 ]; then
        echo -e "${BOLD}${BLUE}□ 次の待機タスク:${NC}"
        jq -r '.tasks[] | select(.status=="pending") | "  ID: \(.id) | \(.type) | Agent: \(.agent_type)"' "$STATE_FILE" | head -3
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "最終更新: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 初回表示
update_dashboard

# ファイル変更を監視（macOSではfswatch、Linuxではinotifywait）
if command -v fswatch &> /dev/null; then
    # macOS
    fswatch -o "$STATE_FILE" | while read; do
        update_dashboard
    done
elif command -v inotifywait &> /dev/null; then
    # Linux
    while inotifywait -e modify "$STATE_FILE" 2>/dev/null; do
        update_dashboard
    done
else
    # フォールバック: ポーリング
    echo "⚠️  fswatch/inotifywait が見つかりません。ポーリングモードで動作します"
    while true; do
        sleep 2
        update_dashboard
    done
fi
