# Componentes de terceiros — GOGDELY

## Bibliotecas declaradas em apps/cliente/pubspec.yaml
1. **flutter_map** — https://github.com/fleaflet/flutter_map — BSD-3-Clause (licença identificada no repositório de origem).
2. **mobile_scanner** — https://github.com/juliansteenbakker/mobile_scanner — BSD-3-Clause (licença identificada no repositório de origem).
3. **latlong2** — https://pub.dev/packages/latlong2 — licença e versão exata ainda requerem verificação antes de distribuição.

**Uso:** dependências declaradas, não código-fonte copiado. Versões resolvidas e dependências transitivas ainda devem ser verificadas e registradas com seus respectivos avisos de licença.

## Gate antes do merge
- Executar `flutter pub get`, `flutter analyze`, `flutter test` em ambiente aprovado.
- Verificar compatibilidade Flutter/Dart e APIs de cada pacote.
- Revisar licenças da árvore resolvida e avisos de redistribuição.
- Avaliar permissões de câmera, privacidade e segurança de QR.
- Avaliar provedor de tiles, termos de uso, atribuição, privacidade e custos antes de mapas reais.
- Aprovação técnica independente e do proprietário; não presumir que esta integração esteja homologada.
