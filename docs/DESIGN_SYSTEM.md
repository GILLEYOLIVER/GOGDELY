# DESIGN_SYSTEM.md — GOGDELY v0.1

**Status:** diretrizes aprovadas; identidade visual e tokens concretos pendentes. Não confundir exemplos com identidade definitiva.

## Princípios (GOG-087 a GOG-103)
- Moderno, minimalista, profissional; temas claro, escuro e automático.
- Paleta exclusiva ainda a definir; identidade própria de cada estabelecimento dentro de estrutura comum.
- Cliente: navegação por categorias, localização, promoções e recomendações.
- Gestão: adaptativo para mouse, teclado e toque; KDS em cartões/lista.
- Entregador: mapa/lista alternáveis. Master: dashboard e módulos configuráveis.
- Acessibilidade avançada com testes automatizados e manuais; estrutura multilíngue, pt-BR inicial.
- Preferências por usuário, empresa e função; notificações configuráveis.

## Tokens a especificar (sem valores definitivos)
- Cores: brand.primary/onPrimary/secondary, surface.default/raised, text.primary/secondary, status.success/warning/error/info.
- Espaçamentos: 4, 8, 12, 16, 24, 32 (proposta sujeita a aprovação).
- Raios: sm/md/lg/xl; tipografia: body/label/title/display; movimento: fast/normal/reduced.
- Contraste e feedback nunca dependentes apenas de cor.

## Componentes planejados
Botões, campos, busca, filtros, cards de loja/produto, carrinho, cupom, timeline de pedido, QR mesa, mapa, KDS, impressão, tabelas, modais de confirmação, estados vazio/carregando/erro/offline/sincronizando.

## Regras por aplicativo
- Cliente Android/iOS: checkout acessível, endereço, preço e taxas claros, status e rastreamento.
- Gestão Windows/macOS: navegação por teclado, densidade ajustável, estado de impressão e fila offline visíveis.
- Entregador Android/iOS: ações grandes, foco em segurança, localização somente durante finalidade autorizada.
- Master multiplataforma: confirmação reforçada e trilha de auditoria para ações críticas.

## Simulação
VS Code F5: prévia responsiva de iPhone/Android/tablet no Windows; laboratório com pedidos fictícios, notificações e offline. iOS Simulator nativo requer macOS. Nunca conectar laboratório a produção.

## Acessibilidade e aceite
Usar WCAG 2.2 AA como referência onde aplicável; validar leitores de tela, teclado, foco, escala de texto, contraste, alto zoom, tema escuro e redução de movimento. Homologação requer protótipos aprovados, tokens definidos, testes e evidências.

## Pendências
Paleta, logo, tipografia e licença, iconografia, breakpoints, animações, limites de personalização, componentes implementados e métricas de acessibilidade por plataforma.
