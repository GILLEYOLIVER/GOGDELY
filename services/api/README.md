# GOGDELY API — bootstrap

**Estado:** API executável mínima em ambiente local e de testes. O Render de testes expõe `/health` e `/api/v1/info`; ainda não há autenticação, conexão ao banco, pedidos ou pagamentos.

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

## Limites
Não utilizar em produção. O health check não verifica banco ou serviços externos. A migração inicial do esquema Supabase é bloqueada por RLS e não concede acesso à API. Dependências exigem lockfile e revisão antes de produção. A autorização multiempresa no servidor virá em tarefa própria.
