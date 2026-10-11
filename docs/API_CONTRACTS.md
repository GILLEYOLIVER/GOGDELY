# Contratos iniciais da API — proposta

**Status:** esboço para discussão, não endpoints implementados. **Issue:** #4.

## Princípios
- API versionada sob `/api/v1`; especificação OpenAPI a ser gerada a partir do backend após implementação.
- Identificadores opacos para entidades; `tenant_id` e `branch_id` derivados e autorizados pelo contexto autenticado, não confiados ao payload isoladamente.
- Operações mutáveis críticas recebem chave de idempotência e produzem eventos auditáveis.
- Páginas e filtros sempre restringidos ao escopo autorizado.
- Erros estruturados com código, mensagem segura e identificador de correlação; não expor detalhes internos.

## Domínios e responsáveis
| Domínio | Comandos (API) | Eventos de atualização |
|---|---|---|
| Identidade | sessões, perfis e vínculos | mudanças de acesso |
| Empresas | aprovação, filiais, funcionários | configuração atualizada |
| Catálogo | produtos, categorias, preços | catálogo atualizado |
| Pedidos | criar, aceitar, preparar, cancelar | status de pedido alterado |
| Mesas | abrir conta, adicionar itens, fechar | conta/mesa atualizada |
| Financeiro | iniciar/conciliar pagamento, estornar | pagamento confirmado/estornado |
| Entregas | atribuir, iniciar, concluir | status/localização autorizada |
| Estoque | movimentar, reservar, estornar | saldo alterado |
| Impressão | gerar trabalho, reimprimir | trabalho pendente/concluído/falhou |

## Fluxo de pedido
Cliente solicita pedido -> API valida loja, itens, preços e disponibilidade -> cria pedido idempotente -> provedor confirma pagamento quando aplicável -> API altera estado -> evento Realtime notifica Gestão/Cliente -> cliente consulta API para estado autoritativo.

## Pendências
Esquemas, autenticação de máquina para print-agent, versionamento de eventos offline, webhooks, auditoria e contratos fiscais dependem de ADRs específicas.
