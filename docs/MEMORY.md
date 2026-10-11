# MEMORY.md — Contexto persistente GOGDELY

Este arquivo é memória **documental versionada**, não armazenamento de senhas nem memória automática do assistente. Atualizar somente com fatos e decisões verificáveis.

## Identidade e estado
- Projeto: GOGDELY, marketplace nacional multiempresa e multissetorial.
- Repositório privado: GILLEYOLIVER/GOGDELY.
- Documento Mestre v1.0 aprovado como base de planejamento, com 141 registros GOG-001 a GOG-141.
- Piloto previsto com até dez empresas; expansão nacional posterior.
- Estado: estrutura documental inicial; **nenhuma aplicação implementada/homologada e nenhum deploy de produção**.

## Produtos
- Cliente: Android/iOS; descoberta, catálogo, pedidos, pagamento e rastreamento.
- Gestão: Windows/macOS; PDV, KDS, impressão, estoque, fiscal e mesas QR.
- Entregador: Android/iOS; rotas, GPS, comprovantes e entregas múltiplas.
- Master: Android/iOS/Windows/macOS/Web; empresas, planos, comissões e governança.

## Decisões essenciais
- Monorepositório Flutter; FastAPI/Render; Supabase PostgreSQL/Auth/Storage/Realtime.
- Multiempresa com tenant_id, RLS e autorização no backend; filiais e permissões por função.
- Um estabelecimento por pedido; exploração sem cadastro, identificação no checkout; QR de mesa com data/hora/número.
- Assinaturas mensais e comissões flexíveis sobre produtos sem frete; provedor de pagamentos pendente; split quando suportado; emissão fiscal exigida na primeira versão.
- Impressoras térmicas compatíveis USB/rede/Bluetooth, setores configuráveis e KDS.
- Offline avançado, sincronização automática e revisão humana de conflitos críticos.
- GPS em tempo real; entregadores próprios e da plataforma; parceiros externos após primeira versão.
- Identidade moderna/minimalista; paleta ainda não definida; temas claro/escuro/automático; acessibilidade avançada.
- VS Code F5 e laboratório de prévia iPhone/Android/tablet com cenários fictícios.
- Git main/develop/feature/*; PR com revisão técnica e aprovação do proprietário; custos e produção somente com autorização.

## Pendências prioritárias
Provedor de pagamento; emissão fiscal nacional; banco offline e conflitos; licenças e compatibilidade de componentes; metas de cobertura/carga/RPO/RTO; proteção de branches; identidade visual; privacidade de GPS; orçamento Supabase/Render.

## Estado do GitHub
README em main; estrutura inicial em develop; PR #1 em rascunho; seis componentes open source catalogados, **não incorporados**. Importação integral dos 141 registros para o GitHub ainda pendente de verificação.

## Atualização
Distinguir aprovado, proposto, pendente, implementado e homologado. Registrar data, requisito, evidências e próximo passo; nunca inferir aprovações. Revisado em 2026-10-11.
