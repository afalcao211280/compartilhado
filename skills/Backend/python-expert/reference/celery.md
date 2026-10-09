# Celery — Workers e Tasks

Leia `core.md` secao 12 para detalhes.

## Setup

```python
from celery import Celery

celery_app = Celery("eveo-worker", broker=str(settings.REDIS_URL), backend=str(settings.REDIS_URL))
celery_app.conf.update(task_serializer="json", timezone="America/Sao_Paulo")
```

## Task

```python
@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_welcome_email(self, user_id: str, email: str) -> None:
    try:
        # logica
        pass
    except Exception as exc:
        raise self.retry(exc=exc)
```
