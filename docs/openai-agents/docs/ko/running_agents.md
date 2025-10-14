---
search:
  exclude: true
---
# 에이전트 실행

에이전트는 [`Runner`][agents.run.Runner] 클래스를 통해 실행할 수 있습니다. 선택지는 3가지입니다:

1. [`Runner.run()`][agents.run.Runner.run]: 비동기로 실행되며 [`RunResult`][agents.result.RunResult] 를 반환합니다.
2. [`Runner.run_sync()`][agents.run.Runner.run_sync]: 동기 메서드로, 내부적으로 `.run()` 을 실행합니다.
3. [`Runner.run_streamed()`][agents.run.Runner.run_streamed]: 비동기로 실행되며 [`RunResultStreaming`][agents.result.RunResultStreaming] 을 반환합니다. LLM 을 스트리밍 모드로 호출하고, 수신되는 대로 해당 이벤트를 스트림으로 제공합니다.

```python
from agents import Agent, Runner

async def main():
    agent = Agent(name="Assistant", instructions="You are a helpful assistant")

    result = await Runner.run(agent, "Write a haiku about recursion in programming.")
    print(result.final_output)
    # Code within the code,
    # Functions calling themselves,
    # Infinite loop's dance
```

자세한 내용은 [결과 가이드](results.md)에서 확인하세요.

## 에이전트 루프

`Runner` 의 run 메서드를 사용할 때 시작 에이전트와 입력을 전달합니다. 입력은 문자열(사용자 메시지로 간주) 또는 OpenAI Responses API 의 입력 아이템 리스트가 될 수 있습니다.

런너는 다음과 같은 루프를 실행합니다:

1. 현재 입력으로 현재 에이전트에 대해 LLM 을 호출합니다.
2. LLM 이 출력을 생성합니다.
    1. LLM 이 `final_output` 을 반환하면 루프를 종료하고 결과를 반환합니다.
    2. LLM 이 핸드오프를 수행하면 현재 에이전트와 입력을 갱신하고 루프를 다시 실행합니다.
    3. LLM 이 도구 호출을 생성하면 해당 도구 호출을 실행하고 결과를 추가한 뒤 루프를 다시 실행합니다.
3. 전달된 `max_turns` 를 초과하면 [`MaxTurnsExceeded`][agents.exceptions.MaxTurnsExceeded] 예외를 발생시킵니다.

!!! note

    LLM 출력이 "최종 출력" 으로 간주되는 규칙은, 원하는 타입의 텍스트 출력을 생성하고 도구 호출이 없을 때입니다.

## 스트리밍

스트리밍을 사용하면 LLM 이 실행되는 동안 스트리밍 이벤트를 추가로 수신할 수 있습니다. 스트림이 끝나면 [`RunResultStreaming`][agents.result.RunResultStreaming] 에는 실행에 대한 완전한 정보와 새로 생성된 모든 출력이 포함됩니다. 스트리밍 이벤트는 `.stream_events()` 로 호출할 수 있습니다. 자세한 내용은 [스트리밍 가이드](streaming.md)를 참고하세요.

## 실행 구성

`run_config` 매개변수로 에이전트 실행에 대한 전역 설정을 구성할 수 있습니다:

-   [`model`][agents.run.RunConfig.model]: 각 Agent 의 `model` 설정과 무관하게 사용할 전역 LLM 모델을 설정합니다.
-   [`model_provider`][agents.run.RunConfig.model_provider]: 모델 이름 조회를 위한 모델 공급자이며 기본값은 OpenAI 입니다.
-   [`model_settings`][agents.run.RunConfig.model_settings]: 에이전트별 설정을 재정의합니다. 예를 들어 전역 `temperature` 또는 `top_p` 를 설정할 수 있습니다.
-   [`input_guardrails`][agents.run.RunConfig.input_guardrails], [`output_guardrails`][agents.run.RunConfig.output_guardrails]: 모든 실행에 포함할 입력 또는 출력 가드레일의 리스트입니다.
-   [`handoff_input_filter`][agents.run.RunConfig.handoff_input_filter]: 핸드오프에 이미 입력 필터가 없을 경우 모든 핸드오프에 적용할 전역 입력 필터입니다. 입력 필터는 새 에이전트로 전송되는 입력을 편집할 수 있게 합니다. 자세한 내용은 [`Handoff.input_filter`][agents.handoffs.Handoff.input_filter] 문서를 참고하세요.
-   [`tracing_disabled`][agents.run.RunConfig.tracing_disabled]: 전체 실행에 대해 [트레이싱](tracing.md) 을 비활성화할 수 있습니다.
-   [`trace_include_sensitive_data`][agents.run.RunConfig.trace_include_sensitive_data]: LLM 및 도구 호출의 입력/출력과 같은 민감할 수 있는 데이터를 트레이스에 포함할지 구성합니다.
-   [`workflow_name`][agents.run.RunConfig.workflow_name], [`trace_id`][agents.run.RunConfig.trace_id], [`group_id`][agents.run.RunConfig.group_id]: 실행에 대한 트레이싱 워크플로 이름, 트레이스 ID, 트레이스 그룹 ID 를 설정합니다. 최소한 `workflow_name` 설정을 권장합니다. 그룹 ID 는 선택 필드로 여러 실행에 걸쳐 트레이스를 연결할 수 있습니다.
-   [`trace_metadata`][agents.run.RunConfig.trace_metadata]: 모든 트레이스에 포함할 메타데이터입니다.

