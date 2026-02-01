# Claude Code マルチエージェント完全自動化システム

## 全体の仕組み

```
[あなた] → 統括に指示「SMTP実装して」
    ↓
[統括] → タスク分解 & orchestration.json 更新
    ↓
[Watcherデーモン] → ファイル変更検知
    ↓
適切なエージェントを自動起動
    ↓ ↓ ↓
[アーキテクト] [リサーチャー] [実装エージェント×3]
    ↓
完了したら次のタスクをトリガー
    ↓
[統括] → dashboard.md 更新「80%完了」
```

## アーキテクチャ階層

```
[あなた] ← 対話 → [統括エージェント (Orchestrator)]
                         │
                         ├─ dashboard.md (常時更新)
                         ├─ .orchestrator/state.json (タスク状態管理)
                         └─ communication/
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   [アーキテクト]        [リサーチャー]         [レビュアー]
   tech_design/          research/             review/
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                    [実装エージェント群]
                    implementation/
                         ├─ agent_1/
                         ├─ agent_2/
                         └─ agent_3/
```

## コアコンポーネント

### 1. Orchestration Engine（orchestrator.sh）

```bash
#!/bin/bash
# メインのオーケストレーションループ

PROJECT_ROOT="/path/to/project"
STATE_FILE="$PROJECT_ROOT/.orchestrator/state.json"

while true; do
  # 状態ファイルを読む
  PENDING_TASKS=$(jq -r '.tasks[] | select(.status=="pending") | .id' $STATE_FILE)
  
  for task_id in $PENDING_TASKS; do
    TASK_FILE="$PROJECT_ROOT/tasks/queue/task_${task_id}.md"
    
    if [ -f "$TASK_FILE" ]; then
      AGENT_TYPE=$(jq -r ".tasks[] | select(.id==\"$task_id\") | .agent_type" $STATE_FILE)
      
      echo "🚀 Launching $AGENT_TYPE for task $task_id..."
      
      # エージェントを別プロセスで起動
      ./agents/launch_agent.sh "$AGENT_TYPE" "$task_id" &
      
      # 状態を更新
      jq ".tasks[] | select(.id==\"$task_id\") | .status = \"running\"" $STATE_FILE > tmp && mv tmp $STATE_FILE
    fi
  done
  
  sleep 5  # 5秒ごとにチェック（これはClaude外なのでトークン消費なし）
done
```

### 2. Agent Launcher（agents/launch_agent.sh）

```bash
#!/bin/bash
# 特定のエージェントを起動

AGENT_TYPE=$1
TASK_ID=$2
PROJECT_ROOT="/path/to/project"

case $AGENT_TYPE in
  "architect")
    PROMPT="あなたは技術アーキテクトです。communication/to_architect.md のタスク${TASK_ID}を処理してください。完了したら tech_design/ に設計書を保存し、orchestrator に通知してください。"
    ;;
  "researcher")
    PROMPT="あなたはリサーチャーです。communication/to_researcher.md のタスク${TASK_ID}を処理してください。web_searchを使って最新情報を調査し、research/ に結果を保存してください。"
    ;;
  "implementer")
    PROMPT="あなたは実装エージェントです。tasks/queue/task_${TASK_ID}.md を読んで実装してください。完了したらファイルを tasks/completed/ に移動してください。"
    ;;
  "reviewer")
    PROMPT="あなたはコードレビュアーです。tasks/review/ のタスク${TASK_ID}をレビューしてください。"
    ;;
esac

cd "$PROJECT_ROOT"
claude code -m "$PROMPT" > "logs/agent_${AGENT_TYPE}_${TASK_ID}.log" 2>&1

# 完了を通知
echo "{\"task_id\": \"$TASK_ID\", \"agent\": \"$AGENT_TYPE\", \"status\": \"completed\", \"timestamp\": \"$(date -Iseconds)\"}" >> .orchestrator/completions.jsonl
```

### 3. 統括エージェント用のプロトコル

統括が使うファイル形式：

```json
// .orchestrator/state.json
{
  "project": "SMTP Implementation",
  "overall_status": "in_progress",
  "progress": 35,
  "tasks": [
    {
      "id": "001",
      "type": "architecture",
      "agent_type": "architect",
      "status": "completed",
      "dependencies": [],
      "created_at": "2025-01-30T10:00:00Z",
      "completed_at": "2025-01-30T10:15:00Z"
    },
    {
      "id": "002",
      "type": "research",
      "agent_type": "researcher",
      "status": "running",
      "dependencies": ["001"],
      "created_at": "2025-01-30T10:15:00Z"
    },
    {
      "id": "003",
      "type": "implementation",
      "agent_type": "implementer",
      "status": "pending",
      "dependencies": ["001", "002"],
      "created_at": "2025-01-30T10:15:00Z"
    }
  ]
}
```

### 4. Completion Handler（完了通知の処理）

```bash
#!/bin/bash
# completions.jsonl を監視して次のタスクをアンロック

tail -f .orchestrator/completions.jsonl | while read line; do
  COMPLETED_TASK=$(echo $line | jq -r '.task_id')
  
  # この完了によってアンロックされるタスクを探す
  jq ".tasks[] | select(.dependencies[] == \"$COMPLETED_TASK\") | select(.status == \"blocked\") | .id" .orchestrator/state.json | while read blocked_task; do
    # 依存関係をチェック
    ALL_DEPS=$(jq -r ".tasks[] | select(.id == \"$blocked_task\") | .dependencies[]" .orchestrator/state.json)
    ALL_COMPLETED=true
    
    for dep in $ALL_DEPS; do
      DEP_STATUS=$(jq -r ".tasks[] | select(.id == \"$dep\") | .status" .orchestrator/state.json)
      if [ "$DEP_STATUS" != "completed" ]; then
        ALL_COMPLETED=false
        break
      fi
    done
    
    if [ "$ALL_COMPLETED" = true ]; then
      echo "🔓 Unlocking task $blocked_task"
      jq ".tasks[] | select(.id == \"$blocked_task\") | .status = \"pending\"" .orchestrator/state.json > tmp && mv tmp .orchestrator/state.json
    fi
  done
done
```

