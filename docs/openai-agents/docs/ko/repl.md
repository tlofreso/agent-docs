---
search:
  exclude: true
---
# REPL 유틸리티

SDK는 터미널에서 에이전트 동작을 빠르고 인터랙티브하게 테스트할 수 있는 `run_demo_loop`를 제공합니다.

```python
import asyncio
from agents import Agent, run_demo_loop

async def main() -> None:
    agent = Agent(name="Assistant", instructions="You are a helpful assistant.")
    await run_demo_loop(agent)

if __name__ == "__main__":
    asyncio.run(main())
```

`run_demo_loop`는 루프에서 사용자 입력을 요청하고, 턴 사이의 대화 기록을 유지합니다. 기본적으로 생성되는 대로 모델 출력을 스트리밍합니다. 위 예제를 실행하면, run_demo_loop가 인터랙티브 채팅 세션을 시작합니다. 지속적으로 입력을 요청하고, 턴 사이의 전체 대화 기록을 기억하여(에이전트가 논의된 내용을 알 수 있도록) 생성되는 즉시 에이전트의 응답을 실시간으로 자동 스트리밍합니다.

채팅 세션을 종료하려면 `quit` 또는 `exit`를 입력하고 Enter를 누르거나 `Ctrl-D` 키보드 단축키를 사용하세요.