# Checklist do Documento Mestre v1.0 — GOGDELY

**Atualizado em:** 12/10/2026. **Fonte:** [Documento Mestre](MASTER_PLAN.md) e [decisões GOG-001 a GOG-141](DECISIONS.md).

Este checklist controla a conclusão de cada decisão sem alterar o texto aprovado. **[x]** significa que o escopo exato daquela decisão está demonstrado pela evidência indicada; não significa que o produto inteiro esteja homologado. **[ ]** significa pendente ou parcial. **N/A** é um registro sem ação de implementação. Uma funcionalidade ampla só recebe baixa após testes aplicáveis, evidências, documentação, revisão de segurança e aprovação operacional, conforme o Documento Mestre. O ambiente local fictício não comprova produção.

## Marcos do piloto Burger House no laboratório local

- [x] Três protótipos Flutter disponíveis no repositório: Cliente, Gestão e Entregador. Evidência: [apps/cliente](../apps/cliente), [apps/gestao](../apps/gestao), [apps/entregador](../apps/entregador). **Estado: código local; sem homologação de plataformas.**
- [x] Perfil F5 e prévia Cliente em iPhone, Android e tablet no Windows. Evidência: [.vscode/launch.json](../.vscode/launch.json) e [laboratório](../apps/cliente/lib/lab/device_lab.dart). **É uma prévia responsiva, não o Simulator iOS nativo.**
- [x] Fluxo fictício de pedido gravado em SQLite local e lido pelos três apps, com transições de status e atualização periódica na interface. Evidência: [API local](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [Gestão](../apps/gestao/lib/main.dart), [Entregador](../apps/entregador/lib/main.dart). **Não há pagamento, credencial real ou integração de produção.**
- [x] Burger House selecionada como única empresa visível no modo de demonstração local; pedidos das demais lojas não foram apagados. Evidência: [configuração local](../packages/local_demo_api/lib/gogdely_local_demo_api.dart) e consultas dos aplicativos. **Isso ainda não é isolamento multiempresa com login, tenant_id e RLS.**
- [x] Edição local básica do cardápio Burger House: cadastrar/editar produto, categoria, descrição, preço, promoção percentual, disponibilidade e referência de imagem; a API salva no SQLite, usa o preço salvo no pedido e o Cliente atualiza a vitrine. Evidência: [API](../services/api/gogdely_api/local_orders.py), [editor da Gestão](../apps/gestao/lib/menu_editor.dart), [Cliente](../apps/cliente/lib/screens/home_screen.dart) e [teste focado](../services/api/tests/test_local_orders.py).
- [x] Foto do computador e adicionais com preços por produto no piloto local: Gestão envia PNG/JPEG/WebP (até 5 MB) ao armazenamento local; Cliente e cardápio HTML mostram a foto e os adicionais; a API valida opções e calcula os preços salvos. Evidência: [API](../services/api/gogdely_api/local_orders.py), [editor](../apps/gestao/lib/menu_editor.dart), [Cliente](../apps/cliente/lib/screens/home_screen.dart) e [testes](../services/api/tests/test_local_orders.py). **Verificação técnica:** 4 testes focados da API e análise Dart de Cliente/Gestão, em 12/10/2026. **Pendente:** teste visual do seletor de arquivos e permissões por funcionário.
- [ ] Cardápio Burger House editável na Gestão, com produtos, categorias, fotos, preços, adicionais, disponibilidade e promoções; alterações persistidas e exibidas ao Cliente.
- [x] Página web local do cardápio por mesa e ficha com QR para impressão (M01–M10). O pedido fica no SQLite com mesa, número, data/hora e sem frete; aparece em Pedidos/KDS da Gestão e pode ser marcado como servido. O Entregador não recebe pedidos de mesa. Evidência: [API e HTML](../services/api/gogdely_api/local_orders.py), [Mesas QR na Gestão](../apps/gestao/lib/table_qr_page.dart), [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica:** 4 testes da API e análise Dart de Gestão/Entregador, em 12/10/2026. **Limite:** o servidor F5 escuta somente no computador; acesso pelo celular via rede e teste visual ainda pendentes.
- [ ] QR por mesa abre cardápio no navegador sem instalar app e envia pedido com mesa, número, data e hora para a fila/KDS.
- [ ] Fluxo completo da empresa piloto: pedido, preparo, retirada/entrega, pagamento simulado de forma explícita, histórico, cancelamento e auditoria.
- [x] Histórico de mudanças de status e cancelamento com motivo no SQLite local: Cliente cancela antes do preparo; Gestão cancela até o preparo. O histórico é consultável nos dois apps e pedidos anteriores sem eventos não recebem registros inventados. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [Gestão](../apps/gestao/lib/main.dart), [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 5 testes da API; análise Dart dos arquivos alterados de Cliente e Gestão sem erros. **Pendente:** autenticação/permissões reais, estorno/pagamento e teste visual do proprietário.
- [x] Retirada na Burger House no piloto local: Cliente escolhe entrega ou retirada; a retirada é salva sem frete, passa por preparo/pronto/retirado na Gestão e fica fora da fila do Entregador. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [Gestão](../apps/gestao/lib/main.dart), [Entregador](../apps/entregador/lib/main.dart), [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 6 testes da API; análise Dart dos arquivos alterados dos três apps sem erros. **Pendente:** teste visual do proprietário, endereço/horário real de retirada e autenticação.
- [x] Forma de pagamento pretendida salva no pedido local: Cliente escolhe dinheiro, Pix ou cartão; API persiste somente a opção e informa `not_processed`; Gestão mostra a escolha e informa que não houve processamento. Pedidos antigos recebem `unselected`, sem inventar pagamento. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [Gestão](../apps/gestao/lib/main.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Pendente:** integração de provedor, confirmação financeira, permissões e teste visual. GOG-019/GOG-055 continuam parciais.
- [x] Configuração local das formas de pagamento da Burger House: Gestão ativa/desativa dinheiro, Pix e cartão, mantendo ao menos uma opção; Cliente atualiza as opções no checkout; API rejeita opções desativadas e preserva a configuração no SQLite. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Gestão](../apps/gestao/lib/main.dart), [Cliente](../apps/cliente/lib/screens/home_screen.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 7 testes da API; análise Dart dos arquivos alterados de Cliente e Gestão sem erros. **Pendente:** autenticação, controle por empresa/filial em produção, cobrança real e teste visual. GOG-019/GOG-055 permanecem parciais.
- [x] Conferência local da retirada: pedidos de retirada recebem código de seis dígitos persistido; o Cliente o visualiza e a Gestão precisa digitá-lo para marcar `picked_up`. Código ausente/incorreto não conclui o pedido; pedidos antigos de retirada recebem código sem apagar dados. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [Gestão](../apps/gestao/lib/main.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 7 testes da API; análise Dart dos arquivos alterados de Cliente e Gestão sem erros. **Limite:** código de conferência do laboratório, sem autenticação/identificação real ou garantia de segurança.
- [x] Ordem editável dos produtos da Burger House: Gestão move produtos para cima/baixo; API valida a lista completa e persiste a posição; Cliente recebe a ordem pelo cardápio local. Evidência: [API](../services/api/gogdely_api/local_orders.py), [editor](../apps/gestao/lib/menu_editor.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** teste focado da ordenação e análise Dart do editor sem erros. **Pendente:** teste visual do proprietário e controles de acesso; o marco amplo do cardápio continua aberto.
- [x] Resumo detalhado do pedido local no Cliente: itens, quantidades, tamanho, adicionais, subtotal, frete, total e forma de pagamento pretendida vêm do pedido salvo na API. Evidência: [modelo compartilhado](../packages/local_demo_api/lib/gogdely_local_demo_api.dart) e [acompanhamento](../apps/cliente/lib/screens/home_screen.dart). **Verificação técnica em 12/10/2026:** análise Dart do arquivo alterado sem erros. **Pendente:** teste visual do proprietário e comprovante fiscal/financeiro real.
- [x] Painel operacional local da Gestão com contagens por status, soma estimada sem cancelados e dez pedidos recentes; KDS mostra apenas pedidos novos, em preparo ou prontos, na ordem de chegada. Evidência: [Gestão](../apps/gestao/lib/main.dart). **Verificação técnica em 12/10/2026:** análise Dart do arquivo alterado sem erros. **Limites:** consulta dos últimos 100 pedidos do SQLite, sem faturamento recebido ou teste visual.
- [x] Encaminhamento local para entregador próprio: pedido de entrega novo fica aguardando ação da Gestão após o preparo; só então aparece no Entregador e pode avançar para “Em entrega”. O encaminhamento é registrado no histórico e pedidos antigos preservam o fluxo anterior. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Gestão](../apps/gestao/lib/main.dart), [Entregador](../apps/entregador/lib/main.dart), [Cliente](../apps/cliente/lib/screens/home_screen.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica:** 7 testes focados da API e análise Dart dos arquivos alterados dos três apps sem erros. **Pendente:** atribuição a pessoa autenticada, parceiro externo, GPS e teste visual.
- [x] Conferência local da entrega: pedidos de entrega recebem código de seis dígitos persistido; o Cliente vê o código durante a rota e o Entregador deve digitá-lo para concluir. A API rejeita código ausente/incorreto e gera código para entregas antigas ainda abertas. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [Entregador](../apps/entregador/lib/main.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 7 testes da API e análise Dart de Cliente/Entregador sem erros. **Limites:** sem autenticação ou sigilo do código na API local, sem prova de identidade, localização ou entrega física; teste visual do proprietário pendente.
- [x] Histórico local de alterações do cardápio Burger House: criação, edição de campos e mudança de posição registram antes/depois no SQLite; a Gestão mostra os últimos 50 eventos no botão **Histórico**. Produtos existentes antes deste recurso permanecem sem eventos retroativos. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Gestão](../apps/gestao/lib/menu_editor.dart), [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 7 testes da API e análise Flutter da Gestão sem erros. **Limites:** ator fixo “Gestão local”, sem autenticação, autorização ou auditoria imutável; GOG-038 continua pendente e o teste visual é do proprietário.
- [x] Primeira etapa local de GOG-035: a Gestão configura saldo opcional por produto da Burger House e vê os saldos reais na página **Estoque**; pedidos de entrega, retirada e mesa usam a mesma reserva atômica no SQLite, rejeitam falta de saldo e cancelamentos elegíveis repõem apenas unidades efetivamente baixadas. Pedidos antigos e produtos sem saldo configurado permanecem ilimitados; baixa/reposição entram no histórico local. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Estoque](../apps/gestao/lib/stock_page.dart), [editor](../apps/gestao/lib/menu_editor.dart), [Cliente](../apps/cliente/lib/screens/home_screen.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 8 testes da API; análise Flutter de Gestão e Cliente sem erros. **GOG-035 continua parcial.**
- [x] Ficha técnica simples do piloto GOG-035: a Gestão cadastra ingredientes com unidade (`un`, `g`, `ml`) e saldo; no Cardápio vincula quantidades consumidas por unidade vendida. Pedidos de entrega, retirada e mesa reservam produto e ingredientes na mesma transação; falta de qualquer insumo desfaz toda a reserva e oculta o produto no Cliente e no QR. Cancelamento permitido repõe somente os ingredientes reservados pelo pedido. Produtos anteriores permanecem sem receita até edição explícita. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Estoque](../apps/gestao/lib/stock_page.dart), [editor](../apps/gestao/lib/menu_editor.dart), [Cliente](../apps/cliente/lib/screens/home_screen.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 9 testes da API e análise Flutter de Gestão e Cliente sem erros. **GOG-035 continua parcial.**
- [x] Movimentos locais de estoque do piloto GOG-035: Gestão registra entrada, perda e contagem com motivo para produtos controlados e ingredientes; produtos sem limite podem começar pela contagem. Baixas de pedidos e reposições de cancelamento também ficam no histórico com número do pedido. A API rejeita saldo negativo e não inventa movimentos para dados anteriores à criação do histórico. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Estoque](../apps/gestao/lib/stock_page.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 10 testes da API; análise Flutter da Gestão. **GOG-035 continua parcial:** faltam conferência física, conversão de unidades, compras/custos, permissões e teste visual do proprietário.
- [x] Primeira etapa local de GOG-036: PDV da Gestão cria pedido de balcão Burger House pelo cardápio salvo, com total e forma pretendida; a API reaproveita a transação de estoque e a idempotência dos pedidos. Pedidos aparecem em Pedidos/KDS, avançam por preparo/pronto/entregue no balcão e não acionam Entregador. O pagamento continua explicitamente `not_processed`. Evidência: [API](../services/api/gogdely_api/local_orders.py), [PDV](../apps/gestao/lib/pos_page.dart), [Gestão](../apps/gestao/lib/main.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 11 testes focados da API e análise Flutter de Gestão e Cliente sem erros. A segunda etapa de GOG-036, abaixo, amplia o caixa local; a decisão GOG-036 permanece parcial.
- [x] Segunda etapa local de GOG-036: o PDV da Gestão declara abertura de caixa, suprimento, sangria e fechamento da Burger House, todos com motivo e registro no SQLite. Apenas uma sessão pode ficar aberta; o fechamento compara o dinheiro contado com o saldo esperado das declarações e preserva a diferença e o histórico recente. Os pedidos de balcão continuam com pagamento `not_processed` e não entram automaticamente no saldo. Evidência: [API](../services/api/gogdely_api/local_orders.py), [painel do caixa](../apps/gestao/lib/pos_register_panel.dart), [cliente da API](../packages/local_demo_api/lib/gogdely_local_demo_api.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 12 testes focados da API aprovados e análise Flutter da Gestão sem erros. **GOG-036 continua parcial:** faltam confirmação de recebimentos, conciliação financeira, permissões por operador e teste visual do proprietário.
- [x] Primeira etapa local de GOG-032: na fila KDS da Burger House, a Gestão pode marcar um pedido novo/em preparo como prioritário ou devolvê-lo à ordem normal, informando motivo. O SQLite preserva a prioridade e registra a mudança no histórico do pedido; o KDS mostra prioritários primeiro e mantém a ordem de chegada dentro de cada grupo. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Gestão](../apps/gestao/lib/main.dart), [modelo local](../packages/local_demo_api/lib/gogdely_local_demo_api.dart) e [teste focado](../services/api/tests/test_local_kds_priority.py). **Verificação técnica em 12/10/2026:** 1 teste focado da API aprovado e análise Flutter da Gestão sem erros. **GOG-032 continua parcial:** prioridade e ator são locais, sem autenticação, regras por setor, permissões ou teste visual do proprietário.
- [x] Pagamento simulado de forma explícita no piloto local: a Gestão registra, com motivo obrigatório, uma declaração de pagamento para pedidos não cancelados com forma escolhida; a API exige chave idempotente, grava em `demo_order_payments`, marca o pedido com `payment_status: "simulated"` e `payment_settlement: "simulated_local"` e lança evento no histórico sem alterar o status. Cliente e Gestão exibem a diferença entre pagamento não processado e simulado, sempre com aviso de que não houve cobrança real. Cancelados, sem método e repetições com chave nova são rejeitados. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Gestão](../apps/gestao/lib/main.dart), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [modelo local](../packages/local_demo_api/lib/gogdely_local_demo_api.dart) e [teste focado](../services/api/tests/test_local_orders.py). **Verificação técnica em 12/10/2026:** 21 testes da API aprovados; análise Flutter de Cliente, Gestão e Entregador sem erros; testes Flutter da Gestão aprovados. **GOG-055 continua parcial:** nenhum provedor é acionado; faltam confirmação financeira real, conciliação, estornos e permissões.
- [x] App Master multiplataforma no laboratório (GOG-010/096): login com MFA **simulado** exibido na tela, visão geral com empresas/pendências/volume estimado/pagamentos simulados/comissão estimada sobre produtos sem frete, cadastro de empresas com aprovação/recusa simulada e motivo auditado (GOG-025), catálogo fixo de planos (GOG-058 a GOG-062) e trilha de auditoria consolidada do SQLite (pedidos, cardápio, pagamentos simulados, estoque, caixa, aprovações). Evidência: [Master](../apps/master/lib/main.dart), [endpoints locais](../services/api/gogdely_api/master_local.py), [modelo](../packages/local_demo_api/lib/gogdely_local_demo_api.dart). **Verificação técnica em 13/10/2026:** importação da API e análise Flutter sem erros; suítes não executadas por instrução do proprietário, que fará o teste visual. **Limites:** sem autenticação, MFA real, tenant ou produção.
- [x] Empacotamento da API pronto para hospedagem futura (GOG-073/114): configuração por variáveis de ambiente (`config.py`), `Dockerfile`, modelo `render.yaml` (sem implantação), `.env.example` sem segredos e migration SQL versionada de referência (`0001_foundation.sql`) com `tenant_id`, RLS base e estados de pagamento separando simulação de confirmação por provedor. Evidência: [config](../services/api/gogdely_api/config.py), [Dockerfile](../services/api/Dockerfile), [render.yaml](../services/api/render.yaml), [migration](../database/migrations/0001_foundation.sql). **Nenhum deploy, conta ou serviço pago existe; homologação exige aprovação do proprietário.**
- [x] Avaliações locais de pedidos concluídos (GOG-022): o Cliente avalia 1–5 estrelas com comentário opcional após entregue/servido/retirado; a API grava uma avaliação por pedido em `demo_order_ratings`, registra evento no histórico e expõe média e contagem por loja; o Cliente mostra a média na página da loja e a Gestão acompanha a nota no dashboard. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [Gestão](../apps/gestao/lib/main.dart). **Verificação técnica em 13/10/2026:** importação da API e análise Flutter sem erros; suítes não executadas por instrução do proprietário. **Limite:** avaliação do laboratório, sem moderação ou antifraude.
- [x] Pedidos agendados no piloto local (GOG-024): o Cliente escolhe "Assim que possível" ou data/hora futura (mínimo 30 minutos, máximo 14 dias) no checkout; a API valida e persiste `scheduled_for`, grava evento de criação com o horário e o pedido carrega o agendamento para Cliente e Gestão. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [Gestão](../apps/gestao/lib/main.dart). **Verificação técnica em 13/10/2026:** importação da API e análise Flutter sem erros; suítes não executadas por instrução do proprietário. **Limite:** sem fila/separação por janela de horário nem regras por loja.
- [x] Notificações locais do Cliente (GOG-101/102): a página Notificações passa a derivar os eventos reais dos pedidos salvos no SQLite (status, pagamentos simulados, avaliações, encaminhamentos) e traz preferências por usuário (status/promoções) válidas apenas na prévia, sem push, e-mail ou SMS. Evidência: [Cliente](../apps/cliente/lib/screens/home_screen.dart). **Verificação técnica em 13/10/2026:** análise Flutter sem erros; suítes não executadas por instrução do proprietário. **GOG-101/102 continuam parciais:** canais reais e persistência de preferências pendentes.
- [x] Preparação SEO das páginas públicas (GOG-020/026/087): cardápios de mesa com slug público `/m/burger-house/{mesa}`, QR apontando ao slug, metadados completos (título, descrição, Open Graph, canonical e JSON-LD de cardápio), imagens com alt/dimensões/lazy loading, hierarquia com 1 h1, link interno recibo→cardápio, `robots.txt` e `sitemap.xml` dinâmicos, verificação Google Search Console por token, og-image 1200×630 da paleta aprovada e HTTPS obrigatório em produção com HSTS. Tudo permanece `noindex` no laboratório e páginas privadas (recibo, ficha, Master web) ficam `noindex` permanentes. Evidência: [web_seo.py](../services/api/gogdely_api/web_seo.py), [template](../services/api/gogdely_api/local_orders.py), [og-image](../scripts/generate_og_image.py), [docs/SEO.md](SEO.md), [testes](../services/api/tests/test_web_seo.py). **Verificação técnica em 13/10/2026:** 28 testes da API aprovados (7 novos de SEO). **Depende de configuração externa:** domínio público, token GSC, hospedagem e arte final da identidade (GOG-088).
- [x] Promoções da empresa piloto visíveis (GOG-021 parcial): endpoint `/stores/burger-house/promotions`, seção "Promoções da Burger House" na home do Cliente com "de/por" e % OFF, preço original riscado no card e na página do produto. O percentual e o preço efetivo continuam configurados pela Gestão no cardápio e calculados pela API no pedido. Evidência: [API](../services/api/gogdely_api/local_orders.py), [Cliente](../apps/cliente/lib/screens/home_screen.dart), [componentes](../apps/cliente/lib/screens/client_components.dart). **Verificação técnica em 13/10/2026:** 28 testes da API e 6 testes Flutter do Cliente aprovados; análise sem erros. **GOG-021 continua parcial:** sem promoções da plataforma, cupons com código ou campanhas programadas.
- [x] Cardápio do piloto agrupado por categorias da empresa (GOG-016 parcial): a página da loja do Cliente organiza os produtos por categoria em ordem de cadastro, atendendo à navegação por subcategorias da empresa; o modo fictício permanece inalterado. Evidência: [Cliente](../apps/cliente/lib/screens/home_screen.dart). **Verificação técnica em 13/10/2026:** análise Flutter sem erros; 6 testes do Cliente aprovados. **GOG-016 continua parcial:** categorias principais da plataforma e gestão de categorias na Gestão pendentes.
- [x] Endereço de entrega editável usado nos pedidos locais (GOG-015/018 parcial): a página "Onde você quer receber?" permite editar o endereço (mínimo 3 caracteres) e o valor é usado pelo checkout local nos pedidos de entrega; a API segue exigindo e gravando o endereço em cada pedido. Evidência: [Cliente](../apps/cliente/lib/screens/home_screen.dart), [API](../services/api/gogdely_api/local_orders.py). **Verificação técnica em 13/10/2026:** análise Flutter sem erros; testes do Cliente aprovados. **Limites:** sem geolocalização, geocodificação, GPS ou raio de entrega reais.
- [x] Relatórios locais na Gestão (GOG-084 parcial): a página Relatórios mostra métricas reais do SQLite — pedidos totais/ativos, volume estimado sem cancelados, ticket médio, pagamentos simulados, avaliação média, por canal (entrega/retirada/mesa/balcão) e por forma pretendida de pagamento — com atualização automática a cada 3 segundos e aviso de que não há faturamento recebido. Evidência: [Gestão](../apps/gestao/lib/main.dart). **Verificação técnica em 13/10/2026:** análise Flutter sem erros; 2 testes da Gestão aprovados. **GOG-084 continua parcial:** sem logs, alertas, exportação ou monitoramento de produção.
- [x] Comanda 80mm para impressão local (GOG-031 parcial): `GET /api/v1/local/orders/{id}/comanda` gera comanda de cozinha (itens, adicionais, canal/mesa, prioridade, total, formas e aviso fiscal) pronta para impressão no navegador; a Gestão abre pelo menu **Imprimir comanda**. Página privada (`noindex`). Evidência: [API](../services/api/gogdely_api/local_orders.py), [Gestão](../apps/gestao/lib/main.dart), [teste](../services/api/tests/test_local_orders.py). **Verificação técnica em 13/10/2026:** 29 testes da API aprovados; análise e testes da Gestão aprovados. **GOG-031 continua parcial:** sem impressora térmica, filas, setores ou protocolo ESC/POS reais.
- [x] Papéis locais na Gestão (GOG-037 parcial): seletor **Papel local** (Gerente/Caixa/Cozinha) restringe ações — cancelar é exclusivo do Gerente, pagamento simulado exige Caixa ou Gerente, prioridade exige Cozinha ou Gerente; o painel mostra o papel ativo. Evidência: [Gestão](../apps/gestao/lib/main.dart). **Verificação técnica em 13/10/2026:** análise e 2 testes da Gestão aprovados. **GOG-037 continua parcial:** sem autenticação, cargos configuráveis ou autorização no backend.
- [ ] Separação e permissões por empresa/filial comprovadas antes de adicionar novas lojas ao piloto.
- [ ] Teste visual do proprietário e homologação formal do piloto.

## Decisões

### Visão e negócio

- [ ] **GOG-001** — Marketplace de diversas categorias.
- [ ] **GOG-002** — Todo o Brasil.
- [ ] **GOG-003** — Delivery, retirada e consumo no local.
- [ ] **GOG-004** — Assinaturas e comissões por empresa.
- [ ] **GOG-005** — Arquitetura nacional desde a primeira versão.
- [ ] **GOG-006** — Supabase e Render.

### Plataformas

- [ ] **GOG-007** — Cliente Android e iOS.
- [ ] **GOG-008** — Gestão Windows e macOS.
- [ ] **GOG-009** — Entregador Android e iOS.
- [ ] **GOG-010** — Master em todas as plataformas.
- [ ] **GOG-011** — Simulador VS Code e ambiente de desenvolvimento.
- [ ] **GOG-012** — Offline avançado com sincronização.
- [ ] **GOG-013** — Dispositivos simultâneos configuráveis por empresa.
- GOG-014 — Sem observações adicionais. **N/A: registro sem ação.**

### Marketplace

- [ ] **GOG-015** — Descoberta por GPS e endereço.
- [ ] **GOG-016** — Categorias principais da plataforma e subcategorias das empresas.
- [ ] **GOG-017** — Um estabelecimento por pedido.
- [ ] **GOG-018** — Explorar sem cadastro; identificar no checkout.
- [ ] **GOG-019** — Métodos de pagamento configuráveis por estabelecimento.
- [ ] **GOG-020** — QR Code por mesa.
- [ ] **GOG-021** — Promoções da plataforma e das empresas.
- [ ] **GOG-022** — Avaliações de estabelecimentos e entregas.
- [ ] **GOG-023** — Etapas detalhadas e mapa do entregador em tempo real.
- [ ] **GOG-024** — Pedidos imediatos e agendados.
- [ ] **GOG-025** — Cadastro de empresas com aprovação.
- [ ] **GOG-026** — Pedido por QR de mesa entra na fila com número, data e hora.

### Gestão

- [ ] **GOG-027** — Várias filiais por empresa.
- [ ] **GOG-028** — Setores configuráveis por estabelecimento.
- [ ] **GOG-029** — Impressão configurável por empresa.
- [ ] **GOG-030** — USB, rede e Bluetooth compatível.
- [ ] **GOG-031** — Comandas impressas e painel digital.
- [ ] **GOG-032** — Ordem de chegada com prioridade configurável.
- [ ] **GOG-033** — Contas individuais e compartilhadas em mesas.
- [ ] **GOG-034** — Pagamento de mesa antes ou depois, configurável.
- [ ] **GOG-035** — Estoque avançado, fichas técnicas e baixa automática.
- [ ] **GOG-036** — PDV, abertura, fechamento, sangria e suprimento.
- [ ] **GOG-037** — Permissões por cargo e função.
- [ ] **GOG-038** — Alterações com histórico e autorização.
- [ ] **GOG-039** — Fila offline local e sincronização automática.
- GOG-040 — Sem observações adicionais. **N/A: registro sem ação.**

### Logística

- [ ] **GOG-041** — Entregadores próprios e da plataforma.
- [ ] **GOG-042** — Distribuição manual e automática.
- [ ] **GOG-043** — Motos, bicicletas, carros e outros.
- [ ] **GOG-044** — GPS em tempo real (reafirmação da Etapa 3).
- [ ] **GOG-045** — Mapa interno e navegação externa.
- [ ] **GOG-046** — Código, foto e assinatura configuráveis.
- [ ] **GOG-047** — Taxas personalizadas por estabelecimento.
- [ ] **GOG-048** — Raio, bairros e regiões.
- [ ] **GOG-049** — Múltiplas entregas por viagem.
- [ ] **GOG-050** — Parceiros após primeira versão.
- [ ] **GOG-051** — WhatsApp manual e automação futura.
- [ ] **GOG-052** — Remuneração configurável por empresa.
- [ ] **GOG-053** — Eventos offline e sincronização automática.
- GOG-054 — Sem observações adicionais. **N/A: registro sem ação.**

### Pagamentos e fiscal

- [ ] **GOG-055** — Pix, cartão e pagamentos presenciais configuráveis.
- [ ] **GOG-056** — Comparar provedores antes de escolher.
- [ ] **GOG-057** — Split automático quando suportado.
- [ ] **GOG-058** — Planos fixos e contratos personalizados.
- [ ] **GOG-059** — Comissão percentual, fixa ou combinada.
- [ ] **GOG-060** — Comissão sobre produtos, sem frete.
- [ ] **GOG-061** — Assinaturas mensais.
- [ ] **GOG-062** — Teste gratuito configurável por empresa.
- [ ] **GOG-063** — Avisos, carência e suspensão gradual.
- [ ] **GOG-064** — Cancelamentos e estornos por etapa com auditoria.
- [ ] **GOG-065** — Chargebacks conforme contrato, causa e provedor.
- [ ] **GOG-066** — Entregadores próprios pagos pelo estabelecimento e da plataforma por mecanismo separado.
- [ ] **GOG-067** — Emissão fiscal integrada desde a primeira versão.
- [ ] **GOG-068** — Conciliação automática com revisão de divergências.
- GOG-069 — Sem observações adicionais. **N/A: registro sem ação.**

### Arquitetura e segurança

- [x] **GOG-070** — Monorepositório. Evidência: estrutura [apps/](../apps), [services/](../services) e [packages/](../packages) no mesmo repositório.
- [ ] **GOG-071** — Flutter Android, iOS, Windows, macOS e Web.
- [ ] **GOG-072** — Supabase PostgreSQL, Auth, Storage e Realtime.
- [ ] **GOG-073** — Render para FastAPI e backend.
- [ ] **GOG-074** — Banco compartilhado tenant_id, RLS e autorização backend.
- [ ] **GOG-075** — Supabase Auth, login social e MFA por perfil.
- [ ] **GOG-076** — Cargos e permissões adicionais configuráveis.
- [ ] **GOG-077** — Ambientes local, testes, homologação e produção isolados.
- [ ] **GOG-078** — Banco offline após testes de compatibilidade.
- [ ] **GOG-079** — Conflitos por regra automática e revisão humana crítica.
- [ ] **GOG-080** — Realtime para eventos e API para comandos/transações.
- [ ] **GOG-081** — Backups frequentes, retenção e restauração testada.
- [ ] **GOG-082** — Master MFA, dispositivos confiáveis, auditoria e aprovação crítica.
- [ ] **GOG-083** — LGPD privacidade desde concepção, retenção, exportação, exclusão e auditoria.
- [ ] **GOG-084** — Logs, métricas, alertas e rastreamento de falhas.
- [ ] **GOG-085** — Serviços pagos somente com aprovação e orçamento.
- GOG-086 — Sem observações adicionais. **N/A: registro sem ação.**

### Design e simulação

- [ ] **GOG-087** — Visual moderno, minimalista e profissional.
- [x] **GOG-088** — Paleta exclusiva a definir. Direção Azul Elétrico + Grafite aprovada e registrada no [Design System](DESIGN_SYSTEM.md). Componentes e acessibilidade continuam pendentes em seus próprios itens.
- [ ] **GOG-089** — Temas claro, escuro e automático.
- [ ] **GOG-090** — Navegação Cliente focada em categorias.
- [ ] **GOG-091** — Início com localização, categorias, promoções e recomendações.
- [ ] **GOG-092** — Layout padronizado e identidade visual por empresa.
- [ ] **GOG-093** — Gestão adaptativa para mouse, teclado e toque.
- [ ] **GOG-094** — KDS cartões e lista.
- [ ] **GOG-095** — Entregador mapa e lista.
- [ ] **GOG-096** — Master dashboard e módulos configuráveis.
- [ ] **GOG-097** — F5 simulador iPhone, Android e tablet.
- [ ] **GOG-098** — Laboratório com cenários de pedidos, notificações e offline.
- [ ] **GOG-099** — Acessibilidade avançada com testes automáticos e manuais.
- [ ] **GOG-100** — Multilíngue com português inicial.
- [ ] **GOG-101** — Push, internas, e-mail e canais configuráveis.
- [ ] **GOG-102** — Preferências por usuário, empresa e função.
- GOG-103 — Sem observações adicionais. **N/A: registro sem ação.**

### Contribuição

- [ ] **GOG-104** — Repositório privado GILLEYOLIVER.
- [ ] **GOG-105** — Branches main, develop, feature/*.
- [ ] **GOG-106** — IA pode integrar alterações já aprovadas automaticamente.
- [ ] **GOG-107** — PR com revisão técnica e aprovação do proprietário.
- [ ] **GOG-108** — Mudança arquitetural requer proposta e aprovação prévia.
- [ ] **GOG-109** — Conventional Commits com ID do requisito.
- [ ] **GOG-110** — Testes unitários, integração, interface, segurança e fluxos críticos.
- [ ] **GOG-111** — Meta de cobertura e validação de fluxos críticos.
- [ ] **GOG-112** — Lint, análise estática, dependências e arquitetura.
- [ ] **GOG-113** — Documentação em toda funcionalidade.
- [ ] **GOG-114** — Migrations versionadas e revisadas.
- [ ] **GOG-115** — Segredos nunca no Git; ambientes separados.
- [ ] **GOG-116** — Homologação automática após merge em develop e testes.
- [ ] **GOG-117** — Produção com autorização do proprietário e validação independente.
- [ ] **GOG-118** — Plano de reversão para toda publicação.
- [ ] **GOG-119** — Nenhum serviço pago sem aprovação.
- [ ] **GOG-120** — GitHub Issues/Projects e roadmap.
- [ ] **GOG-121** — Versionamento semântico e releases.
- GOG-122 — Sem observações adicionais. **N/A: registro sem ação.**

### Visão e negócio

- [ ] **GOG-123** — Piloto controlado e expansão nacional.
- [ ] **GOG-124** — Até 10 empresas piloto.
- [ ] **GOG-125** — Diversas categorias desde primeira versão.
- [ ] **GOG-126** — Liberação com testes, segurança, documentação, homologação e evidências.
- [ ] **GOG-127** — Publicação de cada plataforma após aprovação.
- [ ] **GOG-128** — Instaladores desktop e lojas quando viável.
- [ ] **GOG-129** — Atualizações graduais com monitoramento e reversão.
- [ ] **GOG-130** — Suporte por plano contratado.
- [ ] **GOG-131** — Estabelecimento atende pedidos; GOGDELY plataforma e disputas.
- [ ] **GOG-132** — Monitoramento contínuo e resposta a incidentes.
- [ ] **GOG-133** — Disponibilidade após testes e orçamento.
- [ ] **GOG-134** — Carga progressiva antes de expansão.
- [ ] **GOG-135** — Continuidade, backups e exercícios de recuperação.
- [ ] **GOG-136** — Onboarding, tutoriais, vídeos e ajuda.
- [ ] **GOG-137** — Roadmap trimestral por métricas e feedback.
- [ ] **GOG-138** — Feature flags por ambiente, empresa e grupo.
- [ ] **GOG-139** — MVP encerrado após homologação e piloto aprovado.
- [ ] **GOG-140** — Releases rotineiras controladas, críticas aprovadas.
- GOG-141 — Sem observações adicionais. **N/A: registro sem ação.**


## Como dar baixa

Ao concluir uma entrega, registrar aqui a data, o escopo real, o arquivo/PR de evidência e a validação executada. Marcar somente o código cujo requisito inteiro foi atendido; entregas parciais ficam nos marcos do piloto ou em nota sob o item. Nenhum marco local substitui revisão técnica, aprovação, homologação, merge ou deploy.
