# GOGDELY API — bootstrap

**Estado:** API executável mínima em ambiente local e de testes. O Render de testes expõe `/health` e `/api/v1/info`; a branch de preparação acrescenta `/ready` e `/version.json`. Ainda não há autenticação, pedidos ou pagamentos em nuvem.

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

## Testar
```powershell
.\.venv\Scripts\python.exe -m pytest
```

## Verificações de publicação

- `/health` verifica somente o processo.
- `/ready` exige `GOGDELY_DATABASE_URL`, TLS com validação de certificado e oito tabelas `gogdely` com RLS forçado. Responde 503 sem banco ou esquema; não divulga a URL ou exceções de conexão.
- `/version.json` mostra somente o SHA fornecido por `RENDER_GIT_COMMIT`, com `Cache-Control: no-store`.

## Limites
Não utilizar em produção. `/ready` verifica apenas a fundação do banco, não autenticação, permissões, Storage ou fluxos de negócio. A migração inicial do esquema Supabase é bloqueada por RLS e não concede acesso à API. A dependência pg8000 (BSD-3-Clause) e sua árvore transitiva exigem revisão de licença e segurança antes de produção. Dependências exigem lockfile e revisão antes de produção. A autorização multiempresa no servidor virá em tarefa própria.
