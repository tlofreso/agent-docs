---
search:
  exclude: true
---
# 暗号化セッション

`EncryptedSession` は、あらゆるセッション実装に対して透過的な暗号化を提供し、会話データを保護するとともに古い項目を自動的に期限切れにします。

## 特長

-  **透過的な暗号化** : どんなセッションでも Fernet 暗号化でラップします
-  **セッション単位の鍵** : HKDF による鍵導出でセッションごとに一意の暗号鍵を使用します
-  **自動期限切れ** : TTL を超えた古い項目は静かにスキップされます
-  **ドロップイン置き換え** : 既存のどのセッション実装でも動作します

## インストール

暗号化セッションには `encrypt` エクストラが必要です:

```bash
pip install openai-agents[encrypt]
```

## クイックスタート

```python
import asyncio
from agents import Agent, Runner
from agents.extensions.memory import EncryptedSession, SQLAlchemySession

async def main():
    agent = Agent("Assistant")
    
    # Create underlying session
    underlying_session = SQLAlchemySession.from_url(
        "user-123",
        url="sqlite+aiosqlite:///:memory:",
        create_tables=True
    )
    
    # Wrap with encryption
    session = EncryptedSession(
        session_id="user-123",
        underlying_session=underlying_session,
        encryption_key="your-secret-key-here",
        ttl=600  # 10 minutes
    )
    
    result = await Runner.run(agent, "Hello", session=session)
    print(result.final_output)

if __name__ == "__main__":
    asyncio.run(main())
```

## 設定

### 暗号鍵

暗号鍵は Fernet キーまたは任意の文字列を使用できます:

```python
from agents.extensions.memory import EncryptedSession

# Using a Fernet key (base64-encoded)
session = EncryptedSession(
    session_id="user-123",
    underlying_session=underlying_session,
    encryption_key="your-fernet-key-here",
    ttl=600
)

# Using a raw string (will be derived to a key)
session = EncryptedSession(
    session_id="user-123", 
    underlying_session=underlying_session,
    encryption_key="my-secret-password",
    ttl=600
)
```

### TTL (Time To Live)

暗号化アイテムの有効期間を設定します:

```python
# Items expire after 1 hour
session = EncryptedSession(
    session_id="user-123",
    underlying_session=underlying_session,
    encryption_key="secret",
    ttl=3600  # 1 hour in seconds
)

# Items expire after 1 day
session = EncryptedSession(
    session_id="user-123",
    underlying_session=underlying_session,
    encryption_key="secret", 
    ttl=86400  # 24 hours in seconds
)
```

## 各種セッションタイプでの使用

### SQLite セッションでの使用

```python
from agents import SQLiteSession
from agents.extensions.memory import EncryptedSession

# Create encrypted SQLite session
underlying = SQLiteSession("user-123", "conversations.db")

session = EncryptedSession(
    session_id="user-123",
    underlying_session=underlying,
    encryption_key="secret-key"
)
```

### SQLAlchemy セッションでの使用

```python
from agents.extensions.memory import EncryptedSession, SQLAlchemySession

# Create encrypted SQLAlchemy session
underlying = SQLAlchemySession.from_url(
    "user-123",
    url="postgresql+asyncpg://user:pass@localhost/db",
    create_tables=True
)

session = EncryptedSession(
    session_id="user-123",
    underlying_session=underlying,
    encryption_key="secret-key"
)
```

!!! warning "高度なセッション機能"

    `EncryptedSession` を `AdvancedSQLiteSession` のような高度なセッション実装と併用する場合は、次の点に注意してください。

    - メッセージ内容が暗号化されるため、`find_turns_by_content()` のようなメソッドは有効に機能しません
    - コンテンツベースの検索は暗号化データ上で行われるため、有効性が制限されます



## 鍵導出

EncryptedSession は HKDF (HMAC-based Key Derivation Function) を使用して、セッションごとに一意の暗号鍵を導出します。

-  **マスター鍵** : 提供した暗号鍵
-  **セッションソルト** : セッション ID
-  **Info 文字列** : `"agents.session-store.hkdf.v1"`
-  **出力** : 32 バイトの Fernet キー

これにより、次が保証されます:
- 各セッションは一意の暗号鍵を持ちます
- マスター鍵なしでは鍵を導出できません
- セッション間でデータを復号できません

## 自動期限切れ

アイテムが TTL を超えると、取得時に自動的にスキップされます:

```python
# Items older than TTL are silently ignored
items = await session.get_items()  # Only returns non-expired items

# Expired items don't affect session behavior
result = await Runner.run(agent, "Continue conversation", session=session)
```

## API リファレンス

- [`EncryptedSession`][agents.extensions.memory.encrypt_session.EncryptedSession] - メインクラス
- [`Session`][agents.memory.session.Session] - ベースセッションプロトコル