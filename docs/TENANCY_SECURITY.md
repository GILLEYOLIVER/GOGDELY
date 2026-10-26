# Segurança multiempresa — fundação GOG-074

**Status:** primeira camada de domínio e testes unitários. Esta branch adiciona
verificação pontual da identidade pelo Supabase Auth em `/api/v1/auth/me`
(GOG-075); ainda não há autorização por vínculo, RLS operacional ou endpoints
de negócio. **Não usar em produção.**

## Modelo conceitual
- Tenant: empresa proprietária de filiais, produtos, pedidos e usuários vinculados.
- Branch: filial com tenant_id obrigatório.
- Membership: vínculo autenticado entre usuário, empresa, função e filiais autorizadas.
- Uma pessoa pode ter vínculos distintos com múltiplas empresas; autorização deve verificar o contexto de cada operação.

## Garantias implementadas nesta etapa
- Authorizer de demonstração com política deny-by-default.
- Validação de tenant e filial em memória.
- Testes de permissão e negação de acesso cruzado entre empresas.
- Dados de demonstração determinísticos sem credenciais nem informações reais.
- Identidade obtida do endpoint verificador do Supabase Auth, sem confiar em
  `user_id`, `tenant_id` ou papel enviados pelo cliente. Ver
  [AUTH_IDENTITY.md](AUTH_IDENTITY.md).

## Limitações críticas
- Não confiar em user_id/tenant_id fornecidos diretamente por clientes;
  identidade verificada ainda precisa ser ligada a vínculos de fonte confiável.
- Não há proteção real de banco ou política RLS ainda. Testes em memória não comprovam isolamento PostgreSQL.
- Não há RBAC completo, login/convites, migrações ou dados persistidos nesta branch.

## Próximas tarefas antes de uso real
1. Modelagem PostgreSQL com chaves compostas/restrições por tenant e migrations revisadas.
2. Políticas RLS para leitura/escrita e testes de acesso cruzado com identidades reais de teste.
3. Vincular identidade confirmada pelo Supabase Auth a memberships no backend;
   testar expiração, revogação e perfis com o serviço de homologação.
4. RBAC por função, filial e ação, com auditoria.
5. Testes de IDOR, acesso entre filiais, revogação de sessão e operações offline.
6. Revisão de segurança independente e aprovação antes de exposição pública.
