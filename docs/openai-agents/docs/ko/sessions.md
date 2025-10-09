---
search:
  exclude: true
---
# 세션

Agents SDK 는 여러 에이전트 실행(run) 간에 대화 기록을 자동으로 유지하는 내장 세션 메모리를 제공하여, 턴 사이에 `.to_input_list()` 를 수동으로 처리할 필요를 없애줍니다.

세션은 특정 세션에 대한 대화 기록을 저장하여, 명시적인 수동 메모리 관리 없이도 에이전트가 컨텍스트를 유지할 수 있도록 합니다. 특히 에이전트가 이전 상호작용을 기억하길 원하는 채팅 애플리케이션이나 멀티턴 대화에 유용합니다.

## 빠른 시작

```python
from agents import Agent, Runner, SQLiteSession

# Create agent
agent = Agent(
    name="Assistant",
    instructions="Reply very concisely.",
)

# Create a session instance with a session ID
session = SQLiteSession("conversation_123")

# First turn
result = await Runner.run(
    agent,
    "What city is the Golden Gate Bridge in?",
    session=session
)
print(result.final_output)  # "San Francisco"

# Second turn - agent automatically remembers previous context
result = await Runner.run(
    agent,
    "What state is it in?",
    session=session
)
print(result.final_output)  # "California"

# Also works with synchronous runner
result = Runner.run_sync(
    agent,
    "What's the population?",
    session=session
)
print(result.final_output)  # "Approximately 39 million"
```

## 동작 방식

세션 메모리가 활성화되면:

1. **각 실행 전**: 러너가 세션의 대화 기록을 자동으로 가져와 입력 항목 앞에 추가합니다
2. **각 실행 후**: 실행 중에 생성된 모든 새 항목(사용자 입력, 어시스턴트 응답, 도구 호출 등)이 세션에 자동으로 저장됩니다
3. **컨텍스트 유지**: 동일한 세션으로 후속 실행을 수행할 때 전체 대화 기록이 포함되어 에이전트가 컨텍스트를 유지합니다

이는 `.to_input_list()` 를 수동으로 호출하고 실행 간 대화 상태를 관리해야 하는 필요를 제거합니다.

## 메모리 작업

### 기본 작업

세션은 대화 기록 관리를 위한 여러 작업을 지원합니다:

```python
from agents import SQLiteSession

session = SQLiteSession("user_123", "conversations.db")

# Get all items in a session
items = await session.get_items()

# Add new items to a session
new_items = [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi there!"}
]
await session.add_items(new_items)

# Remove and return the most recent item
last_item = await session.pop_item()
print(last_item)  # {"role": "assistant", "content": "Hi there!"}

# Clear all items from a session
await session.clear_session()
```

### 수정 시 pop_item 사용

`pop_item` 메서드는 대화에서 마지막 항목을 되돌리거나 수정하려는 경우에 특히 유용합니다:

```python
from agents import Agent, Runner, SQLiteSession

agent = Agent(name="Assistant")
session = SQLiteSession("correction_example")

# Initial conversation
result = await Runner.run(
    agent,
    "What's 2 + 2?",
    session=session
)
print(f"Agent: {result.final_output}")

# User wants to correct their question
assistant_item = await session.pop_item()  # Remove agent's response
user_item = await session.pop_item()  # Remove user's question

# Ask a corrected question
result = await Runner.run(
    agent,
    "What's 2 + 3?",
    session=session
)
print(f"Agent: {result.final_output}")
```

## 메모리 옵션

### 메모리 없음(기본값)

```python
# Default behavior - no session memory
result = await Runner.run(agent, "Hello")
```

### OpenAI Conversations API 메모리

