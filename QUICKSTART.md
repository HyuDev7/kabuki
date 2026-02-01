# 🎭 Kabuki クイックスタートガイド

Zellij統合型マルチエージェントシステムの起動方法

## 📋 前提条件

以下がインストール済みであることを確認：

```bash
# バージョン確認
zellij --version  # 0.43.1 で確認済み
jq --version      # 1.8.1 で確認済み
claude --version  # Claude Code CLIツール
```

## 🚀 セットアップ（初回のみ）

### 1. ファイルを適切な場所に配置

```bash
# ダウンロードしたkabuki_systemディレクトリに移動
cd ~/path/to/kabuki_system

# セットアップスクリプトを実行
bash setup.sh
```

これで `kabuki/` ディレクトリが作成されます。

### 2. kabukiディレクトリに移動

```bash
cd kabuki
```

### 3. 必要なファイルをコピー

```bash
# 親ディレクトリから必要なスクリプトをコピー
cp ../orchestrator.sh .
cp ../completion_handler.sh .
cp ../dashboard_watcher.sh .
cp ../start_kabuki.sh .
cp ../kabuki_layout.kdl .
cp ../ORCHESTRATOR_GUIDE.md .
cp ../SAMPLE_TASK.md .
cp -r ../agents .

# 実行権限を付与
chmod +x *.sh agents/*.sh
```

## 🎬 起動方法

```bash
./start_kabuki.sh
```

これで自動的に：
1. Orchestratorがバックグラウンドで起動
2. Completion Handlerがバックグラウンドで起動
3. Zellijセッション 'kabuki' が開く

## 🖥️ Zellijレイアウト

起動すると以下のレイアウトが表示されます：

```
┌─────────────────────────┬───────────────┐
│ 統括 (Orchestrator)     │ 📊 Dashboard  │
│                         │               │
│ ここで claude code 実行 │ (自動更新)    │
│                         │               │
├─────────────────────────┴───────────────┤
│ 実装 (Implementer)                      │
│ (自動的にエージェントが起動される)      │
└─────────────────────────────────────────┘
```

## 📝 使い方

### 1. 統括エージェントを起動

左上のペインで：

```bash
claude code
```

起動後、`ORCHESTRATOR_GUIDE.md` の内容を参照しながら動作します。

### 2. タスクを依頼

統括エージェントに指示：

```
Hello Worldプログラムを作成してください
```

### 3. 自動実行を確認

- 統括が `state.json` と `tasks/queue/task_001.md` を作成
- Orchestratorが検知してImplementerエージェントを起動（下部ペインに表示）
- Dashboardに進捗が表示される

### 4. 完了を確認

- Dashboard: 100%完了を表示
- 統括エージェントが完了を報告

## 🔍 進捗確認

### ダッシュボード（右上ペイン）
リアルタイムで以下が表示：
- プロジェクト全体の進捗率
- アクティブなタスク
- 完了したタスク

### ログファイル
```bash
# Orchestratorログ
tail -f logs/orchestrator.log

# Completion Handlerログ
tail -f logs/completion_handler.log

# 各エージェントのログ
tail -f logs/agent_implementer_001.log
```

### state.jsonの確認
```bash
jq . .orchestrator/state.json
```

## 🛑 終了方法

### Zellijをデタッチ（セッションは残る）
```
Ctrl+O → d
```

再接続：
```bash
zellij attach kabuki
```

### Zellijを完全終了
```
Ctrl+Q
```

バックグラウンドプロセスも自動的にクリーンアップされます。

## 🐛 トラブルシューティング

### Orchestratorが起動しない
```bash
# ログを確認
cat logs/orchestrator.log
```

### エージェントが起動しない
1. `state.json` にタスクが追加されているか確認
2. Orchestratorログで依存関係エラーをチェック

### Dashboardが更新されない
```bash
# fswatch/inotifywaitがインストールされているか確認
which fswatch
# macOSの場合
brew install fswatch
```

### Zellijが見つからない
```bash
brew install zellij
```

## 📚 次のステップ

### Phase 2への拡張
- Architectエージェントの追加
- Researcherエージェントの追加
- より複雑な依存関係のテスト

### カスタマイズ
- `kabuki_layout.kdl` でレイアウト変更
- `agents/launch_agent.sh` でエージェントのプロンプト調整
- `dashboard_watcher.sh` でダッシュボード表示のカスタマイズ

## 💡 ヒント

1. **統括エージェントとの対話**は自然言語でOK
2. **複雑なタスク**は統括が自動的に分解
3. **並列実行**は依存関係がないタスクで自動的に発生
4. **エラー時**は統括が報告してくれる

楽しんでください！🎭
