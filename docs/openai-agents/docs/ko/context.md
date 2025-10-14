---
search:
  exclude: true
---
# 컨텍스트 관리

컨텍스트는 과부하된 용어입니다. 고려해야 할 컨텍스트에는 두 가지 주요 범주가 있습니다:

1. 코드에서 로컬로 사용할 수 있는 컨텍스트: 이는 도구 함수 실행 시, `on_handoff` 같은 콜백 동안, 라이프사이클 훅 등에서 필요할 수 있는 데이터와 의존성입니다
2. LLMs 에서 사용할 수 있는 컨텍스트: 이는 응답을 생성할 때 LLM 이 볼 수 있는 데이터입니다

## 로컬 컨텍스트

이는 [`RunContextWrapper`][agents.run_context.RunContextWrapper] 클래스와 그 안의 [`context`][agents.run_context.RunContextWrapper.context] 속성을 통해 표현됩니다. 동작 방식은 다음과 같습니다:

1. 원하는 어떤 Python 객체든 생성합니다. 일반적으로 dataclass 또는 Pydantic 객체를 사용합니다
2. 해당 객체를 다양한 실행 메서드에 전달합니다(예: `Runner.run(..., **context=whatever**)`)
3. 모든 도구 호출, 라이프사이클 훅 등에는 `RunContextWrapper[T]` 래퍼 객체가 전달되며, 여기서 `T` 는 컨텍스트 객체 타입을 나타내고 `wrapper.context` 를 통해 접근할 수 있습니다

가장 중요한 점: 특정 에이전트 실행에 대해 모든 에이전트, 도구 함수, 라이프사이클 등은 동일한 컨텍스트의 _타입_ 을 사용해야 합니다.

컨텍스트는 다음과 같은 용도로 사용할 수 있습니다:

- 실행을 위한 컨텍스트 데이터(예: 사용자 이름/uid 또는 사용자에 대한 기타 정보)
- 의존성(예: 로거 객체, 데이터 페처 등)
- 헬퍼 함수

!!! danger "주의"

    컨텍스트 객체는 LLM 에게 **전송되지 않습니다**. 순수하게 로컬 객체로, 읽고 쓰고 메서드를 호출할 수 있습니다.

```python
import asyncio
from dataclasses import dataclass

from agents import Agent, RunContextWrapper, Runner, function_tool

@dataclass
class UserInfo:  # (1)!
    name: str
    uid: int

@function_tool
async def fetch_user_age(wrapper: RunContextWrapper[UserInfo]) -> str:  # (2)!
    """Fetch the age of the user. Call this function to get user's age information."""
    return f"The user {wrapper.context.name} is 47 years old"

async def main():
    user_info = UserInfo(name="John", uid=123)

    agent = Agent[UserInfo](  # (3)!
        name="Assistant",
        tools=[fetch_user_age],
    )

    result = await Runner.run(  # (4)!
        starting_agent=agent,
        input="What is the age of the user?",
        context=user_info,
    )

    print(result.final_output)  # (5)!
    # The user John is 47 years old.

if __name__ == "__main__":
    asyncio.run(main())
```

1. 이것이 컨텍스트 객체입니다. 여기서는 dataclass 를 사용했지만, 어떤 타입이든 사용할 수 있습니다.
2. 이것은 도구입니다. `RunContextWrapper[UserInfo]` 를 받는 것을 볼 수 있습니다. 도구 구현은 컨텍스트에서 읽습니다.
3. 에이전트를 제네릭 `UserInfo` 로 표시하여, 타입 체커가 오류를 잡을 수 있게 합니다(예: 다른 컨텍스트 타입을 받는 도구를 전달하려고 할 때).
4. 컨텍스트는 `run` 함수로 전달됩니다.
5. 에이전트는 도구를 올바르게 호출하고 나이를 가져옵니다.

---

### 고급: `ToolContext`

일부 경우 실행 중인 도구에 대한 추가 메타데이터(이름, 호출 ID, 원문 인자 문자열 등)에 접근하고 싶을 수 있습니다.  
이를 위해 `RunContextWrapper` 를 확장한 [`ToolContext`][agents.tool_context.ToolContext] 클래스를 사용할 수 있습니다.

```python
from typing import Annotated
from pydantic import BaseModel, Field
from agents import Agent, Runner, function_tool
from agents.tool_context import ToolContext

class WeatherContext(BaseModel):
    user_id: str

class Weather(BaseModel):
    city: str = Field(description="The city name")
    temperature_range: str = Field(description="The temperature range in Celsius")
    conditions: str = Field(description="The weather conditions")

@function_tool
def get_weather(ctx: ToolContext[WeatherContext], city: Annotated[str, "The city to get the weather for"]) -> Weather:
    print(f"[debug] Tool context: (name: {ctx.tool_name}, call_id: {ctx.tool_call_id}, args: {ctx.tool_arguments})")
    return Weather(city=city, temperature_range="14-20C", conditions="Sunny with wind.")

agent = Agent(
    name="Weather Agent",
    instructions="You are a helpful agent that can tell the weather of a given city.",
    tools=[get_weather],
)
```

`ToolContext` 는 `RunContextWrapper` 와 동일한 `.context` 속성을 제공하며,  
현재 도구 호출에 특화된 추가 필드를 포함합니다:

- `tool_name` – 호출되는 도구의 이름  
- `tool_call_id` – 이 도구 호출의 고유 식별자  
- `tool_arguments` – 도구에 전달된 원문 인자 문자열  

실행 중 도구 수준 메타데이터가 필요할 때 `ToolContext` 를 사용하세요.  
에이전트와 도구 간 일반적인 컨텍스트 공유에는 `RunContextWrapper` 만으로 충분합니다.

---

## 에이전트/LLM 컨텍스트

LLM 이 호출될 때, LLM 이 볼 수 있는 **유일한** 데이터는 대화 이력뿐입니다. 따라서 LLM 에게 새로운 데이터를 제공하려면 해당 이력에 포함되도록 해야 합니다. 이를 수행하는 몇 가지 방법은 다음과 같습니다:

1. 에이전트 `instructions` 에 추가합니다. 이는 "시스템 프롬프트" 또는 "developer message" 라고도 합니다. 시스템 프롬프트는 정적인 문자열일 수도 있고, 컨텍스트를 받아 문자열을 출력하는 동적 함수일 수도 있습니다. 이는 항상 유용한 정보(예: 사용자 이름이나 현재 날짜)에 일반적으로 사용되는 방식입니다
2. `Runner.run` 함수를 호출할 때 `input` 에 추가합니다. 이는 `instructions` 방식과 유사하지만, [지휘 계통(chain of command)](https://cdn.openai.com/spec/model-spec-2024-05-08.html#follow-the-chain-of-command)에서 더 낮은 위치의 메시지를 사용할 수 있습니다
3. 함수 도구를 통해 노출합니다. 이는 _온디맨드_ 컨텍스트에 유용합니다. LLM 이 언제 데이터가 필요한지 결정하고, 해당 데이터를 가져오기 위해 도구를 호출할 수 있습니다
4. 검색(retrieval) 또는 웹 검색을 사용합니다. 이는 파일이나 데이터베이스에서 관련 데이터를 가져오거나(retrieval), 웹에서 가져올 수 있는(웹 검색) 특수 도구입니다. 이는 관련 컨텍스트 데이터에 기반해 응답을 "그라운딩"하는 데 유용합니다