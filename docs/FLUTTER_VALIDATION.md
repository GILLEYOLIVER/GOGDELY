# Validação local Flutter Cliente — Windows

**Estado:** scripts adicionados para execução pelo proprietário ou CI autorizado; não executados neste ambiente. Não representa homologação.

## Pré-requisitos
- Flutter SDK compatível com o pubspec, Dart e VS Code com extensões Flutter/Dart.
- Git e Android SDK caso deseje emulador Android.
- Chrome instalado para laboratório Flutter Web.
- Ambiente sem acesso a produção; não inserir credenciais reais.

## Primeira preparação
1. Clonar a branch de trabalho e garantir `git status` limpo.
2. Executar `flutter doctor` e corrigir problemas de instalação.
3. Na raiz do repositório, executar:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/setup_cliente_windows.ps1
   ```
4. O script gera scaffolding Android/Web **sem sobrescrever arquivos existentes**, resolve dependências, executa análise estática e testes.
5. Inspecionar `git diff`, especialmente arquivos nativos e `pubspec.lock`, antes de qualquer commit.
6. Abrir VS Code, selecionar **GOGDELY Cliente • Laboratório (Chrome)** e pressionar F5.

## Verificações subsequentes
```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_cliente_windows.ps1
```

## Critérios para aprovação
- `flutter pub get`, `flutter analyze` e `flutter test` concluídos sem erro, com logs anexados ao PR.
- Laboratório abre em Chrome; troca iPhone/Android/tablet, gira e exibe cenários sem exceções.
- QR solicita câmera apenas após permissão; não aceita dados como pedidos reais.
- Mapas sem tiles são identificados como demonstração; provedor, atribuição e custos continuam pendentes.
- Dependências resolvidas e transitivas auditadas quanto a licença e vulnerabilidades.
- Android testado em emulador/dispositivo; iOS será validado posteriormente em macOS/Xcode.

## Limites
- A execução de `flutter pub get` pode acessar o registro de pacotes para obter dependências, sem contratação.
- Nenhuma GitHub Action foi ativada: execução automática em repositório privado pode consumir minutos faturáveis.
- Não executar scripts em máquina que contenha dados de produção sem revisão e autorização.
