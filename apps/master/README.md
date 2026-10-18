# GOGDELY Master

Protótipo Flutter multiplataforma (Android, iOS, Windows, macOS, Web — GOG-010) para a governança da plataforma no laboratório local. Nenhuma autenticação, MFA, tenant ou dado real existe: o login pede um **código MFA simulado** exibido na tela (GOG-082 em simulação) e o painel mostra apenas o SQLite fictício do piloto.

Com `GOGDELY_LOCAL_API=true` e a API local no ar (F5), o app consulta a cada 3 segundos:

- **Visão geral**: empresas aprovadas/pendes, pedidos ativos, volume estimado, pagamentos simulados e comissão estimada sobre produtos sem frete, sempre com avisos de que nada é cobrado (GOG-058 a GOG-063 em simulação).
- **Empresas**: cadastro local com aprovação/recusa **simulada** e motivo obrigatório, registrada na trilha de auditoria (GOG-025).
- **Planos**: catálogo fixo do laboratório (Starter, Growth, Enterprise) com mensalidade, comissão e teste gratuito.
- **Auditoria**: eventos consolidados do SQLite — pedidos, cardápio, pagamentos simulados, estoque, caixa e aprovações (GOG-038/082).

No VS Code, use o perfil **GOGDELY Master • Plataforma (Windows)** ou o composto **GOGDELY • Abrir os 4 aplicativos + API**. Ações críticas são apenas declarativas; produção exige autenticação real, MFA verificado e aprovação do proprietário.
