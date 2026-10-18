# Fundação de testes na nuvem — GOG-072/073/074/077/085/114/115/116

**Rastreio:** issue #33. Este ambiente serve para preparar o GOGDELY online. Não é homologação nem liberação para pedidos reais.

## Recursos

- GitHub: repositório próprio `GILLEYOLIVER/GOGDELY`; alterações desta etapa ficam em `feature/gog-072-cloud-foundation` até revisão e aprovação.
- Render: serviço web gratuito `gogdely-api-testes`, conectado ao GitHub na branch `feature/gog-072-cloud-foundation`, região Virginia, `GOGDELY_ENV=testes`, build `pip install -e services/api`, start `uvicorn gogdely_api.main:app --host 0.0.0.0 --port ${PORT:-10000}` e health check `/health`. O deploy automático segue desligado. O deploy `dep-dba2jaeq1p3s73a2sbl0` do commit `b1347b0` chegou a `live` em 17/10/2026 (Brasília): `/health` e `/version.json` retornaram HTTP 200 e o SHA correto; `/ready` retornou HTTP 503 pela ausência deliberada do segredo de banco. `/health` só verifica o processo, não o banco. O CI desse commit passou e os testes locais da API tiveram 13 aprovações.
- Supabase: projeto gratuito e isolado `GOGDELY Testes`, região São Paulo, ref `vlcssgerbhbvekukpzki`. Em 17/10/2026 (horário de Brasília), `database/migrations/0001_cloud_foundation.sql` foi executada no SQL Editor desse projeto e `database/verification/0001_foundation.sql` retornou `gogdely test foundation: verified`: oito tabelas, RLS forçado, zero políticas e bucket privado `gogdely-menu-testes` (5 MB; JPEG, PNG e WebP). A execução pelo SQL Editor não registra a migração no histórico do Supabase CLI; essa conciliação precisa ser feita antes de automatizar migrações. O projeto separado `GOGDELY` (ref `sbxhrteddwvbzifjrezc`) não foi alterado nesta etapa.

## Banco e acesso

A migração versionada de `database/migrations` e o bucket privado conforme `database/storage/gogdely-menu-testes.json` foram aplicados apenas no projeto de testes. O esquema privado `gogdely` usa chaves compostas com `tenant_id` para relações entre filiais, itens e pedidos. RLS é forçado e não há políticas nem grants para clientes. Isso mantém a estrutura bloqueada até a API validar JWT, papéis e vínculo à empresa e filial. Não colocar senha Postgres, service-role key, JWT secret ou dados reais no GitHub, no cliente Flutter ou em logs.

O Render ainda não tem conexão com o Supabase. `/ready` verifica a conectividade com as oito tabelas, mas ainda não há segredo configurado nem verificação positiva ao vivo. A configuração aceita host, usuário, porta e nome do banco separados, para que a senha seja informada diretamente como `GOGDELY_DATABASE_PASSWORD` no Render, sem envio pelo chat nem montagem manual de URL. A integração seguinte deve checar autenticação e testes de isolamento entre duas empresas antes de aceitar comandos de pedido. A chave administrativa não deve ser exposta ao PWA.

## Publicação e limites

O fluxo planejado é GitHub → revisão/merge aprovado em `develop` → migração testada e registrada → deploy do Render → verificação de SHA, `/health`, `/ready` e fluxos. Auto-deploy do Render não aplica migrações no Supabase. Em plano Free não há etapa pre-deploy adequada para DDL; a migração precisará de um job protegido e revisado. O serviço gratuito pode adormecer, e o projeto gratuito Supabase pode pausar por inatividade. Nenhum serviço pago foi autorizado.

## Critérios antes de pedidos reais

Autenticação, convite e onboarding da loja; autorização API + RLS com testes entre tenants; políticas de Storage; transações e idempotência de pedidos; confirmação de pagamento por provedor; observabilidade, backup e restauração; revisão independente e aprovação do proprietário; testes em dispositivos. A API bootstrap atual não oferece esses fluxos.

## Reversão

Desligar ou remover apenas o serviço `gogdely-api-testes` e o projeto `GOGDELY Testes` após verificar que não contêm dados a preservar. A branch pode ser revertida sem tocar os serviços de outros produtos. Não reverter infraestrutura de outro projeto.
