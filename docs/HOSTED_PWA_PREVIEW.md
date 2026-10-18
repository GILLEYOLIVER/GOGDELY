# PWAs de homologação — GOG-097/GOG-129

O site estático de homologação publica três prévias Flutter Web em caminhos
separados: `/cliente/`, `/gestao/` e `/entregador/`. Cada manifesto usa um
`id`, `start_url` e `scope` próprios, para que os atalhos instalados não abram
o app errado. O build fixa Flutter 3.47.0 no commit
`4cf24164269a5ebf0c16a028a00727d0e77bbb05` e grava o SHA do código em
`version.json`. Na abertura e ao retornar ao app, `release_update.js` consulta
essa versão e recarrega a página quando uma nova publicação já está no ar.

Essas prévias usam **somente dados fictícios em memória**. Os três aplicativos
não compartilham pedidos entre si e não acessam a API do Render nem o banco
Supabase. Um pedido visualizado na prévia não é um pedido real. O fluxo
integrado com SQLite continua restrito ao laboratório local.

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

Revisão técnica independente e aprovação do proprietário nos PRs de PWA e
backend; integração segura com autenticação, autorização por empresa, catálogo,
pedidos, pagamentos e entrega; migrações versionadas/revisadas; licenças e
política de mapas; testes de segurança, UI, fluxos críticos e dispositivos.
O deploy estático não aplica migrações ao Supabase automaticamente.
