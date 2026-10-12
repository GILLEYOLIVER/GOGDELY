# Componentes de terceiros — GOGDELY

## QR do cardápio local
- **python-qrcode** 8.2 — [repositório](https://github.com/lincolnloop/python-qrcode), licença BSD-3-Clause. Usado pela API local para gerar o SVG do QR das mesas, sem serviço externo. A licença inclui avisos de origem que devem acompanhar eventual redistribuição; a revisão completa da árvore transitiva segue pendente antes de publicação.

## Bibliotecas declaradas em apps/cliente/pubspec.yaml
1. **http** 1.6.0 — https://pub.dev/packages/http — BSD-3-Clause, licença conferida no pacote local em cache; usado pelo cliente HTTP de teste em `packages/local_demo_api` e pelos três aplicativos.
2. **flutter_map** — https://github.com/fleaflet/flutter_map — BSD-3-Clause (licença identificada no repositório de origem).
3. **mobile_scanner** — https://github.com/juliansteenbakker/mobile_scanner — BSD-3-Clause (licença identificada no repositório de origem).
4. **latlong2** — https://pub.dev/packages/latlong2 — Apache-2.0 na versão local resolvida.

## Versões verificadas no protótipo local (11/10/2026)
- `flutter_map` 8.3.2: BSD-3-Clause, conferida no `LICENSE` do pacote resolvido no cache Pub.
- `mobile_scanner` 7.4.2: BSD-3-Clause, conferida no `LICENSE` do pacote resolvido no cache Pub.
- `latlong2` 0.9.1: Apache-2.0, conferida no `LICENSE` do pacote resolvido no cache Pub.

O catálogo e carrinho fictícios utilizam widgets da SDK Flutter; não foi copiado código de outro aplicativo do GitHub. Esta verificação cobre apenas as três dependências diretas acima, não toda a árvore transitiva nem homologação de redistribuição.

**Uso:** dependências declaradas, não código-fonte copiado. Versões resolvidas e dependências transitivas ainda devem ser verificadas e registradas com seus respectivos avisos de licença.

## Gate antes do merge
- Executar `flutter pub get`, `flutter analyze`, `flutter test` em ambiente aprovado.
- Verificar compatibilidade Flutter/Dart e APIs de cada pacote.
- Revisar licenças da árvore resolvida e avisos de redistribuição.
- Avaliar permissões de câmera, privacidade e segurança de QR.
- Avaliar provedor de tiles, termos de uso, atribuição, privacidade e custos antes de mapas reais.
- Aprovação técnica independente e do proprietário; não presumir que esta integração esteja homologada.