## 대화/채팅 스레드

어떤 run 메서드를 호출하든 하나 이상의 에이전트가 실행될 수 있습니다(즉, 하나 이상의 LLM 호출). 하지만 이는 채팅 대화에서 하나의 논리적 턴을 의미합니다. 예:

1. 사용자 턴: 사용자가 텍스트 입력
2. Runner 실행: 첫 번째 에이전트가 LLM 을 호출하고 도구를 실행하며 두 번째 에이전트로 핸드오프, 두 번째 에이전트가 더 많은 도구를 실행한 뒤 출력을 생성

에이전트 실행이 끝나면 사용자에게 무엇을 보여줄지 선택할 수 있습니다. 예를 들어 에이전트가 생성한 모든 새 아이템을 보여주거나 최종 출력만 보여줄 수 있습니다. 어느 쪽이든, 사용자가 후속 질문을 할 수 있으며, 이 경우 run 메서드를 다시 호출하면 됩니다.

### 수동 대화 관리

다음 턴의 입력을 얻기 위해 [`RunResultBase.to_input_list()`][agents.result.RunResultBase.to_input_list] 메서드를 사용하여 대화 기록을 수동으로 관리할 수 있습니다:

```python
async def main():
    agent = Agent(name="Assistant", instructions="Reply very concisely.")

    thread_id = "thread_123"  # Example thread ID
    with trace(workflow_name="Conversation", group_id=thread_id):
        # First turn
        result = await Runner.run(agent, "What city is the Golden Gate Bridge in?")
        print(result.final_output)
        # San Francisco

        # Second turn
        new_input = result.to_input_list() + [{"role": "user", "content": "What state is it in?"}]
        result = await Runner.run(agent, new_input)
        print(result.final_output)
        # California
```

### Sessions 를 통한 자동 대화 관리

더 간단한 방법으로, [Sessions](sessions.md) 를 사용하면 `.to_input_list()` 를 수동으로 호출하지 않고도 대화 기록을 자동으로 처리할 수 있습니다:

```python
from agents import Agent, Runner, SQLiteSession

async def main():
    agent = Agent(name="Assistant", instructions="Reply very concisely.")

    # Create session instance
    session = SQLiteSession("conversation_123")

    thread_id = "thread_123"  # Example thread ID
    with trace(workflow_name="Conversation", group_id=thread_id):
        # First turn
        result = await Runner.run(agent, "What city is the Golden Gate Bridge in?", session=session)
        print(result.final_output)
        # San Francisco

        # Second turn - agent automatically remembers previous context
        result = await Runner.run(agent, "What state is it in?", session=session)
        print(result.final_output)
        # California
```

Sessions 는 자동으로 다음을 수행합니다:

-   매 실행 전 대화 기록을 조회
-   매 실행 후 새 메시지를 저장
-   서로 다른 세션 ID 별로 분리된 대화를 유지

자세한 내용은 [Sessions 문서](sessions.md)를 참고하세요.


### 서버 관리 대화

