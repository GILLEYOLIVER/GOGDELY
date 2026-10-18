# Migrações do GOGDELY

As migrações numeradas são a fonte do esquema PostgreSQL. O projeto `GOGDELY Testes` é separado dos projetos de outros produtos e não contém dados reais. Os arquivos não são executados automaticamente pelo deploy do Render.

## Ordem

1. `0001_cloud_foundation.sql`: esquema `gogdely`, empresas, filiais, vínculos de usuários, cardápio, pedidos e eventos. Todas as tabelas têm `tenant_id`, RLS habilitado e forçado. Não há políticas nem privilégios para `anon`/`authenticated`: o acesso de aplicação fica bloqueado até a autorização da API ser implementada e revisada.
2. `0002_test_storage.sql`: bucket privado para imagens de teste, sem políticas de leitura ou upload público.

Cada arquivo deve ser executado uma única vez, em ordem, no projeto de **testes** e registrado no controle de migrações quando o fluxo automatizado for adotado. Antes de aplicar, confirmar projeto, ambiente, versão do Git e revisão técnica. Não executar no banco de outro produto nem em produção.

## Verificação

Após aplicar, execute `database/verification/0001_foundation.sql` no SQL Editor do mesmo projeto. Ele falha se faltar tabela, se RLS estiver desligado, se uma política permissiva aparecer ou se o bucket não for privado. Nenhum dado de cliente é necessário.

## Reversão em testes

Se o projeto ainda estiver vazio e exclusivo do GOGDELY, a reversão é remover o bucket `gogdely-menu-testes` e o esquema `gogdely` após conferir que não há dados a preservar. Nunca usar `DROP ... CASCADE` em um projeto compartilhado ou com pedidos reais.
