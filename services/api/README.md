# GOGDELY API — bootstrap

**Estado:** API executável mínima em ambiente local e de homologação. O Render
expõe `/health`, `/ready` e `/version.json`; esta branch também verifica
identidade no Supabase Auth. Ainda não há autorização de empresa, pedidos ou
pagamentos em nuvem.

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

## Verificações de publicação

- `/health` verifica somente o processo.
- `/ready` aceita `GOGDELY_DATABASE_URL` ou as variáveis separadas `GOGDELY_DATABASE_HOST`, `GOGDELY_DATABASE_USER`, `GOGDELY_DATABASE_PASSWORD`, `GOGDELY_DATABASE_PORT` (padrão 5432) e `GOGDELY_DATABASE_NAME` (padrão postgres). A senha separada é codificada na URL internamente, inclusive quando contém caracteres especiais. Exige TLS com validação de certificado e oito tabelas `gogdely` com RLS forçado. Responde 503 sem banco ou esquema; não divulga a URL ou exceções de conexão. A CA pública oficial do Supabase está empacotada em `gogdely_api/certs/prod-ca-2021.crt` (SHA-256 `700723581420DD1AC98FD7E9AC529F0EF210EADCAF87FC868A3AD7D114C2F3B7`); a verificação de hostname permanece ativa.
- No host `*.pooler.supabase.com`, a checagem de prontidão remove apenas `VERIFY_X509_STRICT` porque a CA intermediária atualmente servida pelo pooler não contém a extensão Key Usage (erro OpenSSL 92 no Python recente). A confiança na CA, a validação da cadeia e do hostname continuam obrigatórias. Revisar e retirar esta exceção quando o certificado do pooler for corrigido; não a aplicar a outros hosts.
- Em caso de 503, os logs do servidor registram somente a etapa da falha, a classe da exceção ou o SQLSTATE validado. Mensagens de erro do driver, URL e segredos não são registrados.
- `/version.json` mostra somente o SHA fornecido por `RENDER_GIT_COMMIT`, com `Cache-Control: no-store`.

## Limites
Não utilizar em produção. `/ready` verifica apenas a fundação do banco, não autenticação, permissões, Storage ou fluxos de negócio. A migração inicial do esquema Supabase é bloqueada por RLS e não concede acesso à API. A dependência pg8000 (BSD-3-Clause) e sua árvore transitiva exigem revisão de licença e segurança antes de produção. Dependências exigem lockfile e revisão antes de produção. A autorização multiempresa no servidor virá em tarefa própria.
