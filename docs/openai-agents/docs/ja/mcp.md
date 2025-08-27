---
search:
  exclude: true
---
# Model context protocol (MCP)

[Model context protocol](https://modelcontextprotocol.io/introduction)（別名 MCP）は、LLM にツールやコンテキストを提供するための方法です。MCP のドキュメントより引用します。

> MCP は、アプリケーションが LLM にコンテキストを提供する方法を標準化するオープンなプロトコルです。MCP は AI アプリケーション向けの USB‑C ポートのようなものだと考えてください。USB‑C がさまざまな周辺機器やアクセサリにデバイスを接続する標準化された方法を提供するのと同様に、MCP は AI モデルを異なるデータソースやツールに接続する標準化された方法を提供します。

Agents SDK は MCP をサポートしています。これにより、幅広い MCP サーバーを使用して、エージェントにツールやプロンプトを提供できます。

## MCP サーバー

現在、MCP の仕様では、使用するトランスポート方式に基づいて 3 種類のサーバーが定義されています。

1. **stdio** サーバーはアプリケーションのサブプロセスとして実行されます。いわば「ローカル」で動作します。
2. **HTTP over SSE** サーバーはリモートで実行され、URL で接続します。
3. **Streamable HTTP** サーバーは、MCP 仕様で定義された Streamable HTTP トランスポートを使用してリモートで実行されます。

これらのサーバーに接続するには、[`MCPServerStdio`][agents.mcp.server.MCPServerStdio]、[`MCPServerSse`][agents.mcp.server.MCPServerSse]、[`MCPServerStreamableHttp`][agents.mcp.server.MCPServerStreamableHttp] クラスを使用できます。

たとえば、[公式の MCP filesystem サーバー](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem)は次のように使用します。

```python
from agents.run_context import RunContextWrapper

async with MCPServerStdio(
    params={
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", samples_dir],
    }
) as server:
    # Note: In practice, you typically add the server to an Agent
    # and let the framework handle tool listing automatically.
    # Direct calls to list_tools() require run_context and agent parameters.
    run_context = RunContextWrapper(context=None)
    agent = Agent(name="test", instructions="test")
    tools = await server.list_tools(run_context, agent)
```

## MCP サーバーの使用

MCP サーバーはエージェントに追加できます。Agents SDK は、エージェントの実行ごとに MCP サーバー上で `list_tools()` を呼び出します。これにより、LLM は MCP サーバーのツールを認識できます。LLM が MCP サーバーのツールを呼び出すと、SDK はそのサーバーで `call_tool()` を呼び出します。

```python

agent=Agent(
    name="Assistant",
    instructions="Use the tools to achieve the task",
    mcp_servers=[mcp_server_1, mcp_server_2]
)
```

## ツールのフィルタリング

MCP サーバーでツールフィルターを設定することで、エージェントで使用可能なツールを絞り込めます。SDK は静的フィルタリングと動的フィルタリングの両方をサポートします。

### 静的ツールフィルタリング

単純な許可 / ブロックリストには、静的フィルタリングを使用できます。

```python
from agents.mcp import create_static_tool_filter

# Only expose specific tools from this server
server = MCPServerStdio(
    params={
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", samples_dir],
    },
    tool_filter=create_static_tool_filter(
        allowed_tool_names=["read_file", "write_file"]
    )
)

# Exclude specific tools from this server
server = MCPServerStdio(
    params={
        "command": "npx", 
        "args": ["-y", "@modelcontextprotocol/server-filesystem", samples_dir],
    },
    tool_filter=create_static_tool_filter(
        blocked_tool_names=["delete_file"]
    )
)

```

**`allowed_tool_names` と `blocked_tool_names` の両方が設定されている場合の処理順序は次のとおりです。**
1. まず `allowed_tool_names`（許可リスト）を適用 — 指定したツールのみを残します
2. 次に `blocked_tool_names`（ブロックリスト）を適用 — 残ったツールから指定したツールを除外します

たとえば、`allowed_tool_names=["read_file", "write_file", "delete_file"]` と `blocked_tool_names=["delete_file"]` を設定すると、利用可能なのは `read_file` と `write_file` のみになります。

### 動的ツールフィルタリング

より複雑なフィルタリングロジックには、関数を用いた動的フィルターを使用できます。

```python
from agents.mcp import ToolFilterContext

# Simple synchronous filter
def custom_filter(context: ToolFilterContext, tool) -> bool:
    """Example of a custom tool filter."""
    # Filter logic based on tool name patterns
    return tool.name.startswith("allowed_prefix")

# Context-aware filter
def context_aware_filter(context: ToolFilterContext, tool) -> bool:
    """Filter tools based on context information."""
    # Access agent information
    agent_name = context.agent.name

    # Access server information  
    server_name = context.server_name

    # Implement your custom filtering logic here
    return some_filtering_logic(agent_name, server_name, tool)

# Asynchronous filter
async def async_filter(context: ToolFilterContext, tool) -> bool:
    """Example of an asynchronous filter."""
    # Perform async operations if needed
    result = await some_async_check(context, tool)
    return result

server = MCPServerStdio(
    params={
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", samples_dir],
    },
    tool_filter=custom_filter  # or context_aware_filter or async_filter
)
```

`ToolFilterContext` では次の項目にアクセスできます。
- `run_context`: 現在の実行コンテキスト
- `agent`: ツールを要求しているエージェント
- `server_name`: MCP サーバー名

## プロンプト

MCP サーバーは、エージェントの instructions を動的に生成するためのプロンプトも提供できます。これにより、パラメーターでカスタマイズ可能な再利用可能な instructions テンプレートを作成できます。

### プロンプトの使用

プロンプトに対応した MCP サーバーは、次の 2 つの重要なメソッドを提供します。

- `list_prompts()`: サーバー上の利用可能なすべてのプロンプトを一覧表示
- `get_prompt(name, arguments)`: オプションのパラメーター付きで特定のプロンプトを取得

```python
# List available prompts
prompts_result = await server.list_prompts()
for prompt in prompts_result.prompts:
    print(f"Prompt: {prompt.name} - {prompt.description}")

# Get a specific prompt with parameters
prompt_result = await server.get_prompt(
    "generate_code_review_instructions",
    {"focus": "security vulnerabilities", "language": "python"}
)
instructions = prompt_result.messages[0].content.text

# Use the prompt-generated instructions with an Agent
agent = Agent(
    name="Code Reviewer",
    instructions=instructions,  # Instructions from MCP prompt
    mcp_servers=[server]
)
```

## キャッシュ

エージェントが実行されるたびに、MCP サーバーで `list_tools()` が呼び出されます。特にリモートサーバーの場合、これはレイテンシーの要因になり得ます。ツール一覧を自動的にキャッシュするには、[`MCPServerStdio`][agents.mcp.server.MCPServerStdio]、[`MCPServerSse`][agents.mcp.server.MCPServerSse]、[`MCPServerStreamableHttp`][agents.mcp.server.MCPServerStreamableHttp] に `cache_tools_list=True` を指定します。ツール一覧が変更されないと確信できる場合にのみ使用してください。

キャッシュを無効化したい場合は、サーバーで `invalidate_tools_cache()` を呼び出せます。

## エンドツーエンドの code examples

動作する完全な code examples は [examples/mcp](https://github.com/openai/openai-agents-python/tree/main/examples/mcp) を参照してください。

## トレーシング

[トレーシング](./tracing.md) は、次を含む MCP の操作を自動的に取得します。

1. ツール一覧取得のための MCP サーバーへの呼び出し
2. 関数呼び出しに関する MCP 関連情報

![MCP トレーシングのスクリーンショット](../assets/images/mcp-tracing.jpg)