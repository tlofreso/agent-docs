---
search:
  exclude: true
---
# 트레이싱

[에이전트 트레이싱](../tracing.md) 방식과 마찬가지로, 음성 파이프라인도 자동으로 트레이싱됩니다.

기본적인 트레이싱 정보는 위 문서를 참고하시고, 추가로 [`VoicePipelineConfig`][agents.voice.pipeline_config.VoicePipelineConfig]를 통해 파이프라인 트레이싱을 구성할 수 있습니다.

트레이싱 관련 핵심 필드는 다음과 같습니다:

- [`tracing_disabled`][agents.voice.pipeline_config.VoicePipelineConfig.tracing_disabled]: 트레이싱 비활성화 여부를 제어합니다. 기본값은 활성화입니다
- [`trace_include_sensitive_data`][agents.voice.pipeline_config.VoicePipelineConfig.trace_include_sensitive_data]: 오디오 전사본과 같은 민감할 수 있는 데이터 포함 여부를 제어합니다. 이는 음성 파이프라인에만 해당하며, Workflow 내부에서 수행되는 작업에는 적용되지 않습니다
- [`trace_include_sensitive_audio_data`][agents.voice.pipeline_config.VoicePipelineConfig.trace_include_sensitive_audio_data]: 오디오 데이터 포함 여부를 제어합니다
- [`workflow_name`][agents.voice.pipeline_config.VoicePipelineConfig.workflow_name]: 트레이스 Workflow의 이름입니다
- [`group_id`][agents.voice.pipeline_config.VoicePipelineConfig.group_id]: 트레이스의 `group_id`로, 여러 트레이스를 연결할 수 있게 해줍니다
- [`trace_metadata`][agents.voice.pipeline_config.VoicePipelineConfig.tracing_disabled]: 트레이스에 포함할 추가 메타데이터입니다