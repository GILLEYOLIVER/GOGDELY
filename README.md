# GOGDELY

Plataforma marketplace multiempresa e multissetorial (planejamento v1.0).

**Estado:** protótipos locais de Cliente, Gestão e Entregador executáveis no Windows. Um fluxo opt-in de pedidos fictícios usa a API FastAPI e SQLite isolado no computador para testar gravação e leitura entre os três aplicativos. Nenhum app está homologado. Há uma API bootstrap gratuita de testes no Render, ainda sem conexão com o piloto SQLite ou o Supabase; não houve serviço pago nem deploy de produção.

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
