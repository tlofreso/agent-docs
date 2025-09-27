---
search:
  exclude: true
---
# モデル

Agents SDK には、OpenAI モデルに対する 2 通りのサポートが標準で含まれています。

-   **推奨**: [`OpenAIResponsesModel`][agents.models.openai_responses.OpenAIResponsesModel]。新しい [Responses API](https://platform.openai.com/docs/api-reference/responses) を使って OpenAI API を呼び出します。
-   [`OpenAIChatCompletionsModel`][agents.models.openai_chatcompletions.OpenAIChatCompletionsModel]。 [Chat Completions API](https://platform.openai.com/docs/api-reference/chat) を使って OpenAI API を呼び出します。

## OpenAI モデル

`Agent` を初期化する際にモデルを指定しない場合、既定のモデルが使用されます。現在の既定は [`gpt-4.1`](https://platform.openai.com/docs/models/gpt-4.1) で、エージェント ワークフローの予測可能性と低レイテンシのバランスに優れています。

[`gpt-5`](https://platform.openai.com/docs/models/gpt-5) など他のモデルへ切り替えたい場合は、次のセクションの手順に従ってください。

### 既定の OpenAI モデル

カスタムモデルを設定していないすべてのエージェントで特定のモデルを一貫して使用したい場合は、エージェントを実行する前に `OPENAI_DEFAULT_MODEL` 環境変数を設定してください。

```bash
export OPENAI_DEFAULT_MODEL=gpt-5
python3 my_awesome_agent.py
```

#### GPT-5 モデル

[`gpt-5`](https://platform.openai.com/docs/models/gpt-5)、[`gpt-5-mini`](https://platform.openai.com/docs/models/gpt-5-mini)、または [`gpt-5-nano`](https://platform.openai.com/docs/models/gpt-5-nano) といった GPT-5 の推論モデルをこの方法で使用する場合、SDK は既定で妥当な `ModelSettings` を適用します。具体的には、`reasoning.effort` と `verbosity` の両方を `"low"` に設定します。これらの設定を自分で構成したい場合は、`agents.models.get_default_model_settings("gpt-5")` を呼び出してください。

さらに低レイテンシや特定の要件がある場合は、別のモデルや設定を選べます。既定モデルの推論負荷を調整するには、独自の `ModelSettings` を指定してください。

```python
from openai.types.shared import Reasoning
from agents import Agent, ModelSettings

my_agent = Agent(
    name="My Agent",
    instructions="You're a helpful agent.",
    model_settings=ModelSettings(reasoning=Reasoning(effort="minimal"), verbosity="low")
    # If OPENAI_DEFAULT_MODEL=gpt-5 is set, passing only model_settings works.
    # It's also fine to pass a GPT-5 model name explicitly:
    # model="gpt-5",
)
```

特に低レイテンシが必要な場合は、[`gpt-5-mini`](https://platform.openai.com/docs/models/gpt-5-mini) または [`gpt-5-nano`](https://platform.openai.com/docs/models/gpt-5-nano) に `reasoning.effort="minimal"` を組み合わせると、既定設定より高速に応答が返ることがよくあります。ただし、Responses API の一部の組み込みツール（たとえば ファイル検索 や 画像生成）は `"minimal"` の推論負荷をサポートしていないため、本 Agents SDK では既定を `"low"` にしています。

#### 非 GPT-5 モデル

カスタムの `model_settings` なしで GPT-5 以外のモデル名を渡した場合、SDK はあらゆるモデルに互換性のある汎用の `ModelSettings` にフォールバックします。

## 非 OpenAI モデル

[LiteLLM 連携](./litellm.md)を通じて、ほとんどの非 OpenAI モデルを使用できます。まず、litellm の依存関係グループをインストールします。

```bash
pip install "openai-agents[litellm]"
```

その後、`litellm/` プレフィックスを付けて、[サポート対象モデル](https://docs.litellm.ai/docs/providers) を使用します。

```python
claude_agent = Agent(model="litellm/anthropic/claude-3-5-sonnet-20240620", ...)
gemini_agent = Agent(model="litellm/gemini/gemini-2.5-flash-preview-04-17", ...)
```

### 非 OpenAI モデルの他の利用方法

他の LLM プロバイダーは、さらに 3 つの方法で統合できます（code examples は[こちら](https://github.com/openai/openai-agents-python/tree/main/examples/model_providers/)）。

1. [`set_default_openai_client`][agents.set_default_openai_client] は、LLM クライアントとして `AsyncOpenAI` のインスタンスをグローバルに使用したい場合に便利です。これは、LLM プロバイダーが OpenAI 互換の API エンドポイントを持ち、`base_url` と `api_key` を設定できる場合に使います。設定可能な例は [examples/model_providers/custom_example_global.py](https://github.com/openai/openai-agents-python/tree/main/examples/model_providers/custom_example_global.py) を参照してください。
2. [`ModelProvider`][agents.models.interface.ModelProvider] は `Runner.run` レベルで指定します。これにより、「この実行のすべてのエージェントでカスタムのモデルプロバイダーを使う」と指定できます。設定可能な例は [examples/model_providers/custom_example_provider.py](https://github.com/openai/openai-agents-python/tree/main/examples/model_providers/custom_example_provider.py) を参照してください。
3. [`Agent.model`][agents.agent.Agent.model] は、特定の Agent インスタンスでモデルを指定できます。これにより、エージェントごとに異なるプロバイダーを組み合わせて使用できます。設定可能な例は [examples/model_providers/custom_example_agent.py](https://github.com/openai/openai-agents-python/tree/main/examples/model_providers/custom_example_agent.py) を参照してください。ほとんどの利用可能なモデルを簡単に使う方法としては、[LiteLLM 連携](./litellm.md) が便利です。

`platform.openai.com` の API キーがない場合は、`set_tracing_disabled()` でトレーシングを無効化するか、[別のトレーシング プロセッサー](../tracing.md) を設定することを推奨します。

!!! note

    これらの code examples では、Responses API/モデルではなく Chat Completions API/モデルを使用しています。多くの LLM プロバイダーがまだ Responses API をサポートしていないためです。もしお使いの LLM プロバイダーがサポートしている場合は、Responses の使用を推奨します。

## モデルの組み合わせ

単一のワークフローの中で、エージェントごとに異なるモデルを使いたい場合があります。たとえば、振り分けには小さく高速なモデルを使い、複雑なタスクにはより大きく高機能なモデルを使うといった形です。[`Agent`][agents.Agent] を設定する際、次のいずれかで特定のモデルを選択できます。

1. モデル名を渡す。
2. 任意のモデル名 + その名前を Model インスタンスにマッピングできる [`ModelProvider`][agents.models.interface.ModelProvider] を渡す。
3. [`Model`][agents.models.interface.Model] 実装を直接渡す。

!!!note

    本 SDK は [`OpenAIResponsesModel`][agents.models.openai_responses.OpenAIResponsesModel] と [`OpenAIChatCompletionsModel`][agents.models.openai_chatcompletions.OpenAIChatCompletionsModel] の両方の形状をサポートしていますが、両者はサポートする機能やツールが異なるため、各ワークフローでは単一のモデル形状を使用することを推奨します。ワークフローでモデル形状を混在させる必要がある場合は、使用するすべての機能が両方で利用可能であることを確認してください。

```python
from agents import Agent, Runner, AsyncOpenAI, OpenAIChatCompletionsModel
import asyncio

spanish_agent = Agent(
    name="Spanish agent",
    instructions="You only speak Spanish.",
    model="gpt-5-mini", # (1)!
)

english_agent = Agent(
    name="English agent",
    instructions="You only speak English",
    model=OpenAIChatCompletionsModel( # (2)!
        model="gpt-5-nano",
        openai_client=AsyncOpenAI()
    ),
)

triage_agent = Agent(
    name="Triage agent",
    instructions="Handoff to the appropriate agent based on the language of the request.",
    handoffs=[spanish_agent, english_agent],
    model="gpt-5",
)

async def main():
    result = await Runner.run(triage_agent, input="Hola, ¿cómo estás?")
    print(result.final_output)
```

1.  OpenAI モデルの名前を直接設定します。
2.  [`Model`][agents.models.interface.Model] 実装を提供します。

エージェントで使用するモデルをさらに構成したい場合は、[`ModelSettings`][agents.models.interface.ModelSettings] を渡せます。これは temperature などの任意のモデル構成パラメーターを提供します。

```python
from agents import Agent, ModelSettings

english_agent = Agent(
    name="English agent",
    instructions="You only speak English",
    model="gpt-4.1",
    model_settings=ModelSettings(temperature=0.1),
)
```

また、OpenAI の Responses API を使用する場合、[他にもいくつかの任意パラメーター](https://platform.openai.com/docs/api-reference/responses/create)（例: `user`、`service_tier` など）があります。トップレベルで指定できない場合は、`extra_args` を使って渡せます。

```python
from agents import Agent, ModelSettings

english_agent = Agent(
    name="English agent",
    instructions="You only speak English",
    model="gpt-4.1",
    model_settings=ModelSettings(
        temperature=0.1,
        extra_args={"service_tier": "flex", "user": "user_12345"},
    ),
)
```

## 他の LLM プロバイダー使用時の一般的な問題

### トレーシング クライアント エラー 401

トレーシングに関連するエラーが発生する場合、トレースが OpenAI サーバーにアップロードされる一方で OpenAI の API キーをお持ちでないことが原因です。解決するには次の 3 つの選択肢があります。

1. トレーシングを完全に無効化する: [`set_tracing_disabled(True)`][agents.set_tracing_disabled]。
2. トレーシング用に OpenAI のキーを設定する: [`set_tracing_export_api_key(...)`][agents.set_tracing_export_api_key]。この API キーはトレースのアップロードのみに使用され、[platform.openai.com](https://platform.openai.com/) のものが必要です。
3. OpenAI 以外のトレース プロセッサーを使用する。[tracing ドキュメント](../tracing.md#custom-tracing-processors) を参照してください。

### Responses API のサポート

SDK は既定で Responses API を使用しますが、ほとんどの他社 LLM プロバイダーはまだサポートしていません。その結果、404 などの問題が発生することがあります。解決策は次の 2 つです。

1. [`set_default_openai_api("chat_completions")`][agents.set_default_openai_api] を呼び出す。これは環境変数で `OPENAI_API_KEY` と `OPENAI_BASE_URL` を設定している場合に機能します。
2. [`OpenAIChatCompletionsModel`][agents.models.openai_chatcompletions.OpenAIChatCompletionsModel] を使用する。code examples は[こちら](https://github.com/openai/openai-agents-python/tree/main/examples/model_providers/)。

### Structured outputs のサポート

一部のモデルプロバイダーは [structured outputs](https://platform.openai.com/docs/guides/structured-outputs) をサポートしていません。これにより、次のようなエラーが発生する場合があります。

```

BadRequestError: Error code: 400 - {'error': {'message': "'response_format.type' : value is not one of the allowed values ['text','json_object']", 'type': 'invalid_request_error'}}

```

これは一部プロバイダー側の不足によるもので、JSON 出力はサポートしていても、出力に使用する `json_schema` を指定できないことがあります。現在これに対する解決策に取り組んでいますが、JSON schema 出力をサポートするプロバイダーに依存することを推奨します。そうでない場合、JSON の不正構造によりアプリがしばしば動作しなくなるためです。

## プロバイダー間でのモデルの混在

モデルプロバイダー間の機能差を理解しておかないと、エラーに遭遇する可能性があります。たとえば、OpenAI は structured outputs、マルチモーダル入力、ホスト型の ファイル検索 および Web 検索 をサポートしますが、多くの他社プロバイダーはこれらの機能をサポートしません。以下の制限に注意してください。

-   サポートしていない `tools` を理解しないプロバイダーに送信しないでください
-   テキスト専用のモデルを呼び出す前に、マルチモーダル入力をフィルタリングしてください
-   構造化された JSON 出力をサポートしないプロバイダーは、無効な JSON を生成することがあります