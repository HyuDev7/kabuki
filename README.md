# Kabuki Multi-Agent System

複雑なタスクを並列ワークフローに分解し、専門化されたAIエージェントで自動化するClaude Code マルチエージェント・オーケストレーションシステム。

## 概要

**Kabuki**は、複数のClaude Codeインスタンスを協調させて動作させるBashベースのオーケストレーションフレームワークです。Zellij端末マルチプレクサを使用し、JSON状態ファイルとJSONL完了ログを通じてタスク依存関係を管理します。

### 主な特徴

- **マルチエージェント協調**: 複数のClaude Codeインスタンスが協調して動作
- **依存関係解決**: タスク間の依存関係を自動的に解決し、並列実行可能なタスクを検出
- **リアルタイム可視化**: Zellijを使用した3ペイン構成の直感的なUI
- **ステートマシンアーキテクチャ**: JSON/JSONLによる明確な状態管理
- **拡張可能な設計**: Phase 1（実装者）から Phase 5（完全自動化）まで段階的に拡張可能

## システムアーキテクチャ

```
ユーザー（自然言語リクエスト）
        ↓
    [オーケストレーターエージェント]
    (claude code - 常駐)
        ↓
        └─ タスク作成 & state.json更新
                ↓
        [orchestrator.sh デーモン]
        (Bash - state.jsonを監視)
                ↓
        依存関係が完了したpendingタスクを検出
                ↓
        [launch_agent.sh]
        適切なエージェントタイプを起動
                ↓
    ┌───────┬──────────┬──────────┐
    ↓       ↓          ↓          ↓
[実装者]  [アーキテクト] [リサーチャー] [レビュアー]
(並列実行可) (Phase 2+)  (Phase 2+)   (Phase 2+)
        ↓
    タスク完了、completions.jsonl経由で通知
        ↓
[completion_handler.sh デーモン]
state.json更新、依存タスクのアンロック
        ↓
[dashboard_watcher.sh]
リアルタイム進捗表示
```

## ディレクトリ構造

```
/Users/ryu/projects/kabuki/
├── .git/                          # Gitリポジトリ
├── .gitignore                     # state, tasks, logs, dashboardを除外
│
├── ルートスクリプト（kabuki/ディレクトリにコピー可能）:
├── orchestrator.sh                # メインデーモン
├── start_kabuki.sh                # ブートストラップスクリプト
├── launch_agent.sh                # エージェント起動スクリプト
├── completion_handler.sh          # 完了監視デーモン
├── dashboard_watcher.sh           # 進捗表示スクリプト
├── setup.sh                       # 初期セットアップ
├── kabuki_layout.kdl              # Zellijレイアウト定義
│
├── ドキュメント:
├── multi_agent_architecture.md    # 完全な設計ドキュメント
├── ORCHESTRATOR_GUIDE.md          # オーケストレーター操作マニュアル
├── QUICKSTART.md                  # セットアップガイド
├── SAMPLE_TASK.md                 # サンプルタスク
│
└── kabuki/ (作業ディレクトリ)
    ├── .orchestrator/
    │   ├── state.json            # 現在のタスク状態
    │   └── completions.jsonl     # 完了ログ
    │
    ├── .claude/
    │   └── settings.local.json   # Claude Code権限設定
    │
    ├── agents/
    │   ├── launch_agent.sh       # エージェント起動スクリプト（コピー）
    │   └── start_orchestrator_agent.sh  # メインエージェント起動
    │
    ├── tasks/
    │   ├── queue/                # 保留中タスク
    │   ├── in_progress/          # 実行中タスク
    │   ├── review/               # レビュー待ちタスク
    │   └── completed/            # 完了タスク
    │
    ├── communication/
    │   ├── to_architect.md       # アーキテクトへのリクエスト
    │   ├── to_researcher.md      # リサーチャーへのリクエスト
    │   └── from_*/               # エージェントからの応答
    │
    ├── tech_design/              # アーキテクチャ出力
    ├── research/                 # リサーチ出力
    ├── implementation/           # コード出力
    ├── logs/                     # 実行ログ
    │
    ├── README.md                 # クイックリファレンス
    ├── ORCHESTRATOR_GUIDE.md     # オーケストレーターガイド
    ├── SAMPLE_TASK.md            # サンプルタスク
    │
    └── dashboard.md              # ランタイム生成の進捗表示
```

