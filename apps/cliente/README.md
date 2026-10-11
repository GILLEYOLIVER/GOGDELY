# GOGDELY Cliente — laboratório de dispositivos

**Status:** protótipo em revisão, sem integração com produção.

## VS Code no Windows
1. Instalar Flutter SDK e extensões Dart/Flutter.
2. No terminal, dentro de `apps/cliente`, executar `flutter pub get`.
3. Se o projeto não tiver scaffolding Flutter nativo completo, executar `flutter create --platforms=android,ios,web .` e revisar arquivos gerados.
4. Abrir o repositório no VS Code, selecionar **GOGDELY Cliente • Laboratório (Chrome)** e pressionar **F5**.
5. Selecionar iPhone, Android ou tablet; alternar orientação, notificações fictícias, pedido fictício e indicador de rede.

O modo laboratório usa `--dart-define=GOGDELY_LAB=true` e só aparece no Flutter Web. Os controles de offline **não desligam a conexão real**; simulam apenas indicadores visuais. O estado do pedido não é persistido nem enviado à API.

## Testes
`flutter analyze` e `flutter test` devem ser executados antes de homologação. Ainda não foram executados neste ambiente.

## Dependências de terceiros
`flutter_map` e `mobile_scanner` são declarados no pubspec; licenças e compatibilidade exigem revisão. QR Code apenas exibe conteúdo lido, não valida mesa. Mapa demonstrativo não tem provedor de tiles nem GPS.

**Limitação:** Chrome com moldura de iPhone não é simulador iOS nativo. Builds iOS requerem macOS/Xcode.
