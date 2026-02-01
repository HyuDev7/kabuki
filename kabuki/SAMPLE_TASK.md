# Phase 1 テスト用サンプルタスク

このファイルは統括エージェントがタスクを作成する際の参考例です。

## サンプルタスク: Hello World実装

統括エージェントに以下のように指示してください：

```
シンプルなHello Worldプログラムを作成してください。
- Pythonで実装
- 実装エージェントに依頼
```

統括エージェントは以下のようなstate.jsonを作成するべきです：

```json
{
  "project": "Hello World Test",
  "overall_status": "in_progress",
  "progress": 0,
  "tasks": [
    {
      "id": "001",
      "type": "implementation",
      "agent_type": "implementer",
      "status": "pending",
      "dependencies": [],
      "created_at": "2025-01-30T10:00:00Z",
      "description": "Python Hello Worldプログラムを実装"
    }
  ]
}
```

そして、tasks/queue/task_001.md を作成：

```markdown
## Task: Python Hello World実装
Priority: HIGH
Dependencies: []
Status: PENDING

### Technical Spec
- Python 3.x
- hello_world.py を implementation/ に作成
- "Hello, Kabuki!" と出力

### Implementation Notes
シンプルなprint文でOK

### Acceptance Criteria
- [ ] implementation/hello_world.py が作成されている
- [ ] 実行すると "Hello, Kabuki!" と表示される
```

## 期待される動作

1. 統括がstate.jsonとtasks/queue/task_001.mdを作成
2. orchestrator.shが検知してimplementerエージェントを起動
3. implementerがhello_world.pyを作成
4. implementerがcompletions.jsonlに完了通知
5. completion_handlerがstate.jsonを更新
6. ダッシュボードが100%完了を表示

## より複雑なテスト（Phase 2以降）

```
SMTP送信システムを実装してください。
- まずアーキテクトに設計を依頼
- 最新のベストプラクティスをリサーチ
- その後、実装エージェントに実装を依頼
```

これは複数のエージェントと依存関係を含む複雑なワークフローになります。
