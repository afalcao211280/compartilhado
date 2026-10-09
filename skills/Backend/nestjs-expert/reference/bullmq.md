# BullMQ — Queues e Workers

Leia `core.md` secoes BullMQ para detalhes.

## Queue

```typescript
@Module({
  imports: [BullModule.registerQueue({ name: 'email' })],
})
export class EmailModule {}
```

## Worker

```typescript
@Processor('email')
export class EmailProcessor {
  @Process('send')
  async handleSend(job: Job<SendEmailData>) {
    // processar
  }
}
```
