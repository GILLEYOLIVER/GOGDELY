# GOGDELY Entregador
Protótipo Flutter local para Android e Windows, com prévia web no celular. Com `GOGDELY_LOCAL_API=true`, Entregas consulta a API local a cada 3 segundos enquanto a tela está aberta, mostrando pedidos de entrega encaminhados pelas lojas fictícias. O entregador abre uma rota ilustrativa e os itens do pedido, inicia a entrega e conclui com o código de seis dígitos do Cliente. Sem essa opção, usa somente dados em memória. Não acessa GPS, pedidos reais ou produção.

Com o PWA local ativo, abra `https://192.168.137.1:8767/entregador/` no celular conectado ao hotspot do computador. É uma prévia web do fluxo Flutter, sem navegação externa ou rastreamento. O app Android/iOS ainda requer compilação e homologação nativas.

No VS Code, abra a raiz `C:\Projetos\GOGDELY`, selecione `GOGDELY Entregador • Windows` em Executar e Depurar e pressione F5. Também é possível abrir somente `apps/entregador`; o arquivo `.vscode/launch.json` dessa pasta oferece o mesmo F5. Para abrir os três apps rapidamente com a API local, use `GOGDELY • Cliente + Gestão + Entregador (F5)` na raiz.
