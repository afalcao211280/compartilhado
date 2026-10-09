# SQLAlchemy 2.0 — Async Session e Repository

Leia `core.md` secoes 3 e 4 para detalhes.

## Session Async

```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

engine = create_async_engine(str(settings.DATABASE_URL), pool_size=10, max_overflow=20)
session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

## Repository Pattern

```python
class UserRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_by_id(self, user_id: UUID) -> User | None:
        result = await self._db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def create(self, user: User) -> User:
        self._db.add(user)
        await self._db.flush()
        await self._db.refresh(user)
        return user
```

## Anti-padroes
- N+1 queries — usar selectinload para eager loading
- Lazy loading em contexto async — proibido
- Session global — sempre injetar via Depends
