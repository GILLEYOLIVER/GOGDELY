# ADR-0001 — Limites do monorepositório

**Estado:** Proposto para revisão; não é aprovação final de arquitetura.
**Requisitos:** GOG-070, GOG-071, GOG-072, GOG-073, GOG-074, GOG-077, GOG-080, GOG-104.
**Issue:** #4.

## Contexto
Quatro aplicativos Flutter compartilham linguagem e componentes, enquanto operações de marketplace, pagamentos, estoque e autorização exigem um backend central FastAPI. O sistema deve suportar isolamento por empresa e funcionamento offline.

## Decisão proposta
- `apps/cliente`: Flutter Android/iOS, interface do consumidor.
- `apps/gestao`: Flutter Windows/macOS, interface operacional e PDV.
- `apps/entregador`: Flutter Android/iOS, localização e logística.
- `apps/master`: Flutter Android/iOS/Windows/macOS/Web, administração.
- `packages/design_system`: tokens e componentes Flutter compartilhados; não conter regras de negócio nem dados de empresas.
- `packages/shared_models`: DTOs e tipos Dart sem dependência dos aplicativos; contratos devem refletir especificação da API.
- `services/api`: FastAPI; única autoridade para comandos e transações críticas.
- `services/print-agent`: serviço local Windows/macOS, sem acesso direto ao banco central.
- `database/migrations`: migrações SQL versionadas e revisadas.
- `tests`: testes transversais de contratos, isolamento e fluxos críticos.

## Regras de dependência
- Apps podem importar packages compartilhados; packages não importam apps.
- Frontends nunca recebem chave service_role nem acesso administrativo ao banco.
- API valida autenticação, autorização por tenant/filial, entrada e idempotência independentemente do cliente.
- Supabase Realtime sinaliza mudanças; o estado canônico é consultado na API.
- Integrações externas são encapsuladas por adaptadores substituíveis.
- Dados offline são locais e sincronizados por comandos autenticados; conflitos críticos não são resolvidos por último-escritor sem regra explícita.

## Alternativas consideradas
Repositórios separados: mais isolamento organizacional, porém maior custo de versionamento e compartilhamento no estágio inicial. Backend direto via cliente ao banco: rejeitado para comandos críticos por risco de regras divergentes.

## Riscos e condições
Definir contratos OpenAPI, escolha do banco local, estratégia de migrations, escopo do print-agent, matriz de permissões e metas de testes antes de declarar esta ADR aprovada.

## Aceite
Revisão técnica independente, aprovação do proprietário, rastreabilidade com Documento Mestre e ausência de serviços provisionados nesta etapa.
