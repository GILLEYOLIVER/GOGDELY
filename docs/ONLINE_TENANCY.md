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

`GET /api/v1/management/tenants/{tenant_id}/branches/{branch_id}/context`
usa a mesma identidade verificada e a mesma transação RLS para resolver uma
filial da Gestão. O ID enviado pelo cliente é apenas um alvo de busca: a API
liga empresa, filial e membership do sujeito verificado. Filial inexistente,
de outra empresa, não vinculada ou revogada retorna o mesmo HTTP 404.

As políticas concedem **somente SELECT** às quatro tabelas de vínculo; não
concedem escrita nem acesso aos pedidos, cardápios, eventos ou pagamentos.
A API continua sendo a autoridade para operações comerciais. Clientes
compradores e entregadores não usam esses vínculos.

## Verificação antes de aplicar

### Estado observado em 18/10/2026

No projeto isolado **GOGDELY Homologação** (`vlcssgerbhbvekukpzki`), a
consulta administrativa de leitura confirmou oito tabelas no esquema
`gogdely`, todas com RLS habilitado e forçado, zero políticas e zero linhas
em cada uma das oito tabelas. O roteiro `0001_foundation.sql` foi executado
novamente no SQL Editor e retornou `gogdely test foundation: verified`,
incluindo a checagem do bucket privado. A página de Auth não exibiu contas
de teste. Essas observações não comprovam que o DDL instalado é idêntico ao
arquivo versionado `0001_cloud_foundation.sql`.

Uma inspeção adicional de leitura confirmou colunas/tipos/valores padrão
compatíveis com a `0001`, 39 restrições, 12 índices e ausência de privilégios
de `USAGE`/`SELECT` para `anon` e `authenticated`. Isso ainda não equivale a
um dump completo ou a uma restauração testada.

O painel de backups do plano gratuito informa que não há backups agendados.
Nenhum backup manual recuperável foi confirmado. Por isso, a `0002` continua
**não aplicada**; o roteiro transacional com duas identidades também não foi
executado. Antes de aplicar, ainda faltam comparação completa do esquema
instalado, backup recuperável e revisão técnica independente da migration.
Nenhum serviço pago ou upgrade foi contratado.
O [procedimento de backup manual](../database/migrations/README.md#backup-manual-da-homologação)
está preparado, mas não foi concluído. As ferramentas PostgreSQL 18.6 e o
certificado CA foram instalados fora do repositório; a conexão com o pooler
respondeu ao `pg_isready`. Isso não autentica nem confirma um backup. O
`pg_dump` requer a senha do banco digitada em um terminal interativo. Uma
tentativa sem essa senha foi encerrada, sem gerar arquivo de backup.

Em um PostgreSQL 18.6 descartável no Windows, as migrations `0001` e `0002`
foram aplicadas em sequência com roles `anon`/`authenticated`, uma tabela
`auth.users` e uma função `auth.uid()` simuladas. O roteiro
`0002_membership_read_policies.sql` passou para `manager`, `staff`, `owner`,
revogação e `anon`; após seu `ROLLBACK`, as quatro tabelas de vínculos e
empresas voltaram a zero linhas. O servidor local foi desligado. Esse teste
não substitui a execução no Supabase nem a revisão independente.

- Confirmar que `0001_cloud_foundation.sql` é exatamente o esquema instalado
  na homologação e realizar backup da base.
- Revisar a migration por pessoa independente e executar testes negativos
  reais com dois usuários, duas empresas e filiais distintas, incluindo
  ausência de vínculo, papel `staff`, `manager` e `owner`. O roteiro transacional
  em `database/verification/0002_membership_read_policies.sql` prepara os
  testes de banco sem persistir empresas/filiais fictícias.
- Confirmar que a conexão do Render pode assumir `authenticated` dentro de
  uma transação e que `auth.uid()` lê o sujeito configurado.
- Configurar `GOGDELY_SUPABASE_URL`, a chave publicável e
  `GOGDELY_CORS_ORIGINS` no serviço de homologação; nenhuma chave
  administrativa pode ser enviada ao PWA.
- Aplicar apenas em homologação, verificar `/ready` e o endpoint autenticado,
  e checar os logs sem registrar tokens ou dados pessoais.

Os testes Python usam Auth e PostgreSQL simulados; validam a exigência do
token, o sujeito confiável, o papel RLS, a falha fechada e o contrato do
contexto de filial, inclusive ID de outra empresa e revogação na requisição
seguinte. Não demonstram que a política já funciona no Supabase real. O
roteiro SQL local com PostgreSQL descartável testa as políticas separadamente.
Além disso, a API foi exercitada contra esse PostgreSQL local com `manager`,
`staff`, `owner`, filial de outra empresa e revogação; as respostas foram
200/404 conforme o escopo esperado. O servidor local foi desligado. Ainda
falta repetir a integração no Supabase de homologação com Auth real.

### Matriz repetível para API + RLS em homologação

Depois do backup, da revisão e da aplicação autorizada da `0002`, criar duas
identidades descartáveis no Auth e os vínculos de teste em transação controlada.
Executar cada chamada com um token **real** de Auth da identidade indicada;
nenhum token deve entrar no repositório, no histórico do terminal ou nas
evidências. Consultar `GET /api/v1/auth/memberships` e
`GET /api/v1/management/tenants/{tenant_id}/branches/{branch_id}/context`.

| Identidade e vínculo | Alvo | Resultado esperado |
| --- | --- | --- |
| Usuário A, `manager` de A/A1 | A/A1 | 200, papel `manager` |
| Usuário A, `manager` de A/A1 | A/A2 | 404, `Branch not found` |
| Usuário A, `manager` de A/A1 | B/B1 | 404, mesma resposta |
| Usuário B, `staff` de B/B1 | B/B1 | 200, papel `staff` |
| Usuário B, `staff` de B/B1 | A/A1 | 404, mesma resposta |
| Usuário A, após promoção a `owner` de A | A/A2 | 200, papel `owner` |
| Usuário A, após revogação do vínculo | A/A1 e A/A2 | 404 na requisição seguinte |
| Sem token ou com token inválido | Qualquer filial | 401 |

Registrar projeto, SHA do deploy, IDs fictícios, horários, códigos HTTP e
revisor. Apagar os vínculos/identidades descartáveis após o ensaio. A passagem
do roteiro SQL isolado não substitui esta matriz pela API hospedada.

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
