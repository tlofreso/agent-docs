---
search:
  exclude: true
---
# REPL ユーティリティ

この SDK は、`run_demo_loop` を提供しており、ターミナル上でエージェントの挙動を素早く対話的にテストできます。

```python
import asyncio
from agents import Agent, run_demo_loop

async def main() -> None:
    agent = Agent(name="Assistant", instructions="You are a helpful assistant.")
    await run_demo_loop(agent)

if __name__ == "__main__":
    asyncio.run(main())
```

`run_demo_loop` はループでユーザー入力を促し、ターン間で会話履歴を保持します。デフォルトでは、生成と同時にモデル出力をストリーミングします。上記の例を実行すると、`run_demo_loop` は対話型チャットセッションを開始します。継続的に入力を求め、ターン間の会話全体の履歴を記憶するため（エージェントは何が議論されたかを把握できます）、生成されると同時にエージェントの応答をリアルタイムで自動的にストリーミングします。

このチャットセッションを終了するには、`quit` または `exit` と入力して（Enter を押す）か、`Ctrl-D` キーボードショートカットを使用します。