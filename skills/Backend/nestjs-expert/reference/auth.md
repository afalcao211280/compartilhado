# JWT Auth — Guards, Strategies, Decorators

Leia `core.md` secao JWT para detalhes.

## Guard

```typescript
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
```

## Strategy

```typescript
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.get<string>('JWT_SECRET'),
    });
  }
}
```

## Regras
- @UseGuards(JwtAuthGuard) nas rotas protegidas
- CurrentUser decorator para acesso ao usuario
- JWT com expiracao curta