`to_input_list()` 또는 `Sessions` 로 로컬에서 관리하는 대신, OpenAI 대화 상태 기능에 서버 측 대화 상태 관리를 맡길 수도 있습니다. 이렇게 하면 과거 메시지를 모두 수동으로 다시 보내지 않고도 대화 기록을 보존할 수 있습니다. 자세한 내용은 [OpenAI Conversation state 가이드](https://platform.openai.com/docs/guides/conversation-state?api-mode=responses)를 참고하세요.

OpenAI 는 여러 턴에 걸친 상태 추적을 두 가지 방식으로 제공합니다:

#### 1. `conversation_id` 사용

먼저 OpenAI Conversations API 를 사용해 대화를 생성한 뒤, 이후 모든 호출에서 해당 ID 를 재사용합니다:

```python
from agents import Agent, Runner
from openai import AsyncOpenAI

client = AsyncOpenAI()

async def main():
    # Create a server-managed conversation
    conversation = await client.conversations.create()
    conv_id = conversation.id    

    agent = Agent(name="Assistant", instructions="Reply very concisely.")

    # First turn
    result1 = await Runner.run(agent, "What city is the Golden Gate Bridge in?", conversation_id=conv_id)
    print(result1.final_output)
    # San Francisco

    # Second turn reuses the same conversation_id
    result2 = await Runner.run(
        agent,
        "What state is it in?",
        conversation_id=conv_id,
    )
    print(result2.final_output)
    # California
```

#### 2. `previous_response_id` 사용

또 다른 방법은 **response chaining** 으로, 각 턴이 이전 턴의 response ID 에 명시적으로 연결됩니다.

```python
from agents import Agent, Runner

async def main():
    agent = Agent(name="Assistant", instructions="Reply very concisely.")

    # First turn
    result1 = await Runner.run(agent, "What city is the Golden Gate Bridge in?")
    print(result1.final_output)
    # San Francisco

    # Second turn, chained to the previous response
    result2 = await Runner.run(
        agent,
        "What state is it in?",
        previous_response_id=result1.last_response_id,
    )
    print(result2.final_output)
    # California
```


## 장기 실행 에이전트 및 휴먼인더루프

Agents SDK 의 [Temporal](https://temporal.io/) 통합을 사용하면 휴먼인더루프 (HITL) 작업을 포함한 내구성 있는 장기 실행 워크플로를 운영할 수 있습니다. Temporal 과 Agents SDK 가 함께 장기 실행 작업을 완료하는 데모는 [이 영상](https://www.youtube.com/watch?v=fFBZqzT4DD8)에서 확인하고, [여기 문서](https://github.com/temporalio/sdk-python/tree/main/temporalio/contrib/openai_agents)도 참고하세요.

## 예외

SDK 는 특정 경우에 예외를 발생시킵니다. 전체 목록은 [`agents.exceptions`][] 에 있습니다. 개요는 다음과 같습니다:

-   [`AgentsException`][agents.exceptions.AgentsException]: SDK 내에서 발생하는 모든 예외의 기본 클래스입니다. 다른 모든 구체적 예외가 파생되는 일반적 타입입니다.
-   [`MaxTurnsExceeded`][agents.exceptions.MaxTurnsExceeded]: 에이전트 실행이 `max_turns` 한도를 초과하여 `Runner.run`, `Runner.run_sync`, `Runner.run_streamed` 메서드에서 발생합니다. 지정된 상호작용 횟수 내에 에이전트가 작업을 완료하지 못했음을 나타냅니다.
-   [`ModelBehaviorError`][agents.exceptions.ModelBehaviorError]: 기본 모델(LLM) 이 예기치 않거나 잘못된 출력을 생성할 때 발생합니다. 예를 들면 다음을 포함할 수 있습니다:
    -   잘못된 JSON: 특히 특정 `output_type` 이 정의된 경우, 도구 호출용 또는 직접 출력으로 잘못된 JSON 구조를 제공하는 경우
    -   예기치 않은 도구 관련 실패: 모델이 예상 방식으로 도구를 사용하지 못한 경우
-   [`UserError`][agents.exceptions.UserError]: SDK 를 사용하는 코드 작성자인 귀하가 SDK 사용 중 오류를 범했을 때 발생합니다. 일반적으로 잘못된 코드 구현, 유효하지 않은 구성, SDK API 오사용에서 비롯됩니다.
-   [`InputGuardrailTripwireTriggered`][agents.exceptions.InputGuardrailTripwireTriggered], [`OutputGuardrailTripwireTriggered`][agents.exceptions.OutputGuardrailTripwireTriggered]: 각각 입력 가드레일 또는 출력 가드레일 조건이 충족될 때 발생합니다. 입력 가드레일은 처리 전에 들어오는 메시지를 확인하고, 출력 가드레일은 전달 전에 에이전트의 최종 응답을 확인합니다.