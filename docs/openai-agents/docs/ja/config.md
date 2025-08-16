---
search:
  exclude: true
---
# SDK の設定

## API キーとクライアント

デフォルトでは、SDK はインポートされた直後から LLM リクエストと トレーシング のために `OPENAI_API_KEY` 環境変数を探します。アプリ起動前にその環境変数を設定できない場合は、[set_default_openai_key()][agents.set_default_openai_key] 関数でキーを設定できます。

```python
from agents import set_default_openai_key

set_default_openai_key("sk-...")
```

また、使用する OpenAI クライアントを設定することもできます。デフォルトでは、SDK は環境変数または上記で設定したデフォルト キーを用いて `AsyncOpenAI` インスタンスを作成します。これを変更するには、[set_default_openai_client()][agents.set_default_openai_client] 関数を使用します。

```python
from openai import AsyncOpenAI
from agents import set_default_openai_client

custom_client = AsyncOpenAI(base_url="...", api_key="...")
set_default_openai_client(custom_client)
```

さらに、使用する OpenAI API をカスタマイズできます。デフォルトでは OpenAI Responses API を使用します。これを上書きして Chat Completions API を使用するには、[set_default_openai_api()][agents.set_default_openai_api] 関数を使用します。

```python
from agents import set_default_openai_api

set_default_openai_api("chat_completions")
```

## トレーシング

トレーシング はデフォルトで有効です。デフォルトでは上記の OpenAI API キー（つまり、環境変数または設定したデフォルト キー）を使用します。トレーシング に使用する API キーを個別に設定するには、[`set_tracing_export_api_key`][agents.set_tracing_export_api_key] 関数を使用します。

```python
from agents import set_tracing_export_api_key

set_tracing_export_api_key("sk-...")
```

[`set_tracing_disabled()`][agents.set_tracing_disabled] 関数を使用して、トレーシング を完全に無効化することもできます。

```python
from agents import set_tracing_disabled

set_tracing_disabled(True)
```

## デバッグ ログ

SDK には、ハンドラーが設定されていない 2 つの Python ロガーがあります。デフォルトでは、警告とエラーは `stdout` に送られ、それ以外のログは抑制されます。

詳細なログを有効にするには、[`enable_verbose_stdout_logging()`][agents.enable_verbose_stdout_logging] 関数を使用します。

```python
from agents import enable_verbose_stdout_logging

enable_verbose_stdout_logging()
```

また、ハンドラー、フィルター、フォーマッターなどを追加してログをカスタマイズすることもできます。詳しくは [Python logging guide](https://docs.python.org/3/howto/logging.html) を参照してください。

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

### ログ内の機微データ

一部のログには機微なデータ（たとえば ユーザー データ）が含まれる場合があります。これらのデータがログに出力されないようにするには、以下の環境変数を設定してください。

LLM の入力と出力のログ記録を無効化するには:

```bash
export OPENAI_AGENTS_DONT_LOG_MODEL_DATA=1
```

ツールの入力と出力のログ記録を無効化するには:

```bash
export OPENAI_AGENTS_DONT_LOG_TOOL_DATA=1
```