# Leitura de vínculos online — GOG-074 (issue #39)

**Estado:** implementação em branch de integração para revisão. A migration
`0002_membership_read_policies.sql` não foi aplicada no Supabase, e este
endpoint não foi publicado no Render.

## Fluxo

1. `GET /api/v1/auth/memberships` exige o token de acesso do Supabase Auth.
2. A API verifica o token em `/auth/v1/user` e recebe o UUID do usuário.
3. A conexão PostgreSQL inicia uma transação, define o sujeito verificado
   apenas para ela e assume o papel `authenticated`.
4. A consulta lista somente os vínculos do usuário. As políticas RLS filtram
   empresas e filiais: `owner` vê todas as filiais da empresa; `manager` e
   `staff` veem apenas filiais em `membership_branches`.
5. Qualquer falha de configuração, SQL, conexão ou política retorna HTTP 503
   sem expor credenciais. Token ausente ou inválido retorna HTTP 401.

As políticas concedem **somente SELECT** às quatro tabelas de vínculo; não
concedem escrita nem acesso aos pedidos, cardápios, eventos ou pagamentos.
A API continua sendo a autoridade para operações comerciais. Clientes
compradores e entregadores não usam esses vínculos.

## Verificação antes de aplicar

- Confirmar que `0001_cloud_foundation.sql` é exatamente o esquema instalado
  na homologação e realizar backup da base.
- Revisar a migration por pessoa independente e executar testes negativos
  reais com dois usuários, duas empresas e filiais distintas, incluindo
  ausência de vínculo, papel `staff`, `manager` e `owner`.
- Confirmar que a conexão do Render pode assumir `authenticated` dentro de
  uma transação e que `auth.uid()` lê o sujeito configurado.
- Configurar `GOGDELY_SUPABASE_URL`, a chave publicável e
  `GOGDELY_CORS_ORIGINS` no serviço de homologação; nenhuma chave
  administrativa pode ser enviada ao PWA.
- Aplicar apenas em homologação, verificar `/ready` e o endpoint autenticado,
  e checar os logs sem registrar tokens ou dados pessoais.

Os testes Python usam Auth e PostgreSQL simulados; validam a exigência do
token, o sujeito confiável, o papel RLS e a falha fechada. Não demonstram que
a política já funciona no Supabase real.

## Reversão

Em transação, revogar SELECT e USAGE concedidos pela migration e remover as
quatro políticas criadas; reverter o commit da API em nova branch revisada.
Antes de executar a reversão, confirmar que nenhuma outra funcionalidade
passou a depender das mesmas permissões.

## Próximas dependências

O convite de lojas (GOG-025/#40) exige escrita auditada de convites e
membership após aceitação, autorização Master com MFA e provedor de e-mail.
Links/QR de lojas (GOG-020/026/#41) exigem cardápio público por slug, URLs
estáveis e pedidos online com autorização e isolamento comprovados. O QR
atual de mesa é apenas do laboratório SQLite.

Referência: [Supabase — Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).
