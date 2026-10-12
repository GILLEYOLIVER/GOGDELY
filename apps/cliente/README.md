# GOGDELY Cliente — laboratório de dispositivos

**Status:** protótipo local em revisão, sem integração com produção.

## Primeira jornada de marketplace (GOG-016/017/018/090/091)
Na prévia, o Cliente apresenta categorias, busca, produtos, carrinho, checkout demonstrativo, acompanhamento, pedidos, avaliação, perfil, notificações, endereço, login e onboarding. Com `GOGDELY_LOCAL_API=true`, somente Burger House aparece como empresa piloto; o checkout grava pedidos fictícios na API/SQLite local e acompanhamento e histórico consultam novos status automaticamente a cada 3 segundos enquanto essas telas estão abertas. Sem essa opção, a prévia visual antiga continua em memória com outras lojas fictícias. Não há cadastro, localização, disponibilidade, autenticação ou pagamento reais.

## VS Code no Windows
1. Instalar Flutter SDK, extensões Dart/Flutter e as ferramentas C++ para aplicativos Flutter Windows.
2. No terminal, dentro de `apps/cliente`, executar `flutter pub get`.
3. Abrir a raiz do repositório no VS Code, selecionar **GOGDELY • Cliente + Gestão + Entregador (F5)** e pressionar **F5**. Para abrir só o Cliente, selecione **GOGDELY Cliente • somente esta janela** ou abra apenas `apps/cliente` no VS Code.
4. Selecionar iPhone, Android ou tablet; alternar orientação, notificações fictícias, pedido fictício e indicador de rede.

Esta execução Windows é somente um laboratório local para visualizar o Cliente. O produto Cliente continua destinado a Android/iOS. Para iniciar sem VS Code: `flutter run -d windows --dart-define=GOGDELY_LAB=true` dentro de `apps/cliente`.

O modo laboratório usa `--dart-define=GOGDELY_LAB=true` e aparece na prévia Windows ou Flutter Web. Os controles de offline **não desligam a conexão real**; simulam apenas indicadores visuais. Para testar persistência com os outros aplicativos, use o perfil conjunto de F5 na raiz; ele inicia a API local e os três aplicativos com `GOGDELY_LOCAL_API=true`.

## Testes
Executar `flutter analyze` e `flutter test` antes de revisão. Os testes cobrem busca, carrinho de uma loja e controles do laboratório; homologação em dispositivo real ainda é necessária.

## Dependências de terceiros
O protótipo usa componentes do Flutter e preserva as integrações open source [`flutter_map`](https://github.com/fleaflet/flutter_map) e [`mobile_scanner`](https://github.com/juliansteenbakker/mobile_scanner). Não foi copiado código-fonte de aplicativos prontos. QR Code apenas exibe conteúdo lido, sem validar mesa. Mapa demonstrativo não tem provedor de tiles nem GPS. Licenças das versões resolvidas estão registradas em `docs/THIRD_PARTY_NOTICES.md`; dependências transitivas e distribuição ainda requerem revisão.

**Limitação:** Chrome com moldura de iPhone não é simulador iOS nativo. Builds iOS requerem macOS/Xcode.
