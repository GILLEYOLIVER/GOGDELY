# Loja fictícia na homologação (GOG-017, GOG-041, GOG-042, GOG-052)

Este fluxo usa exclusivamente o projeto Supabase **GOGDELY Homologação**. Os
produtos, pedidos, endereço e ganhos são fictícios. Não há cobrança, liquidação,
navegação GPS nem contratação de entregas reais.

## Dados e isolamento

- Tenant de teste: `c95d5aca-8eea-4ad4-8b50-53117abe3f01`.
- Filial: `d3bdc553-639a-47c4-9cea-aad6a06725ea`.
- Link da loja: `/cliente/?loja=loja-ficticia-gogdely`.
- Doze produtos de teste, sendo um indisponível, são criados pelo seed
  `database/seeds/2026-10-25_homologacao_ficticia.sql`.
- A conta Auth já existente no projeto é vinculada à loja apenas na
  homologação. O acesso Master exige seu próprio MFA.
- O vínculo fictício de entregador e o valor fixo fictício por entrega são
  criados por `database/seeds/2026-10-25_entrega_ficticia.sql`, após a
  migration 0007. A reutilização desta conta entre perfis é restrita a este
  ensaio; criar identidades distintas antes de qualquer operação real.
- As credenciais de teste e sua origem ficam somente no arquivo local ignorado
  `apps/gestao/acessos`. Ele nunca deve ser incluído em commits ou logs.

## Ordem para ativar no banco

1. Confirmar o projeto e comparar o esquema atual em modo somente leitura.
2. Para o teste com dados inteiramente fictícios, executar pelo SQL Editor
   `database/checks/2026-10-25_homologacao_preflight.sql` e conferir os
   resultados. Se coincidirem com 1 tenant, 1 filial, 1 vínculo, 12 itens,
   0 pedidos, 0 políticas e 8 tabelas, executar
   `database/checks/2026-10-25_homologacao_internal_snapshot.sql` e
   verificar as contagens copiadas. Essa cópia interna é reversível para os
   dados fictícios, mas **não é um backup integral ou externo**. Antes de
   receber dados reais, criar um dump recuperável fora do projeto.
3. Aplicar as migrations versionadas 0002, 0003, 0004, 0005, 0006 e 0007,
   nesta ordem, cada uma em transação, após conferir seu conteúdo. A 0001 já
   está instalada no projeto. O Render não aplica migrations automaticamente.
4. Executar o seed `2026-10-25_entrega_ficticia.sql`. O seed da loja e dos
   produtos já foi aplicado em 2026-10-25; ele é idempotente.
5. Conferir as tabelas, políticas RLS, permissões e contagem dos dados apenas
   neste tenant antes de publicar a API.
6. Publicar API e PWAs com o mesmo commit e conferir `/ready`, `version.json`,
   catálogo público e os fluxos autenticados nos três apps.

Não declarar o ambiente pronto se qualquer etapa acima estiver pendente.

## Fluxo esperado

O Cliente acessa a loja por link ou QR, pesquisa produtos, escolhe itens e
cria um pedido fictício. O servidor consulta o preço atual no banco, registra
itens e total e devolve o número do pedido. A Gestão autenticada enxerga o
pedido, altera seu estado e disponibiliza a entrega quando estiver pronta.
O Entregador vinculado e ativo vê a loja e a corrida disponível, aceita, inicia
e conclui a entrega. O valor mostrado no app é uma simulação determinada pela
configuração da loja e registrada na atribuição. Os estados são persistidos no
Supabase e podem ser relidos pelos três aplicativos.

Os endpoints `/api/v1/demo/orders` e `/api/v1/courier/*` respondem 404 fora
dos ambientes `testes` e `homologacao`. Todos os comandos autenticados passam
pela API e verificam tenant, filial, papel e vínculo ativo. As tabelas de
entrega têm RLS forçada e nenhum acesso direto a `anon` ou `authenticated`.

## Reversão

1. Se a publicação da aplicação falhar, restaurar o commit anterior nos
   serviços Render. As migrations são aditivas e não precisam ser desfeitas
   para reverter a aplicação.
2. Para remover somente os dados de teste, conferir os UUIDs acima e executar
   `database/seeds/2026-10-25_homologacao_ficticia_rollback.sql` no projeto de
   homologação. Isto apaga os pedidos e produtos fictícios do tenant conhecido;
   não executar em outro ambiente.
3. Guardar o dump verificado antes de qualquer correção de esquema. Uma
   restauração integral exige decisão separada, pois substitui dados.

## Estado em 2026-10-25

O seed da loja e dos produtos está no Supabase. As migrations 0002 a 0007,
o vínculo de entregador, a checagem e cópia interna verificadas e a publicação deste fluxo ainda
dependem de execução e checagem. O aplicativo hospedado atualmente não prova
o fluxo descrito neste documento.
