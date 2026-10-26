# GOGDELY — DECISIONS.md

**Documento Mestre v1.0 | 11/10/2026 | Base de planejamento aprovada.**

Registro de 141 respostas e observações das dez etapas. Estes itens não equivalem a 141 funcionalidades distintas. Decisões técnicas pendentes não são consideradas resolvidas. Nenhum deploy ou serviço pago autorizado por este documento.

## Etapa 1 — Visão e negócio

- **GOG-001** — Marketplace de diversas categorias.
- **GOG-002** — Todo o Brasil.
- **GOG-003** — Delivery, retirada e consumo no local.
- **GOG-004** — Assinaturas e comissões por empresa.
- **GOG-005** — Arquitetura nacional desde a primeira versão.
- **GOG-006** — Supabase e Render.

## Etapa 2 — Plataformas

- **GOG-007** — Cliente Android e iOS.
- **GOG-008** — Gestão Windows e macOS.
- **GOG-009** — Entregador Android e iOS.
- **GOG-010** — Master em todas as plataformas.
- **GOG-011** — Simulador VS Code e ambiente de desenvolvimento.
- **GOG-012** — Offline avançado com sincronização.
- **GOG-013** — Dispositivos simultâneos configuráveis por empresa.
- **GOG-014** — Sem observações adicionais.

## Etapa 3 — Marketplace

- **GOG-015** — Descoberta por GPS e endereço.
- **GOG-016** — Categorias principais da plataforma e subcategorias das empresas.
- **GOG-017** — Um estabelecimento por pedido.
- **GOG-018** — Explorar sem cadastro; identificar no checkout.
- **GOG-019** — Métodos de pagamento configuráveis por estabelecimento.
- **GOG-020** — QR Code por mesa.
- **GOG-021** — Promoções da plataforma e das empresas.
- **GOG-022** — Avaliações de estabelecimentos e entregas.
- **GOG-023** — Etapas detalhadas e mapa do entregador em tempo real.
- **GOG-024** — Pedidos imediatos e agendados.
- **GOG-025** — Cadastro de empresas com aprovação.
- **GOG-026** — Pedido por QR de mesa entra na fila com número, data e hora.

## Etapa 4 — Gestão

- **GOG-027** — Várias filiais por empresa.
- **GOG-028** — Setores configuráveis por estabelecimento.
- **GOG-029** — Impressão configurável por empresa.
- **GOG-030** — USB, rede e Bluetooth compatível.
- **GOG-031** — Comandas impressas e painel digital.
- **GOG-032** — Ordem de chegada com prioridade configurável.
- **GOG-033** — Contas individuais e compartilhadas em mesas.
- **GOG-034** — Pagamento de mesa antes ou depois, configurável.
- **GOG-035** — Estoque avançado, fichas técnicas e baixa automática.
- **GOG-036** — PDV, abertura, fechamento, sangria e suprimento.
- **GOG-037** — Permissões por cargo e função.
- **GOG-038** — Alterações com histórico e autorização.
- **GOG-039** — Fila offline local e sincronização automática.
- **GOG-040** — Sem observações adicionais.

## Etapa 5 — Logística

- **GOG-041** — Entregadores próprios e da plataforma.
- **GOG-042** — Distribuição manual e automática.
- **GOG-043** — Motos, bicicletas, carros e outros.
- **GOG-044** — GPS em tempo real (reafirmação da Etapa 3).
- **GOG-045** — Mapa interno e navegação externa.
- **GOG-046** — Código, foto e assinatura configuráveis.
- **GOG-047** — Taxas personalizadas por estabelecimento.
- **GOG-048** — Raio, bairros e regiões.
- **GOG-049** — Múltiplas entregas por viagem.
- **GOG-050** — Parceiros após primeira versão.
- **GOG-051** — WhatsApp manual e automação futura.
- **GOG-052** — Remuneração configurável por empresa.
- **GOG-053** — Eventos offline e sincronização automática.
- **GOG-054** — Sem observações adicionais.

## Etapa 6 — Pagamentos e fiscal

