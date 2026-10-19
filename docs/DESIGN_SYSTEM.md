# DESIGN_SYSTEM.md — GOGDELY v1.1

**Status:** direção visual Azul Elétrico + Grafite aprovada e aplicada aos protótipos locais. Complementa GOG-088; preserva o Documento Mestre e as decisões GOG-001 a GOG-141. As seções históricas abaixo indicam intenção inicial e as pendências de homologação.

## Paleta aprovada

| Token | Valor | Token | Valor |
| --- | --- | --- | --- |
| `brandPrimary` | `#2563EB` | `brandPrimaryHover` | `#1D4ED8` |
| `brandAccent` | `#60A5FA` | `brandGraphite` | `#151B2B` |
| `backgroundLight` | `#F2F5FF` | `backgroundDark` | `#101522` |
| `surfaceLight` | `#FFFFFF` | `surfaceDark` | `#253047` |
| `textPrimaryLight` | `#1E293B` | `textPrimaryDark` | `#F8FAFC` |
| `textSecondaryLight` | `#64748B` | `textSecondaryDark` | `#B8C4DC` |
| `borderLight` | `#DCE4F2` | `borderDark` | `#38455D` |

Verde não integra marca, botões, navegação, badges, progresso ou confirmações positivas. Erros usam vermelho; alertas, âmbar; informação e confirmações, azul, sempre com texto/ícone. Tipografia: display 32/700, título 24/700, título secundário 20/600, subtítulo 16/600, corpo 14–16/400, legenda 12/400. Espaçamento: 4, 8, 12, 16, 24, 32, 48 px. Botões principais: 52 px; campos: mínimo 48 px; cards: raio 16 px; modais: 20 px; botões de ação: 12 px.

`packages/design_system` centraliza o tema Flutter claro, escuro e automático. Cliente, Entregador e Gestão possuem protótipos locais navegáveis com dados fictícios e imagens originais. Inter será considerada somente após verificação de licença e compatibilidade; os protótipos usam a fonte nativa. O laboratório Cliente mostra iPhone, Android e tablet numa janela Windows, sem simular iOS nativo. Autenticação, mapa/GPS, pedidos, pagamentos, notificações e serviços de produção ainda não estão integrados. Acessibilidade completa e responsividade devem passar por validação visual e testes específicos antes da homologação.

### Ícones dos PWAs de homologação

- Cliente: motociclista original já usado no PWA.
- Entregador: motocicleta com caixa de entregas, em azul elétrico sobre grafite; fonte vetorial em `apps/entregador/web/icons/gogdely-entrega.svg`.
- Gestão: fachada de loja com cartão de pedido, na mesma família visual; fonte vetorial em `apps/gestao/web/icons/gogdely-lojas.svg`.
- Cada PWA tem PNGs 192/512, versões maskable, ícone Apple de 180 px e favicon próprio. Os ícones são desenhos vetoriais internos, sem nova dependência de runtime ou material de terceiros.

### Refinamento da prévia Gestão e Entregador — GOG-087/088/093

- As prévias publicáveis usam tema claro inicial, barra superior branca e fundo uniforme, inclusive nas metatags PWA, para eliminar a faixa com contraste gradual vista no iPhone. O tema escuro segue selecionável pelo usuário; validar a aparência em PWA já instalado no aparelho antes de homologar.
- Gestão compacta usa navegação inferior para Início, Pedidos, Cardápio e Financeiro; o menu lateral conserva os demais módulos. Indicadores se reorganizam em duas colunas no celular, com espaçamento próprio, e em quatro colunas no desktop. O gráfico de sete dias tem barras animadas, rótulos e seleção por toque.
- Cardápio hospedado apresenta catálogo ilustrativo com busca, categoria e detalhes do produto; a edição persiste somente no laboratório local. Nunca sugerir que a prévia online altera uma loja real.
- Financeiro separa **volume estimado de pedidos** de **valores recebidos**, mostra composição por forma pretendida de pagamento e o estado da conciliação. Sem provedor integrado, não há saldo, repasse ou extrato real. O filtro por canal afeta somente a composição exibida.
- Entregador prioriza leitura rápida: resumo da jornada, status, endereço, distância e ação de rota em cartões espaçados. Rotas e entregas da prévia hospedada continuam ilustrativas.
- Referências de princípios, sem reprodução de marca ou componentes: [Material 3 — app bars](https://m3.material.io/components/app-bars/), [Material 3 — papéis de superfície](https://m3.material.io/styles/color/the-color-system), [Carbon — dashboards](https://v10.carbondesignsystem.com/data-visualization/dashboards/) e [Stripe — distinção entre pagamentos e repasses](https://support.stripe.com/questions/stripe-reports). A marca e os componentes continuam próprios do GOGDELY.

## Princípios (GOG-087 a GOG-103)
- Moderno, minimalista, profissional; temas claro, escuro e automático.
- Paleta aprovada acima; identidade própria de cada estabelecimento dentro de estrutura comum.
- Cliente: navegação por categorias, localização, promoções e recomendações.
- Gestão: adaptativo para mouse, teclado e toque; KDS em cartões/lista.
- Entregador: mapa/lista alternáveis. Master: dashboard e módulos configuráveis.
- Acessibilidade avançada com testes automatizados e manuais; estrutura multilíngue, pt-BR inicial.
- Preferências por usuário, empresa e função; notificações configuráveis.

## Tokens e componentes em evolução
- Cores semânticas adicionais: estados de erro, alerta e informação, superfície e texto.
- Espaçamentos: 4, 8, 12, 16, 24, 32, 48 px.
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
Licença e compatibilidade da Inter, iconografia, breakpoints, animações, limites de personalização, componentes restantes e métricas de acessibilidade por plataforma.
