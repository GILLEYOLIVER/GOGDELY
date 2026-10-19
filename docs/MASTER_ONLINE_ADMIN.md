# Administração online do Master — GOG-004/025/082/096

## Escopo desta entrega

- Corrige contraste, cabeçalho e cartões no PWA instalado, mantendo a paleta azul elétrico, branco e grafite aprovada.
- Permite criar empresa e primeira filial em `draft`, vincular uma conta Supabase Auth **já confirmada** como responsável, ativar/suspender empresa e salvar política percentual de comissão.
- Cada comando exige identidade verificada, UUID autorizado em `GOGDELY_MASTER_USER_IDS` e sessão Supabase `aal2` (MFA). Alteração e motivo são gravados na mesma transação em `master_audit`; a tabela rejeita `UPDATE` e `DELETE`.
- Empresa suspensa some do catálogo público e seus comandos de Gestão falham fechados. A sessão da empresa continua existente; a tela deve informar a suspensão em uma entrega posterior.
- A configuração de comissão não altera pedidos antigos ou atuais e não processa cobrança, Pix, split ou repasse.

## Preparação de banco e publicação

1. Revisar o SHA exato da branch, comparar o esquema instalado da homologação e criar backup recuperável do esquema `gogdely`.
2. Aplicar `database/migrations/0006_master_administration.sql` uma vez no projeto GOGDELY Homologação. Registrar resultado e verificar RLS forçado e ausência de permissões para `anon`/`authenticated`.
3. Testar com duas contas descartáveis: proprietário Master com MFA, outro usuário sem autorização, e um responsável confirmado. Verificar que AAL1 e outro usuário recebem 403, que toda alteração gera auditoria e que uma empresa suspensa desaparece do catálogo.
4. Publicar API e PWA do mesmo SHA em homologação. Conferir `/ready`, `/version.json`, `/master/version.json` e o fluxo no celular. Reverter código pelo SHA anterior; não apagar auditoria na reversão.

## Limites de aceite

O e-mail de convite ainda não foi implementado: o SMTP padrão do Supabase não atende empresas externas e a URL de retorno atual vai para `localhost:3000`. A tela **Vincular responsável** só aceita uma conta já confirmada, sem mandar e-mail. A aprovação do fluxo proposto em ADR-0002, SMTP revisado e confirmação do URL são pré-requisitos para convite real. Redefinição de senha de terceiros, valores financeiros realizados, planos, entregadores e operação de produção não fazem parte desta fatia.

## Reversão do banco

Se a migration for aplicada e não houver registros nas duas tabelas, pode-se remover `tenant_commission_settings`, `master_audit` e a função `reject_master_audit_change` após confirmar o backup e o estado do projeto. Se houver auditoria, preservar os eventos e corrigir por migration aditiva; não apagar histórico para reverter uma versão de código.
