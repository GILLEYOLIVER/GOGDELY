# GOGDELY — Documento Mestre v1.0

**Aprovado como base de planejamento em 11/10/2026.** Este documento consolida requisitos; não autoriza produção, custos ou implementação sem aprovações posteriores.

## Fonte das decisões
O registro integral das **141 decisões e observações** encontra-se em [DECISIONS.md](DECISIONS.md), códigos GOG-001 a GOG-141. Cada alteração deverá referenciar o código correspondente.

## Visão
Marketplace nacional multissetorial e multiempresa. Delivery, retirada e consumo local; piloto de até dez estabelecimentos antes da expansão. Monetização por mensalidade e comissão configuráveis.

## Produtos
| Produto | Plataformas | Escopo |
|---|---|---|
| Cliente | Android/iOS | Busca por localização, categorias, checkout, pedidos, QR mesa, rastreamento |
| Gestão | Windows/macOS | Pedidos, PDV, KDS, comandas, estoque, filiais, fiscal |
| Entregador | Android/iOS | Atribuição, GPS, navegação, comprovantes e múltiplas entregas |
| Master | Android/iOS/Windows/macOS/Web | Empresas, planos, permissões, comissões e governança |

## Arquitetura aprovada
Flutter; FastAPI no Render; Supabase PostgreSQL/Auth/Storage/Realtime; banco compartilhado com tenant_id, RLS e autorização no backend. Operação offline avançada, banco local pendente de escolha por testes. Ambientes local, testes, homologação e produção isolados.

## Governança
Repositório privado GILLEYOLIVER/GOGDELY; main/develop/feature/*; PR com revisão técnica e aprovação do proprietário; agentes podem integrar apenas mudanças já aprovadas. Sem contratação ou deploy de produção sem autorização explícita.

## Documentos relacionados
- [Decisões](DECISIONS.md)
- [Arquitetura](ARCHITECTURE.md)
- [Pendências](OPEN_ISSUES.md)
- [Memória documental](MEMORY.md)
- [Ata](ATA.md)
- [Design System](DESIGN_SYSTEM.md)
- [Catálogo open source](COMPONENTES_OPEN_SOURCE.md)
- [Regras de contribuição](../CONTRIBUTING.md)

## Critérios gerais de aceite
Nenhuma funcionalidade é considerada homologada sem testes aplicáveis, evidências, documentação, revisão de segurança e aprovação operacional. O MVP exige homologação completa e piloto aprovado; publicação individual por plataforma. Ver pendências antes de decisões irreversíveis.
