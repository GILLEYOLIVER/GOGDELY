# Fundação de testes na nuvem — GOG-072/073/074/077/085/114/115/116

**Rastreio:** issue #33. O ambiente chamado “Homologação” serve para preparar e verificar o GOGDELY online. O nome não significa que os aplicativos tenham sido homologados ou liberados para pedidos reais.

## Recursos

- GitHub: repositório próprio `GILLEYOLIVER/GOGDELY`; a integração de homologação usa `develop`. A branch `feature/gog-072-cloud-foundation` foi a fonte inicial.
- Render: serviço web gratuito `gogdely-api-homologacao`, região Virginia, `GOGDELY_ENV=testes`, build `pip install -e services/api`, start `uvicorn gogdely_api.main:app --host 0.0.0.0 --port ${PORT:-10000}` e health check `/health`. O endereço público continua `https://gogdely-api-testes.onrender.com`. Em 18/10/2026, a fonte foi alterada para `develop` e o auto deploy ativado em **On Commit**. O deploy `dep-dbanoms9v7es73988up0` do SHA `17e4f78db2d5043a7353364912cf493a159816e3` ficou `live`; `/health`, `/ready` e `/version.json` retornaram HTTP 200, sendo que `/version.json` confirmou esse SHA. Isso não aplica a migration `0002` nem valida acesso real entre empresas. Histórico: o deploy inicial `dep-dba2jaeq1p3s73a2sbl0` do commit `b1347b0` ficou `live` em 17/10; então `/ready` retornava 503 por falta do segredo de banco. `/health` só verifica o processo.
- Supabase: projeto gratuito e isolado agora chamado `GOGDELY Homologação`, região São Paulo, ref `vlcssgerbhbvekukpzki`. Em 17/10/2026 (horário de Brasília), `database/migrations/0001_cloud_foundation.sql` foi executada no SQL Editor desse projeto e `database/verification/0001_foundation.sql` retornou `gogdely test foundation: verified`: oito tabelas, RLS forçado, zero políticas e bucket privado `gogdely-menu-testes` (5 MB; JPEG, PNG e WebP). A execução pelo SQL Editor não registra a migração no histórico do Supabase CLI; essa conciliação precisa ser feita antes de automatizar migrações. O projeto separado `GOGDELY` (ref `sbxhrteddwvbzifjrezc`) não foi alterado nesta etapa.

## Banco e acesso

A migração versionada de `database/migrations` e o bucket privado conforme `database/storage/gogdely-menu-testes.json` foram aplicados apenas no projeto de testes. O esquema privado `gogdely` usa chaves compostas com `tenant_id` para relações entre filiais, itens e pedidos. RLS é forçado e não há políticas nem grants para clientes. Isso mantém a estrutura bloqueada até a API validar JWT, papéis e vínculo à empresa e filial. Não colocar senha Postgres, service-role key, JWT secret ou dados reais no GitHub, no cliente Flutter ou em logs.

O segredo `GOGDELY_DATABASE_PASSWORD` foi informado diretamente no Render, sem envio pelo chat. A primeira tentativa de `/ready` após isso retornou 503 durante a verificação TLS, antes da autenticação: OpenSSL código 92, causado por uma extensão ausente na CA intermediária servida pelo pooler Supabase. A API agora preserva verificação da CA e do hostname e desativa apenas a flag estrita para hosts do pooler. O deploy `dep-dba4oiijnfac73ebsue0` do commit `7fdd2ee` ficou `live`, e `/ready` passou da etapa TLS. O deploy seguinte, `dep-dba4pbu1egvs739c262g` do commit `4fdffce`, registrou somente SQLSTATE `28P01`: o PostgreSQL rejeitou a senha então apresentada. Depois de o proprietário corrigir o segredo diretamente no Render, o deploy `dep-dba682ijnfac73ehafcg` do commit `9dd5d3d` ficou `live` em 18/10/2026. `/ready`, `/health` e `/version.json` retornaram HTTP 200, e `/version.json` confirmou o SHA completo `9dd5d3d09720f489e3addc62b1765cc84108087e`. `/ready` confirmou conexão e oito tabelas `gogdely` com RLS forçado; ainda não valida autenticação, políticas, Storage ou pedidos. A configuração aceita host, usuário, porta e nome do banco separados. A integração seguinte deve checar autenticação e testes de isolamento entre duas empresas antes de aceitar comandos de pedido. A chave administrativa não deve ser exposta ao PWA.

## Publicação e limites

O fluxo atual é GitHub → merge da entrega autorizada em `develop` → auto deploy **On Commit** do Render → verificação de SHA, `/health`, `/ready` e fluxos aplicáveis. Revisão independente deixou de ser condição de merge (GOG-107 atualizado). Auto-deploy do Render não aplica migrações no Supabase. Em plano Free não há etapa pre-deploy adequada para DDL; migrations exigem operação separada com backup e compatibilidade confirmados. O serviço gratuito pode adormecer, e o projeto gratuito Supabase pode pausar por inatividade. Nenhum serviço pago foi autorizado.

## Critérios antes de pedidos reais

Autenticação, convite e onboarding da loja; autorização API + RLS, com isolamento verificado entre tenants antes de dados reais; políticas de Storage; transações e idempotência de pedidos; confirmação de pagamento por provedor; observabilidade, backup e restauração; testes em dispositivos antes da operação real. A API bootstrap atual não oferece esses fluxos.

## Reversão

Desligar ou remover apenas o serviço `gogdely-api-homologacao` e o projeto `GOGDELY Homologação` após verificar que não contêm dados a preservar. A branch pode ser revertida sem tocar os serviços de outros produtos. Não reverter infraestrutura de outro projeto.
