---
search:
  exclude: true
---
# 트레이싱

Agents SDK에는 내장 트레이싱이 포함되어 있어 에이전트 실행 중 발생하는 이벤트의 포괄적인 기록을 수집합니다: LLM 생성, 도구 호출, 핸드오프, 가드레일, 그리고 발생하는 사용자 정의 이벤트까지 모두 포함합니다. [Traces 대시보드](https://platform.openai.com/traces)를 사용해 개발 중과 프로덕션에서 워크플로를 디버그하고, 시각화하며, 모니터링할 수 있습니다.

!!!note

    트레이싱은 기본적으로 활성화되어 있습니다. 트레이싱을 비활성화하는 방법은 두 가지입니다:

    1. 환경 변수 `OPENAI_AGENTS_DISABLE_TRACING=1` 를 설정하여 전역으로 비활성화
    2. 단일 실행에 대해 [`agents.run.RunConfig.tracing_disabled`][] 를 `True` 로 설정하여 비활성화

***OpenAI의 API를 사용하는 Zero Data Retention (ZDR) 정책 하에서 운영되는 조직의 경우, 트레이싱은 사용할 수 없습니다.***

## 트레이스와 스팬

-   **Traces** 는 "워크플로"의 단일 엔드 투 엔드 작업을 나타냅니다. 스팬으로 구성됩니다. 트레이스에는 다음 속성이 있습니다:
    -   `workflow_name`: 논리적 워크플로 또는 앱입니다. 예: "Code generation" 또는 "Customer service"
    -   `trace_id`: 트레이스의 고유 ID입니다. 전달하지 않으면 자동 생성됩니다. 형식은 `trace_<32_alphanumeric>` 이어야 합니다
    -   `group_id`: 선택적 그룹 ID로, 동일한 대화에서 나온 여러 트레이스를 연결합니다. 예를 들어 채팅 스레드 ID를 사용할 수 있습니다
    -   `disabled`: True이면 트레이스가 기록되지 않습니다
    -   `metadata`: 트레이스에 대한 선택적 메타데이터
-   **Spans** 는 시작 시간과 종료 시간이 있는 작업을 나타냅니다. 스팬에는 다음이 있습니다:
    -   `started_at` 및 `ended_at` 타임스탬프
    -   속한 트레이스를 나타내는 `trace_id`
    -   이 스팬의 상위 스팬(있을 경우)을 가리키는 `parent_id`
    -   스팬에 대한 정보인 `span_data`. 예를 들어 `AgentSpanData`는 에이전트에 대한 정보를, `GenerationSpanData`는 LLM 생성에 대한 정보를 포함합니다

## 기본 트레이싱

기본적으로, SDK는 다음을 트레이싱합니다:

-   전체 `Runner.{run, run_sync, run_streamed}()` 가 `trace()` 로 래핑됩니다
-   에이전트가 실행될 때마다 `agent_span()` 으로 래핑됩니다
-   LLM 생성은 `generation_span()` 으로 래핑됩니다
-   함수 도구 호출은 각각 `function_span()` 으로 래핑됩니다
-   가드레일은 `guardrail_span()` 으로 래핑됩니다
-   핸드오프는 `handoff_span()` 으로 래핑됩니다
-   오디오 입력(음성-텍스트)은 `transcription_span()` 으로 래핑됩니다
-   오디오 출력(텍스트-음성)은 `speech_span()` 으로 래핑됩니다
-   관련 오디오 스팬은 `speech_group_span()` 하위로 배치될 수 있습니다

기본적으로 트레이스 이름은 "Agent workflow"입니다. `trace` 를 사용하면 이 이름을 설정할 수 있으며, 또는 [`RunConfig`][agents.run.RunConfig] 로 이름과 기타 속성을 구성할 수 있습니다.

또한 [custom trace processors](#custom-tracing-processors) 를 설정하여 트레이스를 다른 대상으로 전송(대체 또는 보조 대상으로)할 수 있습니다.

## 상위 수준 트레이스

때로는 여러 번의 `run()` 호출을 하나의 트레이스에 포함하고 싶을 수 있습니다. 전체 코드를 `trace()` 로 래핑하면 됩니다.

```python
from agents import Agent, Runner, trace

async def main():
    agent = Agent(name="Joke generator", instructions="Tell funny jokes.")

    with trace("Joke workflow"): # (1)!
        first_result = await Runner.run(agent, "Tell me a joke")
        second_result = await Runner.run(agent, f"Rate this joke: {first_result.final_output}")
        print(f"Joke: {first_result.final_output}")
        print(f"Rating: {second_result.final_output}")
```

1. `Runner.run` 의 두 호출이 `with trace()` 로 래핑되어 있기 때문에, 개별 실행은 두 개의 트레이스를 생성하는 대신 전체 트레이스의 일부가 됩니다.

## 트레이스 생성

[`trace()`][agents.tracing.trace] 함수를 사용해 트레이스를 생성할 수 있습니다. 트레이스는 시작과 종료가 필요합니다. 다음 두 가지 방법이 있습니다:

1. **권장**: 컨텍스트 매니저로 사용합니다. 예: `with trace(...) as my_trace`. 적절한 시점에 트레이스를 자동으로 시작하고 종료합니다
2. 수동으로 [`trace.start()`][agents.tracing.Trace.start] 와 [`trace.finish()`][agents.tracing.Trace.finish] 를 호출할 수도 있습니다

현재 트레이스는 Python [`contextvar`](https://docs.python.org/3/library/contextvars.html) 를 통해 추적됩니다. 즉, 자동으로 동시성을 지원합니다. 트레이스를 수동으로 시작/종료하는 경우, 현재 트레이스를 업데이트하려면 `start()`/`finish()` 에 `mark_as_current` 및 `reset_current` 를 전달해야 합니다.

## 스팬 생성

여러 [`*_span()`][agents.tracing.create] 메서드를 사용해 스팬을 생성할 수 있습니다. 일반적으로 스팬을 수동으로 생성할 필요는 없습니다. 사용자 정의 스팬 정보를 추적하기 위한 [`custom_span()`][agents.tracing.custom_span] 함수가 제공됩니다.

스팬은 자동으로 현재 트레이스의 일부가 되며, Python [`contextvar`](https://docs.python.org/3/library/contextvars.html) 를 통해 추적되는 가장 가까운 현재 스팬 하위로 중첩됩니다.

## 민감 데이터

일부 스팬은 잠재적으로 민감한 데이터를 캡처할 수 있습니다.

`generation_span()` 은 LLM 생성의 입력/출력을 저장하고, `function_span()` 은 함수 호출의 입력/출력을 저장합니다. 민감한 데이터를 포함할 수 있으므로 [`RunConfig.trace_include_sensitive_data`][agents.run.RunConfig.trace_include_sensitive_data] 를 통해 해당 데이터 캡처를 비활성화할 수 있습니다.

마찬가지로, 오디오 스팬은 기본적으로 입력 및 출력 오디오에 대해 base64로 인코딩된 PCM 데이터를 포함합니다. [`VoicePipelineConfig.trace_include_sensitive_audio_data`][agents.voice.pipeline_config.VoicePipelineConfig.trace_include_sensitive_audio_data] 를 구성하여 이 오디오 데이터 캡처를 비활성화할 수 있습니다.

## 맞춤 트레이싱 프로세서

트레이싱의 상위 수준 아키텍처는 다음과 같습니다:

-   초기화 시, 트레이스를 생성하는 역할을 하는 전역 [`TraceProvider`][agents.tracing.setup.TraceProvider] 를 생성합니다
-   [`BatchTraceProcessor`][agents.tracing.processors.BatchTraceProcessor] 가 트레이스/스팬을 배치로 [`BackendSpanExporter`][agents.tracing.processors.BackendSpanExporter] 에 전달하도록 `TraceProvider` 를 구성합니다. Exporter 는 스팬과 트레이스를 OpenAI 백엔드로 배치 전송합니다

기본 설정을 사용자 정의하여 다른 백엔드로 전송하거나 추가 백엔드로 전송하거나, exporter 동작을 수정하려면 다음 두 가지 옵션이 있습니다:

1. [`add_trace_processor()`][agents.tracing.add_trace_processor] 는 트레이스와 스팬이 준비될 때 이를 수신하는 **추가** 트레이스 프로세서를 추가할 수 있게 해줍니다. 이를 통해 OpenAI 백엔드로 트레이스를 전송하는 것에 더해 자체 처리를 수행할 수 있습니다
2. [`set_trace_processors()`][agents.tracing.set_trace_processors] 는 기본 프로세서를 사용자의 트레이스 프로세서로 **교체** 할 수 있게 해줍니다. 이 경우 OpenAI 백엔드로 트레이스가 전송되지 않으며, 이를 수행하는 `TracingProcessor` 를 포함한 경우에만 전송됩니다

## 비 OpenAI 모델과 트레이싱

트레이싱을 비활성화할 필요 없이 OpenAI API 키를 비 OpenAI 모델과 함께 사용하여 OpenAI Traces 대시보드에서 무료 트레이싱을 활성화할 수 있습니다.

```python
import os
from agents import set_tracing_export_api_key, Agent, Runner
from agents.extensions.models.litellm_model import LitellmModel

tracing_api_key = os.environ["OPENAI_API_KEY"]
set_tracing_export_api_key(tracing_api_key)

model = LitellmModel(
    model="your-model-name",
    api_key="your-api-key",
)

agent = Agent(
    name="Assistant",
    model=model,
)
```

## 참고
- OpenAI Traces 대시보드에서 무료 트레이스를 확인하세요

## 외부 트레이싱 프로세서 목록

-   [Weights & Biases](https://weave-docs.wandb.ai/guides/integrations/openai_agents)
-   [Arize-Phoenix](https://docs.arize.com/phoenix/tracing/integrations-tracing/openai-agents-sdk)
-   [Future AGI](https://docs.futureagi.com/future-agi/products/observability/auto-instrumentation/openai_agents)
-   [MLflow (self-hosted/OSS)](https://mlflow.org/docs/latest/tracing/integrations/openai-agent)
-   [MLflow (Databricks hosted)](https://docs.databricks.com/aws/en/mlflow/mlflow-tracing#-automatic-tracing)
-   [Braintrust](https://braintrust.dev/docs/guides/traces/integrations#openai-agents-sdk)
-   [Pydantic Logfire](https://logfire.pydantic.dev/docs/integrations/llms/openai/#openai-agents)
-   [AgentOps](https://docs.agentops.ai/v1/integrations/agentssdk)
-   [Scorecard](https://docs.scorecard.io/docs/documentation/features/tracing#openai-agents-sdk-integration)
-   [Keywords AI](https://docs.keywordsai.co/integration/development-frameworks/openai-agent)
-   [LangSmith](https://docs.smith.langchain.com/observability/how_to_guides/trace_with_openai_agents_sdk)
-   [Maxim AI](https://www.getmaxim.ai/docs/observe/integrations/openai-agents-sdk)
-   [Comet Opik](https://www.comet.com/docs/opik/tracing/integrations/openai_agents)
-   [Langfuse](https://langfuse.com/docs/integrations/openaiagentssdk/openai-agents)
-   [Langtrace](https://docs.langtrace.ai/supported-integrations/llm-frameworks/openai-agents-sdk)
-   [Okahu-Monocle](https://github.com/monocle2ai/monocle)
-   [Galileo](https://v2docs.galileo.ai/integrations/openai-agent-integration#openai-agent-integration)
-   [Portkey AI](https://portkey.ai/docs/integrations/agents/openai-agents)
-   [LangDB AI](https://docs.langdb.ai/getting-started/working-with-agent-frameworks/working-with-openai-agents-sdk)
-   [Agenta](https://docs.agenta.ai/observability/integrations/openai-agents)