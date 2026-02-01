#!/bin/bash
# 統括エージェント自動起動スクリプト

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# ORCHESTRATOR_GUIDE.mdを読み込んで統括エージェントを起動
cat << EOF | claude code
$(cat ORCHESTRATOR_GUIDE.md)

---

あなたは上記のガイドに従って動作する統括エージェント（Orchestrator）です。

**重要な動作ルール:**
1. ユーザーからの依頼を受けたら、タスクに分解してstate.jsonに追加する
2. 自分で実装は書かない - 実装はimplementerエージェントに任せる
3. タスクファイル(tasks/queue/task_XXX.md)を作成する
4. orchestrator.shが自動的にエージェントを起動するのを待つ
5. 進捗はダッシュボードで確認する

準備ができました。ユーザーからの依頼をお待ちしています。
EOF
