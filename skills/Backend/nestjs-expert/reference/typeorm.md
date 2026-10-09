# TypeORM — Entities, Repositories, Migrations

Leia `core.md` secoes TypeORM para detalhes.

## Entity

```typescript
@Entity()
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column()
  name: string;
}
```

## Repository

```typescript
@Injectable()
export class UserRepository {
  constructor(@InjectRepository(User) private readonly ormRepo: Repository<User>) {}

  async findById(id: string): Promise<User | null> {
    return this.ormRepo.findOne({ where: { id } });
  }
}
```

## Regras
- Repository encapsula acesso a dados
- Nunca expor Entity na response
- Migrations via TypeORM CLI
