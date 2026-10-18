# GOGDELY API — bootstrap local

**Estado:** API executável mínima; esta branch acrescenta somente verificação
de identidade (GOG-075). Não há autorização de empresa, banco, pedidos,
pagamentos ou deploy nesta branch.

## Requisitos
Python 3.11+ no Windows.

## Executar localmente
No PowerShell, a partir da pasta `services/api`:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[test]"
.\.venv\Scripts\python.exe -m uvicorn gogdely_api.main:app --reload --host 127.0.0.1 --port 8000
```

Abrir `http://127.0.0.1:8000/docs` ou `http://127.0.0.1:8000/health`.

## Identidade Supabase (GOG-075, issue #37)

Configure `GOGDELY_SUPABASE_URL` com o endereço HTTPS do projeto
`*.supabase.co` e `GOGDELY_SUPABASE_PUBLISHABLE_KEY` **somente no servidor**.
`GET /api/v1/auth/me` exige `Authorization: Bearer <access_token>`, consulta
diretamente `/auth/v1/user` no Supabase Auth e devolve apenas o UUID confirmado.
O token não é decodificado localmente. Sem configuração, com token inválido ou
com Auth indisponível, o endpoint falha fechado. Não usa chave administrativa.

Esta etapa não autoriza acesso a loja, filial, pedido ou dados privados. A
próxima etapa precisa consultar vínculos confiáveis no banco e testar RLS entre
empresas antes de habilitar endpoints de negócio. Consulte
[`docs/AUTH_IDENTITY.md`](../../docs/AUTH_IDENTITY.md).

## Testar
```powershell
.\.venv\Scripts\python.exe -m pytest
```

## Limites
Não utilizar em produção. O health check não verifica banco ou serviços externos. Dependências exigem lockfile e revisão antes de produção. Multiempresa virá em tarefa própria com RLS e autorização no servidor.