- **GOG-055** — Pix, cartão e pagamentos presenciais configuráveis.
- **GOG-056** — Comparar provedores antes de escolher.
- **GOG-057** — Split automático quando suportado.
- **GOG-058** — Planos fixos e contratos personalizados.
- **GOG-059** — Comissão percentual, fixa ou combinada.
- **GOG-060** — Comissão sobre produtos, sem frete.
- **GOG-061** — Assinaturas mensais.
- **GOG-062** — Teste gratuito configurável por empresa.
- **GOG-063** — Avisos, carência e suspensão gradual.
- **GOG-064** — Cancelamentos e estornos por etapa com auditoria.
- **GOG-065** — Chargebacks conforme contrato, causa e provedor.
- **GOG-066** — Entregadores próprios pagos pelo estabelecimento e da plataforma por mecanismo separado.
- **GOG-067** — Emissão fiscal integrada desde a primeira versão.
- **GOG-068** — Conciliação automática com revisão de divergências.
- **GOG-069** — Sem observações adicionais.

## Etapa 7 — Arquitetura e segurança

- **GOG-070** — Monorepositório.
- **GOG-071** — Flutter Android, iOS, Windows, macOS e Web.
- **GOG-072** — Supabase PostgreSQL, Auth, Storage e Realtime.
- **GOG-073** — Render para FastAPI e backend.
- **GOG-074** — Banco compartilhado tenant_id, RLS e autorização backend.
- **GOG-075** — Supabase Auth, login social e MFA por perfil.
- **GOG-076** — Cargos e permissões adicionais configuráveis.
- **GOG-077** — Ambientes local, testes, homologação e produção isolados.
- **GOG-078** — Banco offline após testes de compatibilidade.
- **GOG-079** — Conflitos por regra automática e revisão humana crítica.
- **GOG-080** — Realtime para eventos e API para comandos/transações.
- **GOG-081** — Backups frequentes, retenção e restauração testada.
- **GOG-082** — Master MFA, dispositivos confiáveis, auditoria e aprovação crítica.
- **GOG-083** — LGPD privacidade desde concepção, retenção, exportação, exclusão e auditoria.
- **GOG-084** — Logs, métricas, alertas e rastreamento de falhas.
- **GOG-085** — Serviços pagos somente com aprovação e orçamento.
- **GOG-086** — Sem observações adicionais.

## Etapa 8 — Design e simulação

- **GOG-087** — Visual moderno, minimalista e profissional.
- **GOG-088** — Paleta exclusiva a definir.
- **GOG-089** — Temas claro, escuro e automático.
- **GOG-090** — Navegação Cliente focada em categorias.
- **GOG-091** — Início com localização, categorias, promoções e recomendações.
- **GOG-092** — Layout padronizado e identidade visual por empresa.
- **GOG-093** — Gestão adaptativa para mouse, teclado e toque.
- **GOG-094** — KDS cartões e lista.
- **GOG-095** — Entregador mapa e lista.
- **GOG-096** — Master dashboard e módulos configuráveis.
- **GOG-097** — F5 simulador iPhone, Android e tablet.
- **GOG-098** — Laboratório com cenários de pedidos, notificações e offline.
- **GOG-099** — Acessibilidade avançada com testes automáticos e manuais.
- **GOG-100** — Multilíngue com português inicial.
- **GOG-101** — Push, internas, e-mail e canais configuráveis.
- **GOG-102** — Preferências por usuário, empresa e função.
- **GOG-103** — Sem observações adicionais.

## Etapa 9 — Contribuição

