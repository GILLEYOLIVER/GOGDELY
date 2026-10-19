# PWAs de homologação — GOG-097/GOG-129

O site estático de homologação publica três prévias Flutter Web em caminhos
separados: `/cliente/`, `/gestao/` e `/entregador/`. Cada manifesto usa um
`id`, `start_url` e `scope` próprios, para que os atalhos instalados não abram
o app errado. O build fixa Flutter 3.47.0 no commit
`4cf24164269a5ebf0c16a028a00727d0e77bbb05` e grava o SHA do código em
`version.json`. Na abertura e ao retornar ao app, `release_update.js` consulta
essa versão e recarrega a página quando uma nova publicação já está no ar.
Os ícones da Entrega e Gestão usam arte própria azul/grafite, inclusive no
atalho do iPhone (`apple-touch-icon`). Um atalho instalado antes da troca de
ícone pode precisar ser removido e adicionado novamente no iOS.

Em 18/10/2026, o Static Site `gogdely-pwas-homologacao` foi ligado a
`develop`, com auto deploy **On Commit**. O deploy
`dep-dbanoobbc2fs73c3mdp0` ficou `live` no SHA
`17e4f78db2d5043a7353364912cf493a159816e3`. Cliente, Gestão e
Entregador responderam HTTP 200 em seus caminhos; os três `version.json`
confirmaram o mesmo SHA e os manifestos mantiveram `start_url` separados.
Isso é confirmação de publicação, sem teste visual nos aparelhos nesta entrega.

No deploy registrado acima, as três prévias usavam **dados fictícios em
memória**. A mudança de catálogo online nesta branch ainda não está publicada:
o Cliente hospedado passa a consultar o catálogo público por link de loja e
mesa, e a Gestão usa a API autenticada para editar produtos e gerar QR de
mesa. Isso depende das migrações e da configuração descritas em
[ONLINE_MANAGEMENT_SLICE.md](ONLINE_MANAGEMENT_SLICE.md). O Entregador continua
demonstrativo. Nenhum dos PWAs compartilha ainda pedidos online.

## Publicação e verificação

- Build: `bash scripts/build_render_pwas.sh` na raiz do repositório.
- Diretório público: `build/pwa` em um único Render Static Site gratuito.
- O site está com `noindex` e inclui créditos/licenças. O mapa ilustrativo usa
  tiles OpenStreetMap sob demanda; revisar a política/atribuição antes de abrir
  acesso amplo ou usar em operação comercial.
- Conferir HTTP 200 para os três `index.html`, `manifest.json`,
  `main.dart.js` e `version.json`; conferir o SHA, os três escopos e uma
  abertura real em navegador/dispositivo.
- Reversão: no Render, republicar o último deploy estático íntegro. O site de
  homologação não altera dados do Supabase.

## Pendências para produção

Integração segura com autenticação, autorização por empresa, catálogo,
pedidos, pagamentos e entrega; migrações versionadas/revisadas; licenças e
política de mapas; testes de segurança, UI, fluxos críticos e dispositivos.
O deploy estático não aplica migrações ao Supabase automaticamente.
