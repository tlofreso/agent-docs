---
search:
  exclude: true
---
# ガイド

このガイドでは、OpenAI Agents SDK の realtime 機能を使って音声対応の AI エージェントを構築する方法を詳しく説明します。

!!! warning "ベータ機能"
Realtime エージェントはベータ版です。実装の改善に伴い、互換性を損なう変更が発生する可能性があります。

## 概要

Realtime エージェントは、リアルタイムで音声とテキスト入力を処理し、リアルタイム音声で応答する会話フローを実現します。OpenAI の Realtime API と持続的な接続を維持し、低レイテンシで自然な音声対話を可能にし、割り込みにも適切に対応します。

## アーキテクチャ

### コアコンポーネント

realtime システムは、いくつかの主要コンポーネントで構成されます。

-   **RealtimeAgent**: instructions、tools、handoffs を設定したエージェントです。
-   **RealtimeRunner**: 構成を管理します。`runner.run()` を呼び出してセッションを取得できます。
-   **RealtimeSession**: 1 回の対話セッションです。通常は ユーザー が会話を開始するたびに作成し、会話が終了するまで維持します。
-   **RealtimeModel**: 基盤となるモデルインターフェース（通常は OpenAI の WebSocket 実装）

### セッションフロー

一般的な realtime セッションは、次のフローに従います。

1. **RealtimeAgent を作成** し、instructions、tools、handoffs を設定します。
2. **RealtimeRunner をセットアップ** し、エージェントと構成オプションを指定します。
3. **セッションを開始** します。`await runner.run()` を使用すると RealtimeSession が返されます。
4. **音声またはテキストメッセージを送信** します。`send_audio()` または `send_message()` を使用します。
5. **イベントをリッスン** します。セッションを反復処理してイベントを受け取ります。イベントには音声出力、書き起こし、ツール呼び出し、ハンドオフ、エラーが含まれます。
6. **割り込みに対応** します。ユーザー がエージェントの発話に重ねて話した場合、現在の音声生成は自動的に停止します。

セッションは会話履歴を保持し、realtime モデルとの持続的な接続を管理します。

## エージェントの設定

RealtimeAgent は通常の Agent クラスと同様に動作しますが、いくつか重要な違いがあります。完全な API の詳細は、[`RealtimeAgent`][agents.realtime.agent.RealtimeAgent] の API リファレンスをご覧ください。

通常のエージェントとの主な違い:

-   モデルの選択はエージェントレベルではなく、セッションレベルで構成します。
-   structured outputs はサポートされません（`outputType` は未対応です）。
-   音声はエージェントごとに設定できますが、最初のエージェントが発話した後は変更できません。
-   その他の機能（tools、handoffs、instructions）は同じように動作します。

## セッションの設定

### モデル設定

セッション構成では、基盤となる realtime モデルの動作を制御できます。モデル名（`gpt-4o-realtime-preview` など）、音声の選択（alloy、echo、fable、onyx、nova、shimmer）、対応するモダリティ（テキストおよび/または音声）を設定できます。音声フォーマットは入力・出力の両方で設定でき、デフォルトは PCM16 です。

### オーディオ設定

オーディオ設定は、セッションが音声の入出力をどのように処理するかを制御します。Whisper などのモデルを使用した入力音声の書き起こし、言語設定、専門用語の精度を高めるための書き起こしプロンプトを設定できます。ターン検出設定により、エージェントが応答を開始・終了するタイミングを制御できます（音声活動検出のしきい値、無音時間、検出音声の前後パディングのオプションを含む）。

## ツールと関数

### ツールの追加

通常のエージェントと同様に、realtime エージェントは会話中に実行される 関数ツール をサポートします。

```python
from agents import function_tool

@function_tool
def get_weather(city: str) -> str:
    """Get current weather for a city."""
    # Your weather API logic here
    return f"The weather in {city} is sunny, 72°F"

@function_tool
def book_appointment(date: str, time: str, service: str) -> str:
    """Book an appointment."""
    # Your booking logic here
    return f"Appointment booked for {service} on {date} at {time}"

agent = RealtimeAgent(
    name="Assistant",
    instructions="You can help with weather and appointments.",
    tools=[get_weather, book_appointment],
)
```