## コンポーネント詳細

### Shellスクリプト（オーケストレーション層）

| スクリプト | 役割 | タイプ |
|-----------|------|-------|
| `orchestrator.sh` | コアデーモン - state.jsonを監視し、エージェントを起動 | デーモン |
| `start_kabuki.sh` | ブートストラップ - Zellijセッション設定、デーモン起動 | 初期化 |
| `launch_agent.sh` | エージェント起動 - ロール固有のプロンプトでClaude Codeを起動 | スポナー |
| `completion_handler.sh` | 完了監視 - completions.jsonlを監視し、state.jsonを更新 | デーモン |
| `dashboard_watcher.sh` | ダッシュボード更新 - state.jsonを監視し、Zellijペインに進捗表示 | モニター |
| `setup.sh` | 初期セットアップ - ディレクトリ構造とテンプレートファイルを作成 | 初期化 |

### エージェントタイプ

#### Phase 1（実装済み）

| エージェント | 役割 | 入力 | 出力 |
|-------------|------|------|------|
| **実装者** | コード開発 | `tasks/queue/task_XXX.md` | `implementation/` ファイル |

#### Phase 2+（設計済み、未実装）

| エージェント | 役割 | 入力 | 出力 |
|-------------|------|------|------|
| **アーキテクト** | 技術設計 | `communication/to_architect.md` | `tech_design/` ドキュメント |
| **リサーチャー** | 情報収集 | `communication/to_researcher.md` | `research/` レポート |
| **レビュアー** | コードレビュー | `tasks/review/task_XXX.md` | コメント & 承認 |

### データフロー

#### state.json（コア状態ファイル）

```json
{
  "project": "Kabuki Multi-Agent System",
  "overall_status": "in_progress",
  "progress": 0,
  "tasks": [
    {
      "id": "001",
      "type": "implementation",
      "agent_type": "implementer",
      "status": "running",
      "dependencies": [],
      "created_at": "2026-02-01T00:00:00+09:00",
      "description": "タスク説明",
      "completed_at": "オプション",
      "failed_at": "オプション"
    }
  ]
}
```

**タスクステータスのライフサイクル:**
```
pending → running → completed
                  └→ failed
```

#### completions.jsonl（完了追跡ファイル）

エージェントが完了通知を追記するJSONLファイル:

```json
{"task_id": "001", "agent": "implementer", "status": "completed", "timestamp": "2026-02-01T12:30:00Z"}
```

## 実行フロー

### 1. 初期化

```bash
./start_kabuki.sh
```

実行内容:
- 依存関係チェック（zellij, jq, claude）
- orchestrator.shをバックグラウンドで起動
- completion_handler.shをバックグラウンドで起動
- Zellijセッションをレイアウト付きで起動
  - 左ペイン: オーケストレーターエージェント（準備完了）
  - 右ペイン: ダッシュボード
  - 下ペイン: エージェント実行領域

### 2. タスク作成

ユーザーがオーケストレーターエージェントに指示（例: "Hello Worldプログラムを作成"）
↓
オーケストレーターが`ORCHESTRATOR_GUIDE.md`を読み込み
↓
`state.json`に新規タスクを作成/更新
↓
`tasks/queue/task_XXX.md`にタスク仕様を作成

### 3. タスク検出と依存関係解決

`orchestrator.sh`デーモンが5秒毎にstate.jsonをチェック
↓
各pendingタスクに対して:
- state.jsonから依存関係を取得
- すべての依存関係が"completed"かチェック
- 準備完了なら: エージェントを起動
- 準備未完なら: 待機（ログに"⏸️ Task waiting for dependency"）

### 4. エージェント実行

```bash
launch_agent.sh <agent_type> <task_id>
```

実行内容:
- タスクファイルを読み込み（実装者の場合）
- ロール固有のプロンプトを構築
- `claude code -m "$PROMPT"`を実行
- 出力を`logs/agent_${AGENT_TYPE}_${TASK_ID}.log`に記録

### 5. 完了通知

エージェントが作業完了後、completions.jsonlに追記:

```bash
echo '{"task_id": "001", "agent": "implementer", "status": "completed", ...}' >> .orchestrator/completions.jsonl
```

### 6. 状態更新

`completion_handler.sh`デーモンがcompletions.jsonlを`tail -f`で監視
↓
新規完了行を検出:
- state.jsonのタスクステータスを"completed"に更新
- 進捗を計算: `(完了 / 合計) * 100`
- すべてのタスクが完了した場合、overall_statusを更新

### 7. ダッシュボード表示

`dashboard_watcher.sh`がstate.jsonの変更を監視
↓
`fswatch`（macOS）または`inotifywait`（Linux）でファイル監視
↓
変更検出時: ダッシュボードを再描画
- プロジェクト名、ステータス、進捗%
- 進捗バーの視覚化
- ステータス別タスク数
- 現在実行中のタスク
- 最近完了したタスク
- 次の保留中タスク

### 8. 依存タスクのアンロック

タスク完了に伴い、orchestrator.shが新たにアンロック可能なタスクを自動検出
↓
すべての依存関係が完了したタスクが pending → running に遷移
↓
オーケストレーターが適切な順序でエージェントを起動（DAGを尊重）

## 依存関係

### システム要件

- **Zellij** (端末マルチプレクサ) v0.43.1+
- **jq** (JSONプロセッサ) v1.8.1+
- **Claude Code CLI**
- **Bash** 4.0+
- **fswatch** (macOS) または **inotifywait** (Linux) - ファイル監視用

### インストール

#### macOS (Homebrew)

```bash
brew install zellij jq fswatch
```

#### Linux (Ubuntu/Debian)

```bash
# Zellij
wget https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz
tar -xf zellij-x86_64-unknown-linux-musl.tar.gz
sudo mv zellij /usr/local/bin/

# jq と inotify-tools
sudo apt-get install jq inotify-tools
```

## クイックスタート

### 1. リポジトリをクローン

```bash
git clone <repository_url>
cd kabuki
```

### 2. 初期セットアップ実行

```bash
./setup.sh
```

これにより以下が作成されます:
- `kabuki/` 作業ディレクトリ
- `.orchestrator/` 状態管理ディレクトリ
- `tasks/`, `logs/`, `communication/` など
- 必要なテンプレートファイル

### 3. Kabukiを起動

```bash
./start_kabuki.sh
```

### 4. タスクを作成

左ペイン（オーケストレーター）で:

```
claude code
```

Claude Codeが起動したら、自然言語で指示:

```
Hello Worldプログラムを作成してください
```

### 5. 進捗を監視

右ペインのダッシュボードで進捗をリアルタイム確認。

## データフォーマット仕様

### state.jsonスキーマ

```json
{
  "project": "string",
  "overall_status": "ready|in_progress|completed|failed",
  "progress": 0-100,
  "tasks": [
    {
      "id": "001",
      "type": "implementation|architecture|research|review",
      "agent_type": "implementer|architect|researcher|reviewer",
      "status": "pending|running|completed|failed",
      "dependencies": ["001", "002"],
      "created_at": "ISO8601",
      "completed_at": "ISO8601 (オプション)",
      "failed_at": "ISO8601 (オプション)",
      "description": "string"
    }
  ]
}
```

### タスクファイルフォーマット (task_XXX.md)

