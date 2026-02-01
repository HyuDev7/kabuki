#!/bin/bash
# Agent Launcher - 特定のエージェントを起動

AGENT_TYPE=$1
TASK_ID=$2
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "$AGENT_TYPE" ] || [ -z "$TASK_ID" ]; then
    echo "Usage: $0 <agent_type> <task_id>"
    exit 1
fi

cd "$PROJECT_ROOT"

# ログファイル
LOG_FILE="logs/agent_${AGENT_TYPE}_${TASK_ID}.log"
mkdir -p logs

echo "🤖 Starting $AGENT_TYPE agent for task $TASK_ID" | tee -a "$LOG_FILE"

# エージェントタイプに応じたプロンプトを設定
case $AGENT_TYPE in
    "architect")
        PROMPT="あなたは技術アーキテクトエージェントです。

役割:
- communication/to_architect.md を確認
- タスク${TASK_ID}の技術設計を行う
- 設計書を tech_design/ に保存
- 完了したら .orchestrator/completions.jsonl に通知を追記

重要:
- 作業完了時に必ず以下の形式で通知を追記してください:
  echo '{\"task_id\": \"${TASK_ID}\", \"agent\": \"architect\", \"status\": \"completed\", \"timestamp\": \"'$(date -Iseconds)'\"}' >> .orchestrator/completions.jsonl
"
        ;;
        
    "researcher")
        PROMPT="あなたはリサーチャーエージェントです。

役割:
- communication/to_researcher.md を確認
- タスク${TASK_ID}の調査を実施（web_searchツール使用）
- 調査結果を research/ に保存
- 完了したら .orchestrator/completions.jsonl に通知を追記

重要:
- 作業完了時に必ず以下の形式で通知を追記してください:
  echo '{\"task_id\": \"${TASK_ID}\", \"agent\": \"researcher\", \"status\": \"completed\", \"timestamp\": \"'$(date -Iseconds)'\"}' >> .orchestrator/completions.jsonl
"
        ;;
        
    "implementer")
        TASK_FILE="$PROJECT_ROOT/tasks/queue/task_${TASK_ID}.md"
        if [ ! -f "$TASK_FILE" ]; then
            echo "❌ Task file not found: $TASK_FILE" | tee -a "$LOG_FILE"
            exit 1
        fi

        TASK_CONTENT=$(cat "$TASK_FILE")
        PROMPT="あなたは実装エージェントです。

以下のタスクを実装してください:

---
$TASK_CONTENT
---

重要な指示:
1. 上記のタスク仕様に従って実装を行う
2. コードを implementation/ ディレクトリに保存
3. 完了したら以下を実行:
   - タスクファイルを移動: mv tasks/queue/task_${TASK_ID}.md tasks/completed/
   - 完了通知を追記: echo '{\"task_id\": \"${TASK_ID}\", \"agent\": \"implementer\", \"status\": \"completed\", \"timestamp\": \"'$(date -Iseconds)'\"}' >> .orchestrator/completions.jsonl

それでは、実装を開始してください。
"
        ;;
        
    "reviewer")
        PROMPT="あなたはコードレビュアーエージェントです。

役割:
- tasks/review/ のタスク${TASK_ID}をレビュー
- レビューコメントを追記
- 問題なければ tasks/completed/ に移動
- 完了したら .orchestrator/completions.jsonl に通知を追記

重要:
- 作業完了時に必ず以下の形式で通知を追記してください:
  echo '{\"task_id\": \"${TASK_ID}\", \"agent\": \"reviewer\", \"status\": \"completed\", \"timestamp\": \"'$(date -Iseconds)'\"}' >> .orchestrator/completions.jsonl
"
        ;;
        
    *)
        echo "❌ Unknown agent type: $AGENT_TYPE"
        exit 1
        ;;
esac

# Claude Codeを起動（対話モード）
echo "Starting claude code..." | tee -a "$LOG_FILE"
echo "$PROMPT" | claude code 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=$?
echo "Agent finished with exit code: $EXIT_CODE" | tee -a "$LOG_FILE"

# エラーの場合は失敗を記録
if [ $EXIT_CODE -ne 0 ]; then
    echo "{\"task_id\": \"$TASK_ID\", \"agent\": \"$AGENT_TYPE\", \"status\": \"failed\", \"timestamp\": \"$(date -Iseconds)\"}" >> .orchestrator/completions.jsonl
fi

exit $EXIT_CODE
