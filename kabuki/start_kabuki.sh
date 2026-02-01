#!/bin/bash
# Kabuki 起動スクリプト - すべてをセットアップしてZellijを開始

set -e

# シンボリックリンクを解決して実際のスクリプトのパスを取得
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

echo "🎭 Kabuki マルチエージェントシステム 起動"
echo ""

# 必要なコマンドのチェック
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 がインストールされていません"
        echo "   インストール: brew install $1"
        exit 1
    fi
}

check_command zellij
check_command jq
check_command claude

# 実行権限を付与
chmod +x orchestrator.sh completion_handler.sh dashboard_watcher.sh agents/launch_agent.sh 2>/dev/null || true

# ログディレクトリの作成
mkdir -p logs

# orchestrator.logとcompletion_handler.logをクリア（新しいセッション用）
> logs/orchestrator.log
> logs/completion_handler.log

echo "✅ 環境チェック完了"
echo ""

# バックグラウンドプロセスを起動する関数
start_background_process() {
    local name=$1
    local script=$2

    echo "🚀 Starting $name..."
    cd "$PROJECT_ROOT"
    nohup "$PROJECT_ROOT/$script" > "$PROJECT_ROOT/logs/${name}.log" 2>&1 &
    local pid=$!
    echo "$pid" > "$PROJECT_ROOT/logs/${name}.pid"
    echo "   PID: $pid"
}

# 既存のZellijセッションをチェック・削除
if zellij list-sessions 2>/dev/null | grep -q "kabuki"; then
    echo "⚠️  既存のkabukiセッションが見つかりました"
    echo "🗑️  既存のセッションを削除しています..."
    zellij delete-session kabuki 2>/dev/null || true
    zellij kill-session kabuki 2>/dev/null || true
    sleep 1
    echo "✅ セッションを削除しました"
    echo ""
fi

echo ""
echo "📋 起動シーケンス:"
echo "   1. Orchestratorをバックグラウンドで起動"
echo "   2. Completion Handlerをバックグラウンドで起動"
echo "   3. Zellijセッション 'kabuki' を起動"
echo ""

# バックグラウンドプロセスを起動
start_background_process "orchestrator" "orchestrator.sh"
start_background_process "completion_handler" "completion_handler.sh"

echo ""
echo "⏱️  バックグラウンドプロセスの起動待機中..."
sleep 2

echo ""
echo "🎭 Zellijセッション起動中..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  使い方:"
echo "    - 左上ペイン: 統括エージェント (claude code で起動)"
echo "    - 右上ペイン: ダッシュボード (自動更新)"
echo "    - 下部ペイン: 実装エージェントが自動起動"
echo ""
echo "  統括エージェントの起動:"
echo "    左上ペインで 'claude code' を実行"
echo ""
echo "  終了方法:"
echo "    Ctrl+O → d (Zellijをデタッチ)"
echo "    または Ctrl+Q (Zellijを終了)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# レイアウトファイルを生成する前に、念のため再度セッションを削除
zellij delete-session kabuki 2>/dev/null || true
zellij kill-session kabuki 2>/dev/null || true

# レイアウトファイルを生成（テンプレートから）
echo "📝 レイアウトファイルを生成中..."
cat > "$PROJECT_ROOT/kabuki_layout.kdl" << EOF
// Kabuki Phase 1 レイアウト
// 統括エージェント + ダッシュボード + 実装エージェント

session_name "kabuki"

layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="🎭 Kabuki" {
        pane split_direction="vertical" {
            // 左側: 統括エージェント（自動起動）
            pane name="統括 (Orchestrator)" size="60%" {
                focus true
                command "bash"
                args "-c" "cd $PROJECT_ROOT && ./agents/start_orchestrator_agent.sh"
            }

            // 右側: ダッシュボード
            pane name="📊 Dashboard" {
                command "bash"
                args "-c" "cd $PROJECT_ROOT && ./dashboard_watcher.sh"
            }
        }

        // 下部: 実装エージェント（起動時は空）
        pane split_direction="horizontal" name="実装 (Implementer)" size="40%" {
            cwd "$PROJECT_ROOT"
        }
    }

    tab name="🔧 Orchestrator" {
        pane name="Orchestrator Log" {
            command "bash"
            args "-c" "cd $PROJECT_ROOT && tail -f logs/orchestrator.log"
        }
        pane name="Completions" {
            command "bash"
            args "-c" "cd $PROJECT_ROOT && tail -f .orchestrator/completions.jsonl | jq -C"
        }
    }
}
EOF

# Zellijを起動（レイアウトファイルを使用）
zellij --layout "$PROJECT_ROOT/kabuki_layout.kdl"

# Zellijが終了した後のクリーンアップ
echo ""
echo "🧹 クリーンアップ中..."

# ジョブコントロールメッセージを抑制
set +m

# バックグラウンドプロセスを停止
for pidfile in "$PROJECT_ROOT"/logs/*.pid; do
    if [ -f "$pidfile" ]; then
        pid=$(cat "$pidfile")
        name=$(basename "$pidfile" .pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo "   ✓ $name を停止中..."
            kill "$pid" 2>/dev/null || true
            sleep 0.2
        fi
        rm "$pidfile"
    fi
done

echo "✅ Kabuki セッション終了"
