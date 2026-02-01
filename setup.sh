#!/bin/bash
# Kabuki マルチエージェントシステム セットアップスクリプト

set -e

PROJECT_NAME="kabuki"
echo "🎭 Kabuki マルチエージェントシステム セットアップ"
echo ""

# プロジェクトディレクトリの作成
if [ -d "$PROJECT_NAME" ]; then
  echo "⚠️  $PROJECT_NAME ディレクトリが既に存在します"
  read -p "削除して再作成しますか? (y/N): " confirm
  if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    rm -rf "$PROJECT_NAME"
  else
    echo "セットアップを中止しました"
    exit 1
  fi
fi

echo "📁 ディレクトリ構造を作成中..."

mkdir -p "$PROJECT_NAME"/{.orchestrator,agents,communication,tasks/{queue,in_progress,review,completed},tech_design,research,implementation,logs}

# 初期state.jsonの作成
echo "📝 初期state.jsonを作成中..."
cat > "$PROJECT_NAME/.orchestrator/state.json" << 'EOF'
{
  "project": "Kabuki Multi-Agent System",
  "overall_status": "ready",
  "progress": 0,
  "tasks": []
}
EOF

# 空のcompletions.jsonlを作成
touch "$PROJECT_NAME/.orchestrator/completions.jsonl"

# 初期dashboard.mdの作成
echo "📊 初期dashboard.mdを作成中..."
cat > "$PROJECT_NAME/dashboard.md" << 'EOF'
# 🎭 Kabuki Dashboard

## プロジェクト状態
- **ステータス**: ready
- **進捗**: 0%
- **総タスク数**: 0

## アクティブなタスク
現在アクティブなタスクはありません

## 完了タスク
まだ完了したタスクはありません

---
最終更新: -
EOF

# README作成
echo "📖 READMEを作成中..."
cat > "$PROJECT_NAME/README.md" << 'EOF'
# 🎭 Kabuki - Claude Code マルチエージェントシステム

複数のClaude Codeインスタンスが協調して作業を行う自動化システム

## クイックスタート

```bash
# Zellijセッションを起動
./start_kabuki.sh

# 統括エージェント（左上ペイン）と対話を開始
```

## アーキテクチャ

- **統括エージェント**: あなたとの対話、タスク分解、進捗管理
- **実装エージェント**: 具体的なコード実装
- **ダッシュボード**: リアルタイム進捗表示

## ディレクトリ構造

```
kabuki/
├── .orchestrator/      # 状態管理
├── agents/             # エージェント起動スクリプト
├── tasks/              # タスクキュー
├── implementation/     # 実装コード
├── logs/               # ログファイル
└── dashboard.md        # 進捗ダッシュボード
```

## 開発者向け

Phase 1 PoC: 統括 + 実装エージェント1体 + ダッシュボード
EOF

echo "✅ セットアップ完了！"
echo ""
echo "次のステップ:"
echo "  cd $PROJECT_NAME"
echo "  ./start_kabuki.sh"
echo ""
