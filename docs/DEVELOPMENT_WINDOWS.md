# Desenvolvimento local no Windows — planejamento

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
- Windows: prévia Flutter Web com dimensões de iPhone, Android e tablet; não é simulador iOS nativo.
- Emulador Android: requer Android SDK e configuração local.
- iOS Simulator e builds iOS/macOS nativos: requerem macOS/Xcode ou infraestrutura de build macOS aprovada.
- O laboratório deve usar dados fictícios e falhas simuladas; não pode apontar para produção.

## Política de ambiente
Local, testes, homologação e produção são segregados. Nenhum deploy, serviço pago ou acesso a dados reais é autorizado por este guia.
