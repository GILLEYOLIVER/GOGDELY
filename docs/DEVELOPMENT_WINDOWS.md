# Desenvolvimento local no Windows — planejamento

## Atalho F5 no VS Code

Abra `C:\Projetos\GOGDELY` no VS Code. Em **Executar e Depurar**, selecione **GOGDELY • Cliente + Gestão + Entregador (F5)** e pressione **F5**. A API local inicia primeiro; Gestão e Entregador abrem pelos executáveis Windows compilados e atualizados quando o código muda; depois o VS Code abre o Cliente com depuração. Após a primeira compilação, os próximos F5 reutilizam os executáveis, reduzindo a espera. Ao parar a depuração, as janelas e a API iniciadas por esse F5 são encerradas. Aplicativos ou API que já estavam abertos não são encerrados. Quando o código mudar, o F5 fecha e recompila as janelas que ele mesmo iniciou; uma janela aberta manualmente precisa ser fechada antes. Os três apps consultam automaticamente a API local a cada 3 segundos nas telas de pedidos relevantes para mostrar alterações de status salvas em `services/api/.local/gogdely.sqlite3`. Os botões de atualização manual continuam disponíveis.

Cada app tem seu ponto de entrada `lib/main.dart`. Se abrir somente `apps/cliente`, `apps/entregador` ou `apps/gestao` no VS Code, o `launch.json` daquela pasta permite iniciar o aplicativo individualmente com **F5**. Na raiz, os perfis individuais também estão disponíveis. A API deve estar ativa para os botões que salvam ou leem pedidos locais.

No modo de demonstração local, **Burger House é a única empresa piloto exibida** no Cliente e consultada por Gestão e Entregador. Os dados fictícios já salvos das outras lojas permanecem no SQLite, mas não aparecem nesse fluxo. O filtro por `store_id` serve apenas ao piloto local: ainda não há login, autorização por empresa ou isolamento multiempresa de produção.


**Estado:** instruções preparatórias; nenhum ambiente ou dependência instalado automaticamente.

## Ferramentas previstas
Git, VS Code, Flutter SDK/Dart, Python 3, PostgreSQL local ou instância de teste aprovada. Versões serão fixadas após teste de compatibilidade e revisão técnica. Extensões sugeridas estão em `.vscode/extensions.json`.

## Ordem de implantação local (após aprovação da implementação)
1. Clonar repositório privado e trabalhar em `feature/*` criada de `develop`.
2. Verificar Flutter/Dart, Python e ferramentas de build Windows.
3. Criar arquivos `.env` locais a partir de exemplos aprovados, nunca versionar credenciais.
4. Instalar dependências dos apps e backend somente após aprovação dos manifests e lockfiles.
5. Executar testes de contratos, multiempresa e fluxos críticos antes de iniciar serviços locais.

## Prévia de dispositivos
- Windows: laboratório local em janela Flutter Windows com dimensões de iPhone, Android e tablet; requer ferramentas C++ do Visual Studio. Não é simulador iOS nativo nem uma versão Windows do produto Cliente.
- Emulador Android: requer Android SDK e configuração local.
- iOS Simulator e builds iOS/macOS nativos: requerem macOS/Xcode ou infraestrutura de build macOS aprovada.
- O laboratório deve usar dados fictícios e falhas simuladas; não pode apontar para produção.

## Política de ambiente
Local, testes, homologação e produção são segregados. Nenhum deploy, serviço pago ou acesso a dados reais é autorizado por este guia.
