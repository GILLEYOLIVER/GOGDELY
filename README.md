# GOGDELY

Plataforma marketplace multiempresa e multissetorial (planejamento v1.0).

**Estado:** protótipos locais e prévias web em homologação. O laboratório de pedidos fictícios usa SQLite isolado no computador. A API de homologação usa a fundação PostgreSQL separada no Supabase; a publicação web inclui Cliente, Gestão, Entregador e Master. O Master hospedado oferece entrada protegida e visão de empresas somente para leitura, condicionada à conta autorizada com MFA. Convites, ações administrativas e operação comercial real ainda não estão liberados. Nenhum app está homologado para produção.

## Aplicativos previstos
- Cliente — Android e iOS (Flutter)
- Gestão — Windows e macOS (Flutter)
- Entregador — Android e iOS (Flutter)
- Master — Android, iOS, Windows, macOS e Web (Flutter)

## Arquitetura prevista
FastAPI no Render; Supabase PostgreSQL/Auth/Storage/Realtime; isolamento por tenant_id, RLS e autorização na API; offline avançado sujeito a homologação.

## Governança
- `main`: base estável; `develop`: integração; `feature/*`: alterações isoladas.
- PR rastreável com evidências e reversão; revisão técnica independente é opcional. Entrega autorizada pelo proprietário segue até merge e deploy de homologação após os ajustes e verificações aplicáveis.
- Sem serviços pagos ou produção sem autorização expressa.
- O Documento Mestre GOGDELY v1.0 e seus 141 registros são a referência de planejamento.

Consulte `docs/` e `CONTRIBUTING.md`. Componentes de terceiros são apenas **candidatos** até revisão técnica e de licença.
