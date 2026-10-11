# Roadmap GOGDELY — proposta de execução

**Status:** planejamento; sequência sugerida, não cronograma ou autorização de implementação.

1. Fundação: monorepositório, Flutter, FastAPI, ambientes, CI e autenticação.
2. Multiempresa: tenant_id, RLS, filiais, papéis e testes de isolamento.
3. Marketplace: categorias, lojas, cardápios, carrinho e pedidos simulados.
4. Gestão: QR de mesa, KDS, impressão térmica, PDV e estoque.
5. Offline: banco local selecionado por teste, fila e reconciliação de eventos.
6. Financeiro e fiscal: homologação do provedor, split, assinaturas, conciliação e documentos fiscais.
7. Logística: app Entregador, atribuição, GPS, rotas e comprovantes.
8. Homologação: acessibilidade, segurança, carga, recuperação, testes multiplataforma e piloto de até dez empresas.
9. Expansão: liberação gradual, feature flags, monitoramento e roadmap trimestral.

## Gates obrigatórios
- Issue, requisito GOG-xxx e critérios de aceite antes da implementação.
- Testes unitários, integração, interface, segurança e fluxos críticos.
- Revisão técnica independente e aprovação do proprietário para PR.
- Homologação com evidências; publicação em produção somente com autorização específica e plano de reversão.

## Bloqueios a resolver
Provedor financeiro, emissão fiscal nacional, banco offline, revisores técnicos, metas de qualidade, orçamento e identidade visual.
