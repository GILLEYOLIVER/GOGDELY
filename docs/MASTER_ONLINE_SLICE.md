# GOGDELY Master hospedado — primeiro recorte de homologação

Requisitos relacionados: GOG-010, GOG-082 e GOG-096. Este recorte publica o app Master em `/master/` no host dos PWAs de homologação. O laboratório local continua separado.

## O que funciona

- Login por e-mail e senha do Supabase Auth configurado para este projeto.
- Restrição na API por `GOGDELY_MASTER_USER_IDS`, uma lista de UUIDs de usuários Auth; não se concede acesso por endereço de e-mail informado pelo navegador.
- Cadastro e confirmação de TOTP no app. As leituras de dados exigem token verificado pelo Supabase Auth com nível `aal2` e `sub` igual ao usuário autorizado.
- Visão geral com contagens reais da fundação PostgreSQL da homologação e lista de empresas. A lista é limitada a 200 registros e somente leitura.
- Manifesto, escopo e ícone próprios para instalar o Master como PWA.

Sem usuário Auth autorizado, a API recusa o acesso. Isso é intencional. A criação do primeiro usuário e a definição de seu UUID na variável do Render precisam de um fluxo de provisionamento administrativo; nenhum usuário ou senha foi inventado por esta entrega.

## Ainda pendente

Convites por e-mail, cadastro de lojas, suspensão/ativação, redefinição de senha, comissões, aprovações e trilha de auditoria não estão implementados neste recorte. O banco de homologação contém somente a fundação de oito tabelas. Os demais fluxos dependem de migrations versionadas, backup recuperável e confirmação do esquema de destino. A interface não apresenta ações fictícias para essas funções.

O projeto não está pronto para receber pedidos ou pagamentos reais. A rota do Master está em **homologação** e não constitui liberação de produção.

## Configuração e segurança

1. Manter `GOGDELY_SUPABASE_URL` e `GOGDELY_SUPABASE_PUBLISHABLE_KEY` na API; somente a chave pública é enviada ao app.
2. Criar uma conta Auth do proprietário pelo processo administrativo seguro, sem compartilhar a senha em mensagens ou no repositório.
3. Definir `GOGDELY_MASTER_USER_IDS` no Render com o UUID dessa conta, nunca o e-mail. Se ausente ou inválida, a API responde 503.
4. No primeiro acesso, entrar e configurar o aplicativo autenticador. O segredo TOTP aparece apenas durante a configuração. As rotas de dados exigem MFA válido em cada chamada.
5. Definir `GOGDELY_API_BASE_URL` no build do site estático para o HTTPS da API de homologação. A API deve permitir a origem do site no CORS.

As consultas da API são SQL fixo sem entrada do usuário. Nenhuma chave administrativa do Supabase é distribuída no PWA. Os dados são consultados somente após verificação de identidade e MFA no backend.

## Verificação e reversão

Verificações do recorte: análise e build web do Flutter Master; testes de API para identidade ausente, allowlist vazia/inválida, usuário não autorizado, MFA ausente/incorreto e leitura autorizada. Conferir após deploy `GET /master/`, manifesto, ícone e `version.json` com o commit publicado; `GET /api/v1/master/eligibility` sem token deve retornar 401. Para reverter, restaurar os serviços Render ao último commit estável e remover `GOGDELY_MASTER_USER_IDS` para bloquear imediatamente as rotas de dados. Nenhuma migration de banco é executada nesta entrega.