## ディレクトリ構造

```
project/
├── .orchestrator/
│   ├── state.json           # タスク状態管理
│   └── completions.jsonl    # 完了通知ログ
├── agents/
│   └── launch_agent.sh      # エージェント起動スクリプト
├── communication/
│   ├── to_architect.md      # アーキテクトへの依頼
│   ├── to_researcher.md     # リサーチャーへの依頼
│   └── from_*/              # 各エージェントからの返答
├── tasks/
│   ├── queue/               # 未着手タスク
│   ├── in_progress/         # 作業中タスク
│   ├── review/              # レビュー待ち
│   └── completed/           # 完了タスク
├── tech_design/             # 技術設計書
├── research/                # 調査結果
├── implementation/          # 実装コード
├── logs/                    # エージェント実行ログ
├── dashboard.md             # 進捗ダッシュボード
├── orchestrator.sh          # メインオーケストレーター
└── completion_handler.sh    # 完了ハンドラー
```

## 起動方法

```bash
# プロジェクトディレクトリで
./orchestrator.sh &  # バックグラウンドで常駐
./completion_handler.sh &  # これも常駐

# あとは統括エージェントと会話するだけ
claude code  # 統括として起動
```

## 統括エージェントとの会話例

```
[あなた] SMTP送信システムを実装してほしい。RFC準拠で、テスト可能な設計で。

[統括] 承知しました。以下のようにタスクを分解します：

タスク001: アーキテクチャ設計（依存なし）
タスク002: 最新のSMTP実装ベストプラクティス調査（依存なし）
タスク003: SMTPコマンドパーサー実装（依存: 001, 002）
タスク004: 接続管理モジュール実装（依存: 001）
タスク005: 統合テスト実装（依存: 003, 004）

state.jsonを更新しました。orchestratorが自動的にエージェントを起動します。
進捗はdashboard.mdで確認できます。

[5秒後、orchestrator.shが検知してアーキテクトとリサーチャーを同時起動]
```

## トークン消費の最適化ポイント

1. **Watcherは外部スクリプト**：bashなのでClaude使わない、トークン消費ゼロ
2. **エージェントは必要な時だけ起動**：タスクがある時だけ
3. **エージェントは完了したら終了**：待機しないので無駄なし
4. **統括だけがあなたと対話**：他のエージェントは裏で動く

## さらなる改善案

### 並列実行の最適化

```bash
# 依存関係のない複数タスクを同時起動
READY_TASKS=$(jq -r '.tasks[] | select(.status=="pending") | select(.dependencies | length == 0 or all(.[] | in($completed))) | .id' $STATE_FILE)

# 最大3並列で実行
echo "$READY_TASKS" | xargs -P 3 -I {} ./agents/launch_agent.sh {} &
```

### 優先度管理

```json
{
  "id": "003",
  "priority": "high",  // high, medium, low
  "agent_type": "implementer",
  ...
}
```

高優先度タスクを先に処理。

### エラーハンドリング

```json
{
  "id": "003",
  "status": "failed",
  "retry_count": 2,
  "max_retries": 3,
  "last_error": "依存モジュールが見つかりません"
}
```

失敗したタスクを自動リトライ。

## 実装ステップ

1. **Phase 1**: 基本的なorchestratorとagent launcherを作る
2. **Phase 2**: 統括エージェントがstate.jsonを更新できるようにする
3. **Phase 3**: 依存関係解決とアンロック機能
4. **Phase 4**: ダッシュボードのリアルタイム更新
5. **Phase 5**: エラーハンドリングとリトライ機構

## タスクファイルの例

### tasks/queue/task_001.md

```markdown
## Task: SMTPコマンドパーサー実装
Priority: HIGH
Dependencies: []
Assigned: (none)
Status: PENDING

### Technical Spec
- Input: Raw SMTP command string
- Output: Parsed command object
- Error handling: RFC 5321準拠
- Tests required: Yes

### Implementation Notes
詳細設計は tech_design/smtp_parser.md 参照

### Acceptance Criteria
- [ ] HELO, EHLO, MAIL FROM, RCPT TO, DATA, QUIT コマンドをパース可能
- [ ] 不正なコマンドに対して適切なエラーコードを返す
- [ ] ユニットテストカバレッジ90%以上
```

### communication/to_architect.md

```markdown
## Request #001
Task: SMTP送信システムの設計
Context: ユーザーがメール配送の学習用に実装したい
Requirements:
- RFC準拠
- テスタビリティ重視
- Docker環境で動作

Status: PENDING
Assigned: 2025-01-30 10:00

---

## Response #001
Status: COMPLETED
Completed: 2025-01-30 10:15

設計書を tech_design/smtp_system.md に作成しました。

主要コンポーネント：
1. SMTPCommandParser - コマンド解析
2. ConnectionManager - 接続管理
3. MessageQueue - メッセージキュー
4. DeliveryEngine - 配送エンジン

詳細は設計書を参照してください。
```
