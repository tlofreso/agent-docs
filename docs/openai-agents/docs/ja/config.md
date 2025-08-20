---
search:
  exclude: true
---
# SDK の設定

## API キーとクライアント

デフォルトでは、 SDK はインポートされるとすぐに、 LLM リクエストとトレーシングのために `OPENAI_API_KEY` 環境変数を探します。アプリが起動する前にその環境変数を設定できない場合は、 [set_default_openai_key()][agents.set_default_openai_key] 関数でキーを設定できます。

```python
from agents import set_default_openai_key

set_default_openai_key("sk-...")
```

また、使用する OpenAI クライアントを設定することもできます。デフォルトでは、 SDK は `AsyncOpenAI` インスタンスを作成し、上記の環境変数またはデフォルトキーから API キーを使用します。これを変更するには、 [set_default_openai_client()][agents.set_default_openai_client] 関数を使用します。

```python
from openai import AsyncOpenAI
from agents import set_default_openai_client

custom_client = AsyncOpenAI(base_url="...", api_key="...")
set_default_openai_client(custom_client)
```

最後に、使用する OpenAI API をカスタマイズすることもできます。デフォルトでは OpenAI Responses API を使用します。 [set_default_openai_api()][agents.set_default_openai_api] 関数で、 Chat Completions API を使うように上書きできます。

```python
from agents import set_default_openai_api

set_default_openai_api("chat_completions")
```

## トレーシング

トレーシングはデフォルトで有効です。デフォルトでは、上記の OpenAI API キー（つまり環境変数または設定したデフォルトキー）を使用します。トレーシングに使用する API キーを個別に設定するには、 [`set_tracing_export_api_key`][agents.set_tracing_export_api_key] 関数を使用します。

```python
from agents import set_tracing_export_api_key

set_tracing_export_api_key("sk-...")
```

[`set_tracing_disabled()`][agents.set_tracing_disabled] 関数を使用すると、トレーシングを完全に無効にすることもできます。

```python
from agents import set_tracing_disabled

set_tracing_disabled(True)
```

## デバッグ ログ

SDK にはハンドラーが設定されていない Python ロガーが 2 つあります。デフォルトでは、これは警告とエラーが `stdout` に送られ、それ以外のログは抑制されることを意味します。

冗長なログを有効にするには、 [`enable_verbose_stdout_logging()`][agents.enable_verbose_stdout_logging] 関数を使用します。

```python
from agents import enable_verbose_stdout_logging

enable_verbose_stdout_logging()
```

また、ハンドラー、フィルター、フォーマッターなどを追加してログをカスタマイズできます。詳しくは [Python logging guide](https://docs.python.org/3/howto/logging.html) を参照してください。

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

一部のログには機微データ（例: ユーザー データ）が含まれる場合があります。これらのデータを記録しないようにするには、次の環境変数を設定してください。

LLM の入力と出力のログ記録を無効にするには:

```bash
export OPENAI_AGENTS_DONT_LOG_MODEL_DATA=1
```

ツールの入力と出力のログ記録を無効にするには:

```bash
export OPENAI_AGENTS_DONT_LOG_TOOL_DATA=1
```