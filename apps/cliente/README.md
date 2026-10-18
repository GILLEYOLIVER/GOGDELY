# GOGDELY Cliente — laboratório de dispositivos

**Status:** protótipo local em revisão, sem integração com produção.

## Primeira jornada de marketplace (GOG-016/017/018/090/091)
Na prévia, o Cliente apresenta categorias, busca, produtos, carrinho, checkout demonstrativo, acompanhamento, pedidos, avaliação, perfil, notificações, endereço, login e onboarding. Com `GOGDELY_LOCAL_API=true`, dez estabelecimentos fictícios e seus cardápios vêm da API/SQLite local; o checkout grava pedidos de uma loja por vez e acompanhamento e histórico consultam novos status automaticamente a cada 3 segundos enquanto essas telas estão abertas. Sem essa opção, a prévia visual antiga continua em memória. Não há cadastro, localização, disponibilidade, autenticação ou pagamento reais.

### Referências visuais do Cliente (GOG-015/016/017/018/087/090/091, parcial)

As 25 capturas fornecidas em 14/10/2026 orientam a hierarquia e a navegação: cabeçalho com endereço, trilho de categorias, destaques horizontais, filtros e ordenação, lista de lojas, cardápio, seleção de tamanho e adicionais, sacola, revisão e formulário de endereço. A identidade aprovada do GOGDELY usa azul elétrico e grafite. As imagens e marcas de terceiros não fazem parte do aplicativo. As ações principais de produto, sacola, revisão e endereço ficam fixas na borda inferior. A aba Ofertas mostra somente produtos com promoção cadastrada no catálogo atual; o filtro de ofertas e a ordenação operam apenas sobre as lojas carregadas. No PWA, o endereço digitado e os IDs das lojas favoritas ficam no armazenamento local do navegador e reaparecem ao abrir o mesmo endereço; não há conta nem sincronização entre aparelhos. O endereço é usado no pedido local e não é geocodificado. O ponto do mapa e o GPS não são armazenados. Cupons, pagamentos externos, frete promocional e rastreamento real seguem pendentes.

Os cinco vídeos enviados em 16/10/2026 também orientaram a organização das telas e as transições. A entrada animada, o entregador de moto, o ícone do aplicativo e os destaques são criações do GOGDELY. A abertura pode ser pulada e respeita a preferência de movimento reduzido. O fluxo da sacola apresenta uma revisão antes de gravar o pedido local. Detalhes e limites: [experiência visual](../../docs/CLIENT_EXPERIENCE.md).

## VS Code no Windows
1. Instalar Flutter SDK, extensões Dart/Flutter e as ferramentas C++ para aplicativos Flutter Windows.
2. No terminal, dentro de `apps/cliente`, executar `flutter pub get`.
3. Abrir a raiz do repositório no VS Code, selecionar **GOGDELY • Cliente + Gestão + Entregador (F5)** e pressionar **F5**. Para abrir só o Cliente, selecione **GOGDELY Cliente • somente esta janela** ou abra apenas `apps/cliente` no VS Code.
4. Selecionar iPhone, Android ou tablet; alternar orientação, notificações fictícias, pedido fictício e indicador de rede.

Esta execução Windows é somente um laboratório local para visualizar o Cliente. O produto Cliente continua destinado a Android/iOS. Para iniciar sem VS Code: `flutter run -d windows --dart-define=GOGDELY_LAB=true` dentro de `apps/cliente`.

O modo laboratório usa `--dart-define=GOGDELY_LAB=true` e aparece na prévia Windows ou Flutter Web. Os controles de offline **não desligam a conexão real**; simulam apenas indicadores visuais. Para testar persistência com os outros aplicativos, use o perfil conjunto de F5 na raiz; ele inicia a API local e os três aplicativos com `GOGDELY_LOCAL_API=true`.

## PWA local no celular (GOG-007/015/090/091 parcial)

No Windows, abra **Iniciar GOGDELY PWA.cmd** na área de trabalho. O atalho liga o hotspot móvel, recompila Cliente e prévia web do Entregador e sobe API SQLite no mesmo HTTPS. Conecte o celular à rede anunciada pelo hotspot; veja o nome e a senha em **Configurações > Rede e Internet > Hotspot móvel**. O terminal mostra os links exatos do Cliente e do Entregador, que podem mudar conforme o IP atribuído ao hotspot. Para usar uma rede Wi-Fi existente, execute `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/start-local-pwa.ps1` na raiz do repositório, sem `-UseHotspot`.

Na primeira abertura pelo iPhone, instale o certificado de teste pelo endereço `http://IP:8768/GOGDELY-Local-CA.cer` mostrado no terminal. Em **Ajustes > Perfil Baixado**, instale o perfil; depois em **Ajustes > Geral > Sobre > Ajustes de Confiança de Certificados**, habilite confiança total para **GOGDELY Local Test CA**. Abra o link HTTPS no Safari, use **Compartilhar > Adicionar à Tela de Início** e abra o ícone GOGDELY. O certificado é exclusivo deste laboratório, gerado em `.local/pwa`; nunca compartilhe a chave `.key`. Em outros celulares, instale/confie no certificado conforme o sistema permitir antes de instalar o PWA.

Se o Windows bloquear o acesso pelo celular, execute **Liberar acesso GOGDELY PWA.cmd** e aceite a solicitação de administrador. A regra autoriza apenas as portas 8767/8768 no IP privado e na sub-rede local e é removida quando o servidor encerra. O acesso depende do computador ligado. **Encerrar GOGDELY PWA.cmd** encerra somente os processos deste PWA. O servidor e as encomendas do piloto não têm login de produção; use apenas rede privada confiável e dados fictícios. Não há publicação na internet. Alterações no código exigem executar o atalho novamente para atualizar o build.

Para separar falha de rede de falha de HTTPS, abra `http://IP:8768/` diretamente no Safari, usando o mesmo IP mostrado pelo terminal. A página simples “Rede GOGDELY conectada” confirma que o celular alcança o computador sem carregar o Flutter. Se ela não abrir, confira se o telefone está conectado ao SSID do hotspot ou à mesma rede Wi-Fi do computador antes de tentar o PWA.

Depois de um novo build, o servidor local exige a revalidação dos arquivos do PWA. O Cliente consulta a versão ao abrir, ao voltar do segundo plano e enquanto estiver visível; se a versão mudar, recarrega uma vez. Isso depende de rede e do mesmo endereço do PWA. Uma instalação antiga, anterior a esta checagem, pode exigir uma atualização manual inicial. Se o IP mudar, o ícone instalado com o IP antigo não muda de endereço: apague os atalhos antigos do iPhone, abra o endereço atual no Safari e use **Compartilhar > Adicionar à Tela de Início**. A instalação atual aparece como **GOGDELY Local** com o ícone da moto; o manifesto tem identidade e endereço inicial próprios para evitar reaproveitar o antigo ícone “G”. Além do ícone no manifesto, o build fornece `apple-touch-icon.png` e `apple-touch-icon-precomposed.png` na raiz para o iPhone. O service worker gerado pelo Flutter atual é apenas um limpador de caches antigos, não oferece operação offline do PWA.

As duas prévias web compartilham origem com a API para evitar URL fixa do computador. O servidor estático só é montado quando `GOGDELY_LOCAL_PWA_DIR` é definido em ambiente local com demo SQLite. O modo padrão F5 e os demais aplicativos permanecem independentes. A prévia do Entregador não substitui a homologação do app Android/iOS.

## Dados fictícios para teste

O catálogo SQLite é preenchido automaticamente com dez lojas e 31 produtos na primeira consulta, sem substituir alterações já salvas no cardápio. Para criar uma amostra de pedidos em diferentes estágios, execute `services/api/.venv/Scripts/python.exe scripts/seed-local-demo.py` na raiz. O script cria um backup consistente em `services/api/.local/backups` antes da carga e usa chaves fixas para não duplicar os pedidos em execuções posteriores. A amostra contém somente nomes, endereços e valores fictícios; não processa pagamentos. Em 14/10/2026, dez amostras foram carregadas no banco local do computador.

## Testes
Executar `flutter analyze`, `flutter test` e `flutter test --dart-define=GOGDELY_LOCAL_API=true` antes de revisão. Os testes cobrem navegação, busca, seleção de produto, sacola, ofertas, ordenação, formulário de endereço e controles do laboratório. Homologação em dispositivo real ainda é necessária.

## Dependências de terceiros
O protótipo usa componentes do Flutter e preserva as dependências open source [`flutter_map`](https://github.com/fleaflet/flutter_map) e [`mobile_scanner`](https://github.com/juliansteenbakker/mobile_scanner). Não foi copiado código-fonte de aplicativos prontos. QR Code apenas exibe conteúdo lido, sem validar mesa. O mapa usa tiles OpenStreetMap com lojas fictícias; a posição do celular é solicitada somente após toque, sem converter coordenadas em endereço ou calcular rota. A tela de pagamento grava a forma pretendida e permite registrar uma simulação explícita no banco local, sem cobrança. A foto do açaí da Wikimedia Commons e os avisos de licença estão em `docs/THIRD_PARTY_NOTICES.md`; dependências transitivas e distribuição ainda requerem revisão.

**Limitação:** Chrome com moldura de iPhone não é simulador iOS nativo. Builds iOS requerem macOS/Xcode.
