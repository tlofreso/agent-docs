---
search:
  exclude: true
---
# 파이프라인과 워크플로

[`VoicePipeline`][agents.voice.pipeline.VoicePipeline]은 에이전트 기반 워크플로를 음성 앱으로 쉽게 전환할 수 있도록 해주는 클래스입니다. 실행할 워크플로를 전달하면, 파이프라인이 입력 오디오를 전사하고, 오디오 종료를 감지하고, 적절한 시점에 워크플로를 호출하며, 워크플로 출력을 다시 오디오로 변환해 제공합니다.

```mermaid
graph LR
    %% Input
    A["🎤 Audio Input"]

    %% Voice Pipeline
    subgraph Voice_Pipeline [Voice Pipeline]
        direction TB
        B["Transcribe (speech-to-text)"]
        C["Your Code"]:::highlight
        D["Text-to-speech"]
        B --> C --> D
    end

    %% Output
    E["🎧 Audio Output"]

    %% Flow
    A --> Voice_Pipeline
    Voice_Pipeline --> E

    %% Custom styling
    classDef highlight fill:#ffcc66,stroke:#333,stroke-width:1px,font-weight:700;

```

## 파이프라인 구성

파이프라인을 만들 때 다음을 설정할 수 있습니다:

1. 매번 새로운 오디오가 전사될 때 실행되는 코드인 [`workflow`][agents.voice.workflow.VoiceWorkflowBase]
2. 사용되는 [`speech-to-text`][agents.voice.model.STTModel] 및 [`text-to-speech`][agents.voice.model.TTSModel] 모델
3. 다음과 같은 항목을 구성할 수 있는 [`config`][agents.voice.pipeline_config.VoicePipelineConfig]
    - 모델 이름을 모델로 매핑할 수 있는 모델 프로바이더
    - 트레이싱: 트레이싱 비활성화 여부, 오디오 파일 업로드 여부, 워크플로 이름, 추적 ID 등
    - 프롬프트, 언어, 사용되는 데이터 타입 등 TTS 및 STT 모델 설정

## 파이프라인 실행

[`run()`][agents.voice.pipeline.VoicePipeline.run] 메서드를 통해 파이프라인을 실행할 수 있으며, 두 가지 형태로 오디오 입력을 전달할 수 있습니다:

1. 전체 오디오 전사본이 있고 그에 대한 결과만 생성하면 될 때는 [`AudioInput`][agents.voice.input.AudioInput]을 사용합니다. 이는 화자가 발화를 마치는 시점을 감지할 필요가 없는 경우, 예를 들어 사전 녹음된 오디오나 사용자가 말하기 종료 시점이 명확한 푸시투토크 앱에서 유용합니다
2. 사용자가 말을 마치는 시점을 감지해야 할 수도 있는 경우에는 [`StreamedAudioInput`][agents.voice.input.StreamedAudioInput]을 사용합니다. 감지되는 대로 오디오 청크를 푸시할 수 있으며, 음성 파이프라인은 "활동 감지(activity detection)"라는 과정을 통해 적절한 시점에 자동으로 에이전트 워크플로를 실행합니다

## 결과

음성 파이프라인 실행의 결과는 [`StreamedAudioResult`][agents.voice.result.StreamedAudioResult]입니다. 이는 이벤트가 발생하는 대로 스트리밍할 수 있도록 해주는 객체입니다. 다음과 같은 여러 종류의 [`VoiceStreamEvent`][agents.voice.events.VoiceStreamEvent]가 있습니다:

1. 오디오 청크를 포함하는 [`VoiceStreamEventAudio`][agents.voice.events.VoiceStreamEventAudio]
2. 턴 시작 또는 종료와 같은 라이프사이클 이벤트를 알려주는 [`VoiceStreamEventLifecycle`][agents.voice.events.VoiceStreamEventLifecycle]
3. 오류 이벤트인 [`VoiceStreamEventError`][agents.voice.events.VoiceStreamEventError]

```python

result = await pipeline.run(input)

async for event in result.stream():
    if event.type == "voice_stream_event_audio":
        # play audio
    elif event.type == "voice_stream_event_lifecycle":
        # lifecycle
    elif event.type == "voice_stream_event_error"
        # error
    ...
```

## 모범 사례

### 인터럽션(중단 처리)

Agents SDK는 현재 [`StreamedAudioInput`][agents.voice.input.StreamedAudioInput]에 대한 인터럽션(중단 처리) 내장 지원을 제공하지 않습니다. 대신 감지된 각 턴마다 워크플로의 별도 실행을 트리거합니다. 애플리케이션 내부에서 인터럽션을 처리하려면 [`VoiceStreamEventLifecycle`][agents.voice.events.VoiceStreamEventLifecycle] 이벤트를 수신하면 됩니다. `turn_started`는 새로운 턴이 전사되었고 처리가 시작됨을 나타냅니다. `turn_ended`는 해당 턴에 대한 모든 오디오가 디스패치된 후 트리거됩니다. 이러한 이벤트를 활용해 모델이 턴을 시작할 때 화자의 마이크를 음소거하고, 해당 턴과 관련된 오디오를 모두 플러시한 뒤 음소거를 해제할 수 있습니다.