---
search:
  exclude: true
---
# SQLAlchemy セッション

`SQLAlchemySession` は SQLAlchemy を使用して本番運用可能なセッション実装を提供し、SQLAlchemy がサポートする任意のデータベース (PostgreSQL、MySQL、SQLite など) をセッションストレージとして使用できます。

## インストール

SQLAlchemy セッションには `sqlalchemy` エクストラが必要です:

```bash
pip install openai-agents[sqlalchemy]
```

## クイックスタート

### データベース URL の使用

最も簡単な開始方法:

```python
import asyncio
from agents import Agent, Runner
from agents.extensions.memory import SQLAlchemySession

async def main():
    agent = Agent("Assistant")
    
    # Create session using database URL
    session = SQLAlchemySession.from_url(
        "user-123",
        url="sqlite+aiosqlite:///:memory:",
        create_tables=True
    )
    
    result = await Runner.run(agent, "Hello", session=session)
    print(result.final_output)

if __name__ == "__main__":
    asyncio.run(main())
```

### 既存の SQLAlchemy エンジンの使用

既存の SQLAlchemy エンジンを持つアプリケーション向け:

```python
import asyncio
from agents import Agent, Runner
from agents.extensions.memory import SQLAlchemySession
from sqlalchemy.ext.asyncio import create_async_engine

async def main():
    # Create your database engine
    engine = create_async_engine("postgresql+asyncpg://user:pass@localhost/db")
    
    agent = Agent("Assistant")
    session = SQLAlchemySession(
        "user-456",
        engine=engine,
        create_tables=True
    )
    
    result = await Runner.run(agent, "Hello", session=session)
    print(result.final_output)
    
    # Clean up
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(main())
```


## API リファレンス

- [`SQLAlchemySession`][agents.extensions.memory.sqlalchemy_session.SQLAlchemySession] - メインクラス
- [`Session`][agents.memory.session.Session] - セッションのベースプロトコル