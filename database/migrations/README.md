# Migrações do GOGDELY

As migrações numeradas são a fonte do esquema PostgreSQL. O projeto `GOGDELY Homologação` (antes `GOGDELY Testes`) é separado dos projetos de outros produtos e não contém dados reais. Na publicação da `develop` atual ou da futura `main`, somente o serviço gratuito de homologação identificado em `gogdely_api/homologation_migrations.py` aplica as migrations pendentes antes de iniciar a API, com destino fixo, cópia interna dos dados fictícios, transação, registro de versão e checksum. Outros ambientes não executam este fluxo. Produção exige backup externo recuperável e etapa de migração separada.

## Ordem

1. `0001_cloud_foundation.sql`: esquema `gogdely`, empresas, filiais, vínculos de usuários, cardápio, pedidos e eventos. Todas as tabelas têm `tenant_id`, RLS habilitado e forçado. Não há políticas nem privilégios para `anon`/`authenticated`: o acesso de aplicação fica bloqueado até a autorização da API ser implementada e revisada.
2. Criar o bucket privado de imagens com a configuração versionada em `database/storage/gogdely-menu-testes.json`, pelo painel ou API oficial de Storage. Não escrever diretamente na tabela interna `storage.buckets`.
3. `0002_membership_read_policies.sql`: concede apenas leitura autenticada das quatro tabelas de vínculo. Ainda requer revisão independente, backup, comparação do esquema instalado e validação no projeto de homologação antes de aplicação.
4. `0006_master_administration.sql`: cria configuração de comissão e auditoria imutável do Master. Depende da fundação `0001`; aplicar somente após backup verificável, comparação do esquema e revisão do plano de reversão. O cadastro nasce em `draft`, o vínculo de responsável exige conta de e-mail já confirmada, e a ativação exige ao menos um owner. Não envia convites nem processa pagamentos.

Cada arquivo é executado uma única vez, em ordem, no projeto de **homologação** e registrado em `gogdely.schema_migrations`. Antes de integrar o arquivo à `main`, confirmar projeto, ambiente, versão do Git e revisão técnica. Não executar no banco de outro produto nem em produção.

## Verificação

### Backup manual da homologação

O plano gratuito não oferece backup agendado. Antes da `0002`, é possível
produzir um dump lógico **somente do esquema `gogdely`** com `pg_dump` e
`pg_restore` oficiais, sem contratar um plano. O script
[`scripts/backup-gogdely-homologation.ps1`](../../scripts/backup-gogdely-homologation.ps1)
usa o session pooler IPv4 confirmado para o projeto de homologação, exige o
certificado CA baixado em **Database > Settings > SSL configuration**, força
`verify-full` e pede a senha do banco diretamente no terminal. Escolha uma
pasta privada **fora do repositório** para o arquivo `.dump`. Não copie a senha
para a linha de comando, variável persistente, Git ou esta conversa.

Exemplo, após instalar as ferramentas oficiais PostgreSQL (`pg_dump` e
`pg_restore`) no Windows:

```powershell
.\scripts\backup-gogdely-homologation.ps1 `
  -OutputDirectory 'C:\GOGDELY-backups' `
  -CaCertificate 'C:\caminho\prod-ca-2021.crt'
```

O script confirma que o arquivo não está vazio e que `pg_restore --list`
consegue lê-lo; isso **não substitui um teste de restauração**. O dump não
inclui `auth`, `storage` nem outros esquemas administrados pelo Supabase.
Registre caminho privado, tamanho e hash SHA-256 sem publicar o conteúdo.
Sem arquivo gerado e verificado, o requisito de backup permanece pendente.

Para comparar o esquema instalado antes do backup, execute a consulta somente
de leitura [`0001_catalog_audit.sql`](../verification/0001_catalog_audit.sql)
e confira todas as colunas, restrições e índices contra a migration `0001`.

Após aplicar a `0001` e criar o bucket, **antes da `0002`**, execute `database/verification/0001_foundation.sql` no SQL Editor do mesmo projeto. Ele falha se faltar tabela, se RLS estiver desligado, se uma política aparecer ou se o bucket não for privado. Nenhum dado de cliente é necessário.

Depois da `0002`, crie **duas identidades descartáveis** pelo Supabase Auth de homologação com os e-mails reservados `gogdely-rls-a@example.invalid` e `gogdely-rls-b@example.invalid`, sem envio de convite. Execute `database/verification/0002_membership_read_policies.sql` no SQL Editor como operador administrativo do projeto. O script cria empresas e filiais fictícias em uma transação, testa leitura como `manager`, `staff`, `owner` e `anon`, escrita negada e revogação imediata, e termina com `ROLLBACK`. Se falhar, não trate a migration como homologada; registre a mensagem e confirme que a transação foi revertida. Remova as duas identidades descartáveis pelo Auth após a verificação. Não execute este teste em produção ou em projeto compartilhado.

O arquivo de verificação é uma preparação revisável, **não evidência de execução no Supabase**. Registre projeto, SHA, data, revisor, resultado e testes negativos da API antes de afirmar isolamento completo.

## Reversão em testes

Se o projeto ainda estiver vazio e exclusivo do GOGDELY, a reversão é remover o bucket `gogdely-menu-testes` e o esquema `gogdely` após conferir que não há dados a preservar. Nunca usar `DROP ... CASCADE` em um projeto compartilhado ou com pedidos reais.