- **GOG-104** — Repositório privado GILLEYOLIVER.
- **GOG-105** — Branches main, develop, feature/*.
- **GOG-106** — IA pode integrar e publicar em homologação uma entrega solicitada pelo proprietário após concluir os ajustes e registrar as evidências; não precisa de nova aprovação por PR.
- **GOG-107** — PR rastreável com escopo, riscos e reversão; revisão técnica independente opcional, sem bloquear merge ou deploy.
- **GOG-108** — Mudança arquitetural requer proposta e aprovação prévia.
- **GOG-109** — Conventional Commits com ID do requisito.
- **GOG-110** — Testes unitários, integração, interface, segurança e fluxos críticos conforme escopo, salvo dispensa expressa para uma entrega identificada; registrar os testes não executados.
- **GOG-111** — Meta de cobertura e validação de fluxos críticos.
- **GOG-112** — Lint, análise estática, dependências e arquitetura.
- **GOG-113** — Documentação em toda funcionalidade.
- **GOG-114** — Migrations versionadas e revisadas.
- **GOG-115** — Segredos nunca no Git; ambientes separados.
- **GOG-116** — Após merge em develop, publicar em homologação e conferir o estado do deploy; a dispensa expressa de testes não impede essa publicação.
- **GOG-117** — Produção com autorização expressa do proprietário para a publicação, compatibilidade de banco confirmada e plano de reversão; revisão independente opcional.
- **GOG-118** — Plano de reversão para toda publicação.
- **GOG-119** — Nenhum serviço pago sem aprovação.
- **GOG-120** — GitHub Issues/Projects e roadmap.
- **GOG-121** — Versionamento semântico e releases.
- **GOG-122** — Sem observações adicionais.

## Etapa 10 — Lançamento e operação

- **GOG-123** — Piloto controlado e expansão nacional.
- **GOG-124** — Até 10 empresas piloto.
- **GOG-125** — Diversas categorias desde primeira versão.
- **GOG-126** — Liberação com testes, segurança, documentação, homologação e evidências.
- **GOG-127** — Publicação de cada plataforma após aprovação.
- **GOG-128** — Instaladores desktop e lojas quando viável.
- **GOG-129** — Atualizações graduais com monitoramento e reversão.
- **GOG-130** — Suporte por plano contratado.
- **GOG-131** — Estabelecimento atende pedidos; GOGDELY plataforma e disputas.
- **GOG-132** — Monitoramento contínuo e resposta a incidentes.
- **GOG-133** — Disponibilidade após testes e orçamento.
- **GOG-134** — Carga progressiva antes de expansão.
- **GOG-135** — Continuidade, backups e exercícios de recuperação.
- **GOG-136** — Onboarding, tutoriais, vídeos e ajuda.
- **GOG-137** — Roadmap trimestral por métricas e feedback.
- **GOG-138** — Feature flags por ambiente, empresa e grupo.
- **GOG-139** — MVP encerrado após homologação e piloto aprovado.
- **GOG-140** — Releases rotineiras controladas, críticas aprovadas.
- **GOG-141** — Sem observações adicionais.

## Controle de alterações

Mudanças de decisões aprovadas exigem proposta, justificativa, impacto e aprovação do proprietário. Manter histórico de revisão e rastreabilidade de GOG-xxx para issues, testes e PRs.

### Alteração de governança aprovada pelo proprietário em 18/10/2026

**Proposta e justificativa:** retirar a revisão técnica independente e a
aprovação repetida por PR como bloqueios de merge/deploy. O proprietário pediu
que a entrega autorizada avance até merge e publicação após os ajustes.

**Histórico:** GOG-106 permitia integração apenas de alterações já aprovadas;
GOG-107 exigia revisão independente e aprovação do proprietário por PR;
GOG-110 exigia testes; GOG-116 condicionava homologação a merge e testes;
GOG-117 exigia validação independente para produção. As formulações acima
substituem essas condições a partir desta deliberação, sem apagar o registro.

**Escopo da dispensa de testes:** o proprietário dispensou novos testes para a
entrega atual que inclui as PRs #43 e #44 e esta alteração de governança.
Testes já executados permanecem como evidência; os não executados devem ser
registrados sem alegar aprovação. Em entregas futuras, dispensas de testes
precisam ser expressas para o respectivo escopo.

**Impacto e limites:** o agente pode fazer merge e deploy de homologação sem
esperar uma revisão humana separada. Isso não transforma código sem migração
aplicada em funcionalidade ativa, nem dispensa backup recuperável, compatibilidade
do esquema, isolamento entre empresas, proteção de segredos ou plano de
reversão. Produção e serviços pagos ainda exigem autorização expressa.