[OpenAI Conversations API](https://platform.openai.com/docs/api-reference/conversations/create)를 사용하여 자체 데이터베이스를 관리하지 않고도
[conversation state](https://platform.openai.com/docs/guides/conversation-state?api-mode=responses#using-the-conversations-api)를 지속할 수 있습니다. 이는 대화 기록 저장에 OpenAI 호스트하는 인프라에 이미 의존하고 있을 때 유용합니다.

```python
from agents import OpenAIConversationsSession

session = OpenAIConversationsSession()

# Optionally resume a previous conversation by passing a conversation ID
# session = OpenAIConversationsSession(conversation_id="conv_123")

result = await Runner.run(
    agent,
    "Hello",
    session=session,
)
```

### SQLite 메모리

```python
from agents import SQLiteSession

# In-memory database (lost when process ends)
session = SQLiteSession("user_123")

# Persistent file-based database
session = SQLiteSession("user_123", "conversations.db")

# Use the session
result = await Runner.run(
    agent,
    "Hello",
    session=session
)
```

### 다중 세션

```python
from agents import Agent, Runner, SQLiteSession

agent = Agent(name="Assistant")

# Different sessions maintain separate conversation histories
session_1 = SQLiteSession("user_123", "conversations.db")
session_2 = SQLiteSession("user_456", "conversations.db")

result1 = await Runner.run(
    agent,
    "Hello",
    session=session_1
)
result2 = await Runner.run(
    agent,
    "Hello",
    session=session_2
)
```

### SQLAlchemy 기반 세션

더 고급 사용 사례의 경우, SQLAlchemy 기반 세션 백엔드를 사용할 수 있습니다. 이를 통해 SQLAlchemy 가 지원하는 모든 데이터베이스(PostgreSQL, MySQL, SQLite 등)를 세션 저장소로 사용할 수 있습니다.

**예시 1: 인메모리 SQLite 와 `from_url` 사용**

개발 및 테스트에 적합한 가장 간단한 시작 방법입니다.

```python
import asyncio
from agents import Agent, Runner
from agents.extensions.memory.sqlalchemy_session import SQLAlchemySession

async def main():
    agent = Agent("Assistant")
    session = SQLAlchemySession.from_url(
        "user-123",
        url="sqlite+aiosqlite:///:memory:",
        create_tables=True,  # Auto-create tables for the demo
    )

    result = await Runner.run(agent, "Hello", session=session)

if __name__ == "__main__":
    asyncio.run(main())
```

**예시 2: 기존 SQLAlchemy 엔진 사용**

프로덕션 애플리케이션에서는 SQLAlchemy `AsyncEngine` 인스턴스를 이미 보유하고 있을 가능성이 큽니다. 이를 세션에 직접 전달할 수 있습니다.

```python
import asyncio
from agents import Agent, Runner
from agents.extensions.memory.sqlalchemy_session import SQLAlchemySession
from sqlalchemy.ext.asyncio import create_async_engine

async def main():
    # In your application, you would use your existing engine
    engine = create_async_engine("sqlite+aiosqlite:///conversations.db")

    agent = Agent("Assistant")
    session = SQLAlchemySession(
        "user-456",
        engine=engine,
        create_tables=True,  # Auto-create tables for the demo
    )

    result = await Runner.run(agent, "Hello", session=session)
    print(result.final_output)

    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(main())
```

### 암호화된 세션

보관 중인 대화 데이터의 암호화가 필요한 애플리케이션의 경우, `EncryptedSession` 을 사용하여 투명한 암호화와 자동 TTL 기반 만료로 어떤 세션 백엔드든 감쌀 수 있습니다. 이를 위해서는 `encrypt` extra 가 필요합니다: `pip install openai-agents[encrypt]`.

`EncryptedSession` 은 세션별 키 파생(HKDF)이 적용된 Fernet 암호화를 사용하며, 오래된 메시지의 자동 만료를 지원합니다. 항목이 TTL을 초과하면 조회 시 조용히 건너뜁니다.

**예시: SQLAlchemy 세션 데이터 암호화**

```python
import asyncio
from agents import Agent, Runner
from agents.extensions.memory import EncryptedSession, SQLAlchemySession

async def main():
    # Create underlying session (works with any SessionABC implementation)
    underlying_session = SQLAlchemySession.from_url(
        session_id="user-123",
        url="postgresql+asyncpg://app:secret@db.example.com/agents",
        create_tables=True,
    )

    # Wrap with encryption and TTL-based expiration
    session = EncryptedSession(
        session_id="user-123",
        underlying_session=underlying_session,
        encryption_key="your-encryption-key",  # Use a secure key from your secrets management
        ttl=600,  # 10 minutes - items older than this are silently skipped
    )

    agent = Agent("Assistant")
    result = await Runner.run(agent, "Hello", session=session)
    print(result.final_output)

if __name__ == "__main__":
    asyncio.run(main())
```

**주요 기능:**

-   **투명한 암호화**: 저장 전 모든 세션 항목을 자동으로 암호화하고 조회 시 복호화
-   **세션별 키 파생**: 세션 ID 를 salt 로 사용하는 HKDF 로 고유한 암호화 키 파생
-   **TTL 기반 만료**: 구성 가능한 time-to-live(기본값: 10분)에 따라 오래된 메시지를 자동 만료
-   **유연한 키 입력**: Fernet 키 또는 원문 문자열을 암호화 키로 허용
-   **어떤 세션이든 래핑**: SQLite, SQLAlchemy, 또는 사용자 정의 세션 구현과 동작

!!! warning "중요한 보안 참고 사항"

    -   암호화 키는 안전하게 저장하세요(예: 환경 변수, 시크릿 매니저)
    -   만료된 토큰은 애플리케이션 서버의 시스템 시계를 기준으로 거부됩니다 - 유효한 토큰이 시계 드리프트로 인해 거부되지 않도록 모든 서버가 NTP 로 시간 동기화되어 있는지 확인하세요
    -   기본 세션은 여전히 암호화된 데이터를 저장하므로 데이터베이스 인프라에 대한 제어권을 유지합니다


## 사용자 정의 메모리 구현

[`Session`][agents.memory.session.Session] 프로토콜을 따르는 클래스를 만들어 자체 세션 메모리를 구현할 수 있습니다:

```python
from agents.memory.session import SessionABC
from agents.items import TResponseInputItem
from typing import List

class MyCustomSession(SessionABC):
    """Custom session implementation following the Session protocol."""

    def __init__(self, session_id: str):
        self.session_id = session_id
        # Your initialization here

    async def get_items(self, limit: int | None = None) -> List[TResponseInputItem]:
        """Retrieve conversation history for this session."""
        # Your implementation here
        pass

    async def add_items(self, items: List[TResponseInputItem]) -> None:
        """Store new items for this session."""
        # Your implementation here
        pass

    async def pop_item(self) -> TResponseInputItem | None:
        """Remove and return the most recent item from this session."""
        # Your implementation here
        pass

    async def clear_session(self) -> None:
        """Clear all items for this session."""
        # Your implementation here
        pass

# Use your custom session
agent = Agent(name="Assistant")
result = await Runner.run(
    agent,
    "Hello",
    session=MyCustomSession("my_session")
)
```

## 세션 관리

### 세션 ID 네이밍

대화를 체계적으로 정리할 수 있도록 의미 있는 세션 ID 를 사용하세요:

-   사용자 기반: `"user_12345"`
-   스레드 기반: `"thread_abc123"`
-   컨텍스트 기반: `"support_ticket_456"`

### 메모리 지속성

-   일시적 대화에는 인메모리 SQLite(`SQLiteSession("session_id")`) 사용
-   지속적 대화에는 파일 기반 SQLite(`SQLiteSession("session_id", "path/to/db.sqlite")`) 사용
-   SQLAlchemy 가 지원하는 기존 데이터베이스가 있는 프로덕션 시스템에는 SQLAlchemy 기반 세션(`SQLAlchemySession("session_id", engine=engine, create_tables=True")`) 사용
-   기록을 OpenAI Conversations API 에 저장하길 원할 때는 OpenAI 호스트하는 스토리지(`OpenAIConversationsSession()`) 사용
-   투명한 암호화와 TTL 기반 만료로 어떤 세션이든 감싸려면 암호화된 세션(`EncryptedSession(session_id, underlying_session, encryption_key")`) 사용
-   더 고급 사용 사례를 위해 다른 프로덕션 시스템(Redis, Django 등)에 대한 사용자 정의 세션 백엔드 구현을 고려

### 세션 관리

```python
# Clear a session when conversation should start fresh
await session.clear_session()

# Different agents can share the same session
support_agent = Agent(name="Support")
billing_agent = Agent(name="Billing")
session = SQLiteSession("user_123")

# Both agents will see the same conversation history
result1 = await Runner.run(
    support_agent,
    "Help me with my account",
    session=session
)
result2 = await Runner.run(
    billing_agent,
    "What are my charges?",
    session=session
)
```

## 전체 예시

다음은 세션 메모리가 실제로 동작하는 전체 예시입니다:

```python
import asyncio
from agents import Agent, Runner, SQLiteSession


async def main():
    # Create an agent
    agent = Agent(
        name="Assistant",
        instructions="Reply very concisely.",
    )

    # Create a session instance that will persist across runs
    session = SQLiteSession("conversation_123", "conversation_history.db")

    print("=== Sessions Example ===")
    print("The agent will remember previous messages automatically.\n")

    # First turn
    print("First turn:")
    print("User: What city is the Golden Gate Bridge in?")
    result = await Runner.run(
        agent,
        "What city is the Golden Gate Bridge in?",
        session=session
    )
    print(f"Assistant: {result.final_output}")
    print()

    # Second turn - the agent will remember the previous conversation
    print("Second turn:")
    print("User: What state is it in?")
    result = await Runner.run(
        agent,
        "What state is it in?",
        session=session
    )
    print(f"Assistant: {result.final_output}")
    print()

    # Third turn - continuing the conversation
    print("Third turn:")
    print("User: What's the population of that state?")
    result = await Runner.run(
        agent,
        "What's the population of that state?",
        session=session
    )
    print(f"Assistant: {result.final_output}")
    print()

    print("=== Conversation Complete ===")
    print("Notice how the agent remembered the context from previous turns!")
    print("Sessions automatically handles conversation history.")


if __name__ == "__main__":
    asyncio.run(main())
```

## API 레퍼런스

자세한 API 문서는 다음을 참조하세요:

-   [`Session`][agents.memory.Session] - 프로토콜 인터페이스
-   [`SQLiteSession`][agents.memory.SQLiteSession] - SQLite 구현
-   [`OpenAIConversationsSession`](ref/memory/openai_conversations_session.md) - OpenAI Conversations API 구현
-   [`SQLAlchemySession`][agents.extensions.memory.sqlalchemy_session.SQLAlchemySession] - SQLAlchemy 기반 구현
-   [`EncryptedSession`][agents.extensions.memory.encrypt_session.EncryptedSession] - TTL 이 포함된 암호화된 세션 래퍼