# Segurança multiempresa — fundação GOG-074

**Status:** primeira camada de domínio e testes unitários. Não há banco, autenticação Supabase, RLS ou endpoints de negócio nesta entrega. **Não usar em produção.**

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

## Limitações críticas
- Não confiar em user_id/tenant_id fornecidos diretamente por clientes; derivar identidade de JWT validado no servidor e vínculos de fonte confiável.
- Não há proteção real de banco ou política RLS ainda. Testes em memória não comprovam isolamento PostgreSQL.
- Não há RBAC completo, autenticação, migrações ou dados persistidos.

## Próximas tarefas antes de uso real
1. Modelagem PostgreSQL com chaves compostas/restrições por tenant e migrations revisadas.
2. Políticas RLS para leitura/escrita e testes de acesso cruzado com identidades reais de teste.
3. Validação de JWT Supabase (assinatura, issuer, audience, expiração) e memberships no backend.
4. RBAC por função, filial e ação, com auditoria.
5. Testes de IDOR, acesso entre filiais, revogação de sessão e operações offline.
6. Revisão de segurança independente e aprovação antes de exposição pública.
