#!/bin/bash
# Kabuki 起動スクリプト - すべてをセットアップしてZellijを開始

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    nohup ./$script > logs/${name}.log 2>&1 &
    local pid=$!
    echo "$pid" > logs/${name}.pid
    echo "   PID: $pid"
}

# 既存のZellijセッションをチェック
if zellij list-sessions 2>/dev/null | grep -q "kabuki"; then
    echo "⚠️  既存のkabukiセッションが見つかりました"
    read -p "既存のセッションに接続しますか？ (y/N): " connect
    if [ "$connect" = "y" ] || [ "$connect" = "Y" ]; then
        zellij attach kabuki
        exit 0
    else
        echo "新しいセッションを作成します（既存のセッションは残ります）"
    fi
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

# Zellijを起動（レイアウトファイルを使用）
zellij --session kabuki --layout ./kabuki_layout.kdl

# Zellijが終了した後のクリーンアップ
echo ""
echo "🧹 クリーンアップ中..."

# バックグラウンドプロセスを停止
for pidfile in logs/*.pid; do
    if [ -f "$pidfile" ]; then
        pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            echo "   Stopping PID $pid..."
            kill "$pid" 2>/dev/null || true
        fi
        rm "$pidfile"
    fi
done

echo "✅ Kabuki セッション終了"
