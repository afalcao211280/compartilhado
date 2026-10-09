# httpx + tenacity — HTTP Client Async

Leia `core.md` secao 11 para detalhes.

## Client com Retry

```python
from httpx import AsyncClient, HTTPStatusError
from tenacity import retry, stop_after_attempt, wait_exponential

class ExternalApiClient:
    def __init__(self, base_url: str, timeout: float = 10.0) -> None:
        self._client = AsyncClient(base_url=base_url, timeout=timeout)

    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=10))
    async def get_resource(self, resource_id: str) -> dict:
        response = await self._client.get(f"/resources/{resource_id}")
        response.raise_for_status()
        return response.json()
```

## Regras
- AsyncClient para chamadas async
- tenacity para retry com backoff
- Sempre raise_for_status()
