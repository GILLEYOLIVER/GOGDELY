# GOGDELY Master

Protótipo Flutter multiplataforma (Android, iOS, Windows, macOS, Web — GOG-010) para a governança da plataforma no laboratório local. Nenhuma autenticação, MFA, tenant ou dado real existe: o login pede um **código MFA simulado** exibido na tela (GOG-082 em simulação) e o painel mostra apenas o SQLite fictício do piloto.

Com `GOGDELY_LOCAL_API=true` e a API local no ar (F5), o app consulta a cada 3 segundos:

- **Visão geral**: empresas aprovadas/pendes, pedidos ativos, volume estimado, pagamentos simulados e comissão estimada sobre produtos sem frete, sempre com avisos de que nada é cobrado (GOG-058 a GOG-063 em simulação).
- **Empresas**: cadastro local com aprovação/recusa **simulada** e motivo obrigatório, registrada na trilha de auditoria (GOG-025).
- **Planos**: catálogo fixo do laboratório (Starter, Growth, Enterprise) com mensalidade, comissão e teste gratuito.
- **Auditoria**: eventos consolidados do SQLite — pedidos, cardápio, pagamentos simulados, estoque, caixa e aprovações (GOG-038/082).

No VS Code, use o perfil **GOGDELY Master • Plataforma (Windows)** ou o composto **GOGDELY • Abrir os 4 aplicativos + API**. Ações críticas são apenas declarativas; produção exige autenticação real, MFA verificado e aprovação do proprietário.

## Prévia hospedada (GOG-082/096)

O PWA de homologação usa Supabase Auth, permite apenas o ID autorizado pelo backend e exige MFA real antes de qualquer dado ou comando. A branch `feature/gog-096-master-management` corrige a paleta clara no iPhone e prepara empresas, suspensão/ativação, vínculo de responsável com conta já confirmada, política de comissão e auditoria. A UI consulta a existência da migration `0006` e mantém as ações desabilitadas enquanto ela não for aplicada. A comissão é uma configuração administrativa: **não cobra, divide nem repassa dinheiro**.

Convites a endereços externos exigem SMTP próprio e URL de retorno autorizada no Supabase. O projeto ainda redireciona e-mails de confirmação para `localhost:3000`; isso precisa ser corrigido em Authentication > URL Configuration antes dos primeiros convites. Redefinição de senha de terceiros, aprovações críticas e relatórios financeiros dependem de desenho e integração adicionais. A prévia não deve ser oferecida como operação comercial pronta.
