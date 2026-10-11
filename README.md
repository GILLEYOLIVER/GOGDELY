# GOGDELY

Plataforma marketplace multiempresa e multissetorial (planejamento v1.0).

**Estado:** inicialização documental; sem aplicativo executável, sem dependências instaladas, sem serviços pagos e sem deploy.

## Aplicativos previstos
- Cliente — Android e iOS (Flutter)
- Gestão — Windows e macOS (Flutter)
- Entregador — Android e iOS (Flutter)
- Master — Android, iOS, Windows, macOS e Web (Flutter)

## Arquitetura prevista
FastAPI no Render; Supabase PostgreSQL/Auth/Storage/Realtime; isolamento por tenant_id, RLS e autorização na API; offline avançado sujeito a homologação.

## Governança
- `main`: base estável; `develop`: integração; `feature/*`: alterações isoladas.
- PR com revisão técnica e aprovação do proprietário; agentes de IA não podem contornar verificações.
- Sem serviços pagos ou produção sem autorização expressa.
- O Documento Mestre GOGDELY v1.0 e seus 141 registros são a referência de planejamento.

Consulte `docs/` e `CONTRIBUTING.md`. Componentes de terceiros são apenas **candidatos** até revisão técnica e de licença.