```markdown
## Task: タイトル
Priority: HIGH|MEDIUM|LOW
Dependencies: [タスクIDのリスト]
Status: PENDING

### Technical Spec
- 詳細な仕様

### Implementation Notes
- ヒントとコンテキスト

### Acceptance Criteria
- [ ] 基準1
- [ ] 基準2
```

### 完了レコードフォーマット

```json
{"task_id": "001", "agent": "implementer", "status": "completed|failed", "timestamp": "ISO8601"}
```

## 設定

### Claude Code権限

`.claude/settings.local.json`:

```json
{
  "allowedPrompts": {
    "Bash": ["cat:*"]
  }
}
```

エージェントはファイルを読み取り可能ですが、書き込み操作には適切なプロンプティングが必要です。

### Zellijレイアウトのカスタマイズ

`kabuki_layout.kdl`を編集してペイン配置を変更:

```kdl
layout {
    pane split_direction="vertical" {
        pane name="orchestrator" size="40%"
        pane split_direction="horizontal" {
            pane name="dashboard" size="50%"
            pane name="implementer" size="50%"
        }
    }
}
```

### オーケストレーターのポーリング間隔

`orchestrator.sh`の`sleep 5`を変更して応答性と負荷のバランスを調整。

## トラブルシューティング

### Zellijが起動しない

```bash
# Zellijのバージョン確認
zellij --version

# 最新版をインストール
brew upgrade zellij  # macOS
```

### state.jsonが更新されない

```bash
# orchestrator.shが実行中か確認
ps aux | grep orchestrator.sh

# 手動で起動
./orchestrator.sh &
```

### ダッシュボードが表示されない

```bash
# dashboard_watcher.shが実行中か確認
ps aux | grep dashboard_watcher.sh

# fswatch/inotifywaitがインストールされているか確認
which fswatch  # macOS
which inotifywait  # Linux
```

### エージェントが起動しない

```bash
# launch_agent.shに実行権限があるか確認
chmod +x launch_agent.sh

# Claude Code CLIが利用可能か確認
which claude
```

## 今後の拡張計画

### Phase 2: マルチエージェントサポート
- アーキテクト、リサーチャーエージェントの実装
- エージェントタイプ間の依存関係チェーン
- 複雑なワークフローオーケストレーション

### Phase 3: 依存関係解決の最適化
- 並列タスク起動
- 優先度キュー管理

### Phase 4: ダッシュボード改善
- リアルタイムメトリクス
- 履歴追跡

### Phase 5: エラーハンドリングと復旧性
- 自動リトライ
- フォールバック戦略

## プロジェクトの哲学

Kabukiは以下の原則に基づいて設計されています:

1. **疎結合**: オーケストレーション（Bash）、状態（JSON）、UI（Zellij）、エージェント（Claude Code）の明確な分離
2. **ゼロトークンオーバーヘッド**: オーケストレーション層はトークンを消費しない
3. **段階的拡張**: Phase 1の単一エージェントからPhase 5の完全自動化まで、段階的に拡張可能
4. **透明性**: すべての状態がJSONファイルで人間可読
5. **復旧性**: ログとJSONL履歴による完全な監査証跡

## 貢献

このプロジェクトはPhase 1の概念実証です。改善提案や新機能のアイデアは歓迎します。

## ライセンス

（適切なライセンスを追加してください）

## 参考資料

- [multi_agent_architecture.md](./multi_agent_architecture.md) - 完全なアーキテクチャ設計
- [ORCHESTRATOR_GUIDE.md](./ORCHESTRATOR_GUIDE.md) - オーケストレーター操作マニュアル
- [QUICKSTART.md](./QUICKSTART.md) - クイックスタートガイド
- [SAMPLE_TASK.md](./SAMPLE_TASK.md) - サンプルタスク集

---

**Kabuki Multi-Agent System** - 複雑なタスクを並列ワークフローに分解し、AIエージェントで自動化する