## ハンドオフ

### ハンドオフの作成

ハンドオフにより、専門化されたエージェント間で会話を引き継ぐことができます。

```python
from agents.realtime import realtime_handoff

# Specialized agents
billing_agent = RealtimeAgent(
    name="Billing Support",
    instructions="You specialize in billing and payment issues.",
)

technical_agent = RealtimeAgent(
    name="Technical Support",
    instructions="You handle technical troubleshooting.",
)

# Main agent with handoffs
main_agent = RealtimeAgent(
    name="Customer Service",
    instructions="You are the main customer service agent. Hand off to specialists when needed.",
    handoffs=[
        realtime_handoff(billing_agent, tool_description="Transfer to billing support"),
        realtime_handoff(technical_agent, tool_description="Transfer to technical support"),
    ]
)
```

## イベント処理

セッションは、セッションオブジェクトを反復処理することでリッスンできるイベントを ストリーミング します。イベントには、音声出力チャンク、書き起こし結果、ツール実行の開始と終了、エージェントのハンドオフ、エラーが含まれます。特に処理すべき主要イベントは次のとおりです。

-   **audio**: エージェントの応答からの raw 音声データ
-   **audio_end**: エージェントの発話が完了
-   **audio_interrupted**: ユーザー がエージェントを割り込み
-   **tool_start/tool_end**: ツール実行のライフサイクル
-   **handoff**: エージェントのハンドオフが発生
-   **error**: 処理中にエラーが発生

イベントの詳細は、[`RealtimeSessionEvent`][agents.realtime.events.RealtimeSessionEvent] をご覧ください。

## ガードレール

Realtime エージェントでサポートされるのは出力 ガードレール のみです。パフォーマンス問題を避けるため、これらの ガードレール はデバウンスされ、リアルタイム生成中に（毎語ではなく）定期的に実行されます。デフォルトのデバウンス長は 100 文字ですが、構成可能です。

ガードレール は `RealtimeAgent` に直接アタッチするか、セッションの `run_config` 経由で提供できます。両方のソースからの ガードレール は併せて実行されます。

```python
from agents.guardrail import GuardrailFunctionOutput, OutputGuardrail

def sensitive_data_check(context, agent, output):
    return GuardrailFunctionOutput(
        tripwire_triggered="password" in output,
        output_info=None,
    )

agent = RealtimeAgent(
    name="Assistant",
    instructions="...",
    output_guardrails=[OutputGuardrail(guardrail_function=sensitive_data_check)],
)
```

ガードレール がトリガーされると、`guardrail_tripped` イベントが生成され、エージェントの現在の応答を中断できます。デバウンスの動作により、安全性とリアルタイム性能要件のバランスを取ります。テキストエージェントと異なり、realtime エージェントは ガードレール が作動しても Exception を発生させません。

## オーディオ処理

[`session.send_audio(audio_bytes)`][agents.realtime.session.RealtimeSession.send_audio] を使って音声をセッションに送信するか、[`session.send_message()`][agents.realtime.session.RealtimeSession.send_message] を使ってテキストを送信します。

音声出力については、`audio` イベントをリッスンし、任意のオーディオライブラリで音声データを再生します。ユーザー がエージェントを割り込んだ際に即座に再生を停止し、キューにある音声をクリアするため、`audio_interrupted` イベントを必ずリッスンしてください。

## 直接モデルアクセス

基盤となるモデルにアクセスして、カスタムリスナーを追加したり高度な操作を実行したりできます。

```python
# Add a custom listener to the model
session.model.add_listener(my_custom_listener)
```

これにより、接続を低レベルに制御する必要がある高度なユースケース向けに、[`RealtimeModel`][agents.realtime.model.RealtimeModel] インターフェースへ直接アクセスできます。

## コード例

完全に動作するコード例は、[examples/realtime ディレクトリ](https://github.com/openai/openai-agents-python/tree/main/examples/realtime) をご覧ください。UI コンポーネントあり／なしのデモを含みます。