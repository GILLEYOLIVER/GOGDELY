# GOGDELY Cliente — protótipo Flutter de componentes

**Status:** integração inicial para avaliação técnica. Não é marketplace funcional.

## Componentes externos
- [flutter_map](https://github.com/fleaflet/flutter_map) — BSD-3-Clause, renderização de mapas Flutter.
- [mobile_scanner](https://github.com/juliansteenbakker/mobile_scanner) — BSD-3-Clause, leitura QR/barcode.
- [latlong2](https://pub.dev/packages/latlong2) — coordenadas para o mapa (licença da versão resolvida ainda a verificar).

As bibliotecas são referenciadas via pubspec; **código de terceiros não foi copiado**. Avisos de licença devem acompanhar distribuição.

## Executar após revisão
Requer Flutter SDK no Windows. No diretório `apps/cliente`:

```powershell
flutter create --platforms=android,ios,web .
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

`flutter create` gera scaffolding nativo ainda ausente; revisar alterações antes de commitar. Chrome é prévia visual, não simulador iOS nativo. Android requer SDK/emulador e iOS requer macOS/Xcode.

## Limitações
- QR: somente exibe conteúdo bruto, sem validar QR de mesa nem registrar pedidos.
- Mapa: sem provedor de tiles; não exibe cartografia completa, GPS ou rotas.
- Câmera exige permissões e contexto seguro; comportamento varia por plataforma.
- Sem autenticação, backend, pagamentos, pedidos ou dados reais.
- Versões e compatibilidade exigem testes e lockfile antes da homologação.
