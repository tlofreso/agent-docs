---
search:
  exclude: true
---
# OpenAI Agents SDK

[OpenAI Agents SDK](https://github.com/openai/openai-agents-python)는 매우 적은 추상화로 가볍고 사용하기 쉬운 패키지에서 에이전트형 AI 앱을 빌드할 수 있게 해줍니다. 이는 이전 에이전트 실험인 [Swarm](https://github.com/openai/swarm/tree/main)의 프로덕션 준비된 업그레이드입니다. Agents SDK에는 매우 작은 기본 구성 요소 집합이 있습니다:

- **에이전트**, instructions와 도구를 갖춘 LLM
- **핸드오프**, 에이전트가 특정 작업을 다른 에이전트에 위임할 수 있게 함
- **가드레일**, 에이전트 입력과 출력을 검증할 수 있게 함
- **세션**, 에이전트 실행 간 대화 기록을 자동으로 유지 관리함

Python과 결합하면, 이러한 기본 구성 요소만으로도 도구와 에이전트 간 복잡한 관계를 표현할 수 있으며, 가파른 학습 곡선 없이 실제 애플리케이션을 구축할 수 있습니다. 또한 SDK에는 기본 제공 **트레이싱**이 포함되어 있어 에이전트 플로우를 시각화하고 디버깅할 수 있으며, 이를 평가하고 심지어 애플리케이션에 맞게 모델을 파인튜닝할 수도 있습니다.

## Agents SDK를 사용하는 이유

SDK의 핵심 설계 원칙은 두 가지입니다:

1. 사용할 가치가 있을 만큼 충분한 기능을 제공하되, 학습을 빠르게 할 수 있도록 기본 구성 요소는 최소화합니다
2. 기본 설정으로도 훌륭하게 작동하지만, 동작을 정확히 원하는 대로 커스터마이즈할 수 있습니다

SDK의 주요 기능은 다음과 같습니다:

- Agent loop: 도구 호출, 결과를 LLM에 전달, LLM이 완료될 때까지 루프를 수행하는 내장 에이전트 루프
- 파이썬 우선: 새로운 추상화를 배우지 않고도, 언어의 기본 기능을 사용해 에이전트를 오케스트레이션하고 체이닝
- 핸드오프: 여러 에이전트 간 조율 및 위임을 가능하게 하는 강력한 기능
- 가드레일: 에이전트와 병렬로 입력 검증과 점검을 수행하며, 실패 시 조기에 중단
- 세션: 에이전트 실행 전반에 걸친 대화 기록 자동 관리로 수동 상태 처리 불필요
- 함수 도구: 모든 Python 함수를 도구로 변환, 스키마 자동 생성 및 Pydantic 기반 검증 제공
- 트레이싱: 기본 제공 트레이싱으로 워크플로를 시각화, 디버그, 모니터링하고 OpenAI의 평가, 파인튜닝 및 디스틸레이션 도구 제품군을 활용할 수 있음

## 설치

```bash
pip install openai-agents
```

## Hello World 예제

```python
from agents import Agent, Runner

agent = Agent(name="Assistant", instructions="You are a helpful assistant")

result = Runner.run_sync(agent, "Write a haiku about recursion in programming.")
print(result.final_output)

# Code within the code,
# Functions calling themselves,
# Infinite loop's dance.
```

(_이를 실행하는 경우, `OPENAI_API_KEY` 환경 변수를 설정했는지 확인하세요_)

```bash
export OPENAI_API_KEY=sk-...
```