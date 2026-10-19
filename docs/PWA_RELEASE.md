# Atualização dos PWAs — GOG-071/129

O Cliente, a Gestão e o Entregador têm build Web. Em cada origem hospedada, `release_update.js` consulta `version.json` com `cache: no-store` ao abrir, retomar e a cada minuto. Ao detectar outro SHA, recarrega uma vez. No piloto local do Cliente, `pwa_update.js` continua usando o endpoint local; são mecanismos distintos.

## Gerar uma release candidata

1. Usar o commit da release autorizada na `main` e executar `flutter build web --release` em `apps/cliente`, `apps/gestao` e `apps/entregador`, sem `GOGDELY_LOCAL_API=true`.
2. Executar `python scripts/stamp_pwa_version.py <SHA completo>` na raiz. O script só grava `version.json` se os três builds estiverem completos.
3. Publicar os três bundles em origens HTTPS separadas, com `Cache-Control: no-cache, max-age=0, must-revalidate` para os arquivos que não têm hash no nome e para `version.json`. Verificar o manifesto, ícones e a versão servida em cada URL.
4. Tornar as novas versões disponíveis após a API do mesmo SHA responder `/ready` e `/version.json`, mais o teste de fluxo em dispositivo.

## Limites atuais

Os três builds locais são prévias demonstrativas. Não há hospedagem pública, pipeline de publicação, autenticação multiempresa, API gerenciada ou teste no iPhone instalado para esta release. `version.json` no bundle local é um marcador de build, não prova de deploy live. Apps nativos instalados dependem de distribuição própria; atualizar dados remotos não altera o binário do aplicativo.

O workflow `pwa-build.yml` compila e verifica os três bundles em PRs e pushes para `develop`/`main` com o SDK Flutter fixado em `4cf24164269a5ebf0c16a028a00727d0e77bbb05` (3.47.0). Ele não publica artefatos: a publicação exige a API pronta no mesmo SHA, autorização de entrega e verificação das três URLs. A revisão independente é opcional (GOG-107 atualizado). O checkout do código fonte do Flutter é do repositório oficial; não há nova action de terceiros para instalar o SDK.
