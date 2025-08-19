---
search:
  exclude: true
---
# SDK の設定

## API キーとクライアント

既定では、SDK はインポートされた直後から、LLM リクエストおよびトレーシング用に `OPENAI_API_KEY` 環境変数を探します。アプリ起動前にその環境変数を設定できない場合は、[set_default_openai_key()][agents.set_default_openai_key] 関数でキーを設定できます。

```python
from agents import set_default_openai_key

set_default_openai_key("sk-...")
```

また、使用する OpenAI クライアントを設定することもできます。既定では、SDK は環境変数または上記で設定した既定キーを使用して `AsyncOpenAI` インスタンスを作成します。これを変更するには、[set_default_openai_client()][agents.set_default_openai_client] 関数を使用します。

```python
from openai import AsyncOpenAI
from agents import set_default_openai_client

custom_client = AsyncOpenAI(base_url="...", api_key="...")
set_default_openai_client(custom_client)
```

最後に、使用する OpenAI API をカスタマイズすることもできます。既定では OpenAI Responses API を使用します。これを上書きして Chat Completions API を使用するには、[set_default_openai_api()][agents.set_default_openai_api] 関数を使用します。

```python
from agents import set_default_openai_api

set_default_openai_api("chat_completions")
```

## トレーシング

トレーシングは既定で有効です。既定では上記の OpenAI API キー（つまり環境変数または設定した既定キー）を使用します。トレーシングに使用する API キーを個別に設定するには、[`set_tracing_export_api_key`][agents.set_tracing_export_api_key] 関数を使用します。

```python
from agents import set_tracing_export_api_key

set_tracing_export_api_key("sk-...")
```

[`set_tracing_disabled()`][agents.set_tracing_disabled] 関数を使用して、トレーシング自体を無効にすることもできます。

```python
from agents import set_tracing_disabled

set_tracing_disabled(True)
```

## デバッグロギング

SDK にはハンドラーが設定されていない 2 つの Python ロガーがあります。既定では、警告とエラーは `stdout` に送られますが、その他のログは抑制されます。

詳細なログを有効にするには、[`enable_verbose_stdout_logging()`][agents.enable_verbose_stdout_logging] 関数を使用します。

```python
from agents import enable_verbose_stdout_logging

enable_verbose_stdout_logging()
```

または、ハンドラー、フィルター、フォーマッターなどを追加してログをカスタマイズできます。詳しくは [Python ロギングガイド](https://docs.python.org/3/howto/logging.html) を参照してください。

```python
import logging

logger = logging.getLogger("openai.agents") # or openai.agents.tracing for the Tracing logger

# To make all logs show up
logger.setLevel(logging.DEBUG)
# To make info and above show up
logger.setLevel(logging.INFO)
# To make warning and above show up
logger.setLevel(logging.WARNING)
# etc

# You can customize this as needed, but this will output to `stderr` by default
logger.addHandler(logging.StreamHandler())
```

### ログの機微なデータ

一部のログには機微なデータ（例: ユーザー データ）が含まれる場合があります。これらのデータがログに出力されないようにするには、次の環境変数を設定してください。

LLM の入力と出力のログ記録を無効にするには:

```bash
export OPENAI_AGENTS_DONT_LOG_MODEL_DATA=1
```

ツールの入力と出力のログ記録を無効にするには:

```bash
export OPENAI_AGENTS_DONT_LOG_TOOL_DATA=1
```