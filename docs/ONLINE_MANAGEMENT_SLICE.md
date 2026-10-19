# Gestão online: primeira fatia — GOG-016/025/043/074/075

## O que foi preparado

- A API expõe configuração **publicável** do Supabase Auth, catálogo público por
  slug e catálogo da filial para usuário autenticado. Criação e atualização de
  produtos exigem papel `owner` ou `manager`, passam por RLS de filial e gravam
  um evento de auditoria na mesma transação. Alterações concorrentes ao produto
  retornam 409 e pedem recarga.
- A Gestão hospedada usa e-mail/senha do Supabase Auth, lê os vínculos da API,
  seleciona a filial e edita nome, descrição, categoria, preço e disponibilidade
  de produtos. Não recebe senha administrativa nem conexão direta com Postgres.
- A preferência `allow_online_payment` pode ser alterada por loja. O campo
  `online_payment_available` permanece **false** até haver integração real com
  provedor de pagamento, confirmação e conciliação. Com a opção desligada, o
  pedido da mesa deverá ser enviado para fechamento no caixa. Este fluxo de
  pedido da mesa ainda não está implementado online.
- O PWA Cliente hospedado, compilado com `GOGDELY_HOSTED_PWA=true`, abre
  `?loja=<slug>&mesa=<numero>` no catálogo público da API e permite buscar
  produtos da loja. Não oferece pedidos ou pagamentos fictícios. A Gestão
  autenticada gera o link e a matriz QR após validar o vínculo da filial.
  Esse QR apenas abre o catálogo; ainda não cria pedido. Sem slug, a entrada
  informa que é necessário o link da loja. Na Gestão web, a ficha de mesa
  abre isolada para imprimir ou salvar em PDF pela função do navegador.

## Configuração e ordem de implantação

1. Revisar o esquema real e obter backup restaurável do projeto Supabase de
   homologação. A interface do plano Free informa que **não há backups
   agendados**. Em 19/10/2026, consulta de contagem no SQL Editor mostrou zero
   linhas nas oito tabelas `gogdely` da fundação, zero usuários `auth.users`
   e zero políticas `gogdely`. As contagens de colunas por tabela coincidem
   com `0001_cloud_foundation.sql` (6/3/4/12/9/8/15/4), mas isso **não
   substitui** um backup restaurável de esquema e Auth.
2. Aplicar, em ordem, `0002_membership_read_policies.sql`,
   `0003_catalog_read_policies.sql`, `0004_catalog_write_policies.sql` e
   `0005_table_payment_preference.sql`, após comparação com o esquema instalado.
   Registrar hora, operador e resultado. Não aplicar por auto deploy do Render.
3. Configurar `GOGDELY_CORS_ORIGINS` na API para a origem HTTPS exata do site
   estático de homologação. Conferir `GOGDELY_SUPABASE_URL` e
   `GOGDELY_SUPABASE_PUBLISHABLE_KEY` na API; nunca usar service-role no PWA.
4. Configurar `GOGDELY_API_BASE_URL` no build do Static Site para a API de
   homologação e `GOGDELY_CLIENT_PWA_URL` na API para a URL HTTPS do Cliente
   terminada em `/cliente/`. Publicar o mesmo commit na API e nos PWAs, conferir `/ready`,
   `/api/v1/client-config`, `version.json` e uma entrada real com usuário de
   teste vinculado a uma filial.
5. Testar no Supabase: dono/gerente cria e edita; funcionário é bloqueado;
   outra empresa/filial não lê nem altera; catálogo público só revela loja
   ativa e item disponível; revogação do vínculo bloqueia o próximo pedido.

## Limites e dependências

- Cadastro de empresas, convites, senha no primeiro acesso e recuperação de
  terceiros ainda não estão implementados. Exigem Master com MFA, fluxo
  auditado e SMTP próprio; o SMTP padrão do Supabase não serve para enviar
  convites a empresas externas.
- Mesas QR com pedido online, exportação PDF nativa, pagamentos Pix/split, comissões,
  entregadores, promoções e integrações iFood/99Food seguem em requisitos
  separados. A tela de Gestão não deve apresentar dados fictícios como reais.
- `supabase_flutter` 2.18.3 (MIT) e `http` 1.6.0 (BSD-3) foram adicionados ao
  PWA Gestão; revisar dependências transitivas antes de distribuição comercial.

## Reversão

Reverter o commit do PWA/API e republicar o último deploy íntegro. Migrações
novas não devem ser removidas sem verificar dados e dependências criadas desde
a aplicação; restaurar do backup validado quando necessário. A preferência de
pagamento não autoriza liquidação financeira.
