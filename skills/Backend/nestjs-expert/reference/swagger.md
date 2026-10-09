# Swagger — OpenAPI Documentation

Leia `core.md` secoes Swagger para detalhes.

## Decorators

```typescript
@ApiTags('Users')
@ApiOperation({ summary: 'Criar usuario' })
@ApiCreatedResponse({ type: UserResponseDto })
@Post()
async create(@Body() dto: CreateUserDto): Promise<UserResponseDto> {
  return this.service.create(dto);
}
```

## Regras
- @ApiTags em todo controller
- @ApiOperation em todo endpoint
- @ApiProperty em DTOs de response
- Swagger apenas em non-prod
