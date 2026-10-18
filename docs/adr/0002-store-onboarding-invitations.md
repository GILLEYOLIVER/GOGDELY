# ADR-0002 — Convites e ativação de lojas

**Estado:** proposta técnica, sem autorização de migração ou envio de e-mail.
**Issue:** #40. **Requisitos:** GOG-025, GOG-037, GOG-074, GOG-075,
GOG-082, GOG-083, GOG-114.

## Contexto

O proprietário deseja cadastrar uma loja, convidar o responsável por e-mail,
permitir que ele crie a senha no primeiro acesso e conclua a configuração no
painel Gestão. O acesso deve ficar restrito à empresa e à filial convidadas.
O projeto de homologação já possui Supabase Auth e o esquema inicial, mas a
autorização de vínculos da issue #39 ainda não foi homologada. O Master atual
tem apenas MFA **simulado** no laboratório SQLite.

## Decisão proposta

1. Somente um operador Master reconhecido por uma tabela privada de operadores
   da plataforma pode criar, reenviar ou revogar convites. A API confirma a
   identidade no Supabase Auth e exige sessão `aal2` para cada comando crítico.
   O JWT fornecido pelo cliente só pode contribuir com o nível de autenticação
   depois de validado contra o Auth, com `sub` igual ao UUID confirmado; cargo
   Master nunca vem de metadados editáveis pelo próprio usuário.
2. A API cria empresa/filial em estado `draft`, dentro de transação, e registra
   um convite para e-mail normalizado, empresa, filial e papel inicial. A
   operação recebe chave de idempotência e grava evento de auditoria com o
   operador, motivo, data e estado anterior/novo. Nenhuma chave administrativa
   é enviada ao Flutter.
3. O acesso ao convite usa a função administrativa de convite do Supabase
   Auth, chamada **somente pelo servidor**. O link de Auth prova o controle do
   e-mail; a posse desse link sozinha **não** cria membership. A API exige
   usuário autenticado com o mesmo e-mail verificado e convite ainda válido,
   pendente e não revogado antes de conceder o vínculo.
4. A aceitação altera o convite de `pending` para `accepted` e cria o
   membership no mesmo commit. Um bloqueio/condição no banco permite apenas
   uma aceitação; repetição com a mesma identidade é idempotente, e outra
   identidade é negada. Expiração e revogação bloqueiam membership mesmo que
   um link de Auth ainda abra uma sessão.
5. A Gestão só libera nome público, endereço, horários e área de entrega
   depois que a API autorizar o vínculo da filial. Toda escrita passa pela API
   com autorização por tenant/filial, validação e trilha de auditoria.
6. O e-mail de convite é enviado após persistir o registro, por uma fila
   idempotente/outbox. Falha de entrega deixa estado rastreável para reenvio;
   não cria membership e não duplica lojas. A chave de idempotência do reenvio
   evita dois envios para a mesma solicitação.

## Modelo mínimo proposto

- `platform_operators`: UUID de Auth, permissões explícitas, ativo/revogado,
  concessor e auditoria. Não é uma tabela de tenant. Sem acesso direto dos
  aplicativos, mesmo autenticados.
- `store_invitations`: UUID, `tenant_id`, `branch_id`, e-mail normalizado,
  papel permitido, estado (`pending`, `accepted`, `revoked`, `expired`),
  validade, criador, aceita por, datas e chave de idempotência. Restrições
  impedem filial de outra empresa e convites pendentes duplicados.
- `invitation_outbox`: evento de envio com ID estável, tentativas, último
  resultado seguro e data de próxima tentativa. Não guarda token em texto
  aberto nem HTML de mensagem. A retenção de e-mail/auditoria deve seguir a
  política de privacidade aprovada.
- `access_audit`: criação, reenvio, revogação, aceitação e mudança de papel;
  append-only para a API, com autor e correlação. Não gravar token, senha,
  cookie, chave de API ou URL completa de convite nos logs.

Todos os objetos novos exigem migration versionada, RLS forçado onde houver
acesso por usuário e testes negativos de leitura/escrita como `anon` e
`authenticated`. A API usa credencial administrativa somente nas operações
estritamente necessárias de Auth; acesso comum ao banco continua sujeito a
RLS e verificação própria da API. Um desenho de permissões detalhado e o DDL
devem ser revisados antes de aplicar qualquer migration.

## Sequência de implementação

1. Concluir #39: backup, revisão independente, policies em homologação e
   testes de duas empresas/filiais com Auth real.
2. Revisar esta ADR e a matriz Master/loja; implementar MFA real e operador
   Master privado. Nunca reaproveitar o MFA exibido na tela do laboratório.
3. Versionar migrations, API transacional, outbox, auditoria e testes locais
   de expiração, revogação, reutilização, e-mail diferente, corrida de aceite,
   acesso cruzado e reenvio idempotente.
4. Configurar em homologação o template de convite, URLs de retorno exatas e
   transporte de e-mail revisado. Testar com contas descartáveis autorizadas,
   sem endereços de lojas reais.
5. Criar o primeiro acesso da Gestão e conferir que o responsável só vê e
   altera sua própria filial. Repetir em aparelho/navegador com evidências.
6. Só depois de revisão, aprovação, backup e plano de reversão publicar para
   estabelecimentos reais.

## E-mail e custo

O SMTP padrão do Supabase é para exploração: só envia a endereços autorizados
na organização, tem limite baixo e não oferece SLA. Portanto, a hospedagem
gratuita atual **não basta** para convidar restaurantes reais. Um SMTP
externo precisa de escolha e revisão de segurança, custo, privacidade,
entregabilidade e limites antes de configuração. Nenhum fornecedor ou plano
pago é aprovado por esta ADR.

## Alternativas e riscos

- Link da loja sem Auth: rejeitado; não prova e-mail nem cria identidade
  confiável.
- Membership imediato ao enviar convite: rejeitado; concederia acesso antes
  de comprovar o destinatário.
- Acesso direto do PWA à chave administrativa: rejeitado.
- Token próprio de convite além do Auth: evitar inicialmente para não manter
  dois segredos de ativação. Se a revogação do registro não atender a um caso
  operacional, propor mecanismo adicional com hash, expiração e uso único.
- Prefetch de links por filtros de e-mail pode consumir links de Auth. O
  template e o primeiro acesso precisam de teste com OTP ou confirmação por
  botão, conforme o transporte escolhido.
- Usuário com conta Auth pré-existente exige fluxo de convite que não crie
  segunda conta; aceitar somente após novo login e e-mail verificado igual.

## Reversão e aceite

Antes da publicação, desabilitar a rota/flag e revogar convites pendentes.
Após aceites reais, não apagar memberships nem auditoria automaticamente;
qualquer reversão de DDL depende de backup e migração revisada. O aceite da
issue #40 exige MFA real do Master, convite de uso único com prazo e
revogação, auditoria, testes de abuso e isolamento no Supabase de homologação,
prova de entrega de e-mail, revisão técnica independente e aprovação do
proprietário. Esta ADR, sozinha, não cumpre esses critérios.

## Fontes técnicas

- [Supabase Auth: convites administrativos](https://supabase.com/docs/guides/auth/users)
- [Supabase Auth: MFA e níveis AAL](https://supabase.com/docs/guides/auth/auth-mfa)
- [Supabase Auth: SMTP e restrições do servidor padrão](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase Auth: templates e prefetch de links](https://supabase.com/docs/guides/auth/auth-email-templates)
