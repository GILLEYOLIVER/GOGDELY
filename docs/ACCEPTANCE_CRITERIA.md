# Critérios de aceite e evidências — GOGDELY

**Status:** checklist inicial; metas numéricas e casos de teste detalhados pendentes de homologação.

## Critérios por área
1. **Multiempresa:** dados e permissões isolados por tenant_id/filial; testes negativos de acesso cruzado.
2. **Cliente:** busca, catálogo, carrinho de uma empresa, checkout e pedidos com estados consistentes.
3. **Mesa:** QR identifica mesa/unidade, pedido registra ID, data, hora e fila; contas individuais/compartilhadas.
4. **Gestão:** impressão por setor, KDS, estoque com ficha técnica, caixa e alterações auditadas.
5. **Pagamentos:** confirmação real do provedor, idempotência, split quando suportado, estorno e conciliação.
6. **Fiscal:** emissão e contingência nos cenários/jurisdições homologados, com responsabilidade definida.
7. **Entregas:** atribuição, GPS consentido, rotas, comprovantes e finalização sem duplicidades.
8. **Offline:** eventos persistidos e sincronizados; conflitos críticos revisáveis; nenhum pagamento ficticiamente liquidado.
9. **Segurança:** MFA Master, segredos protegidos, auditoria, LGPD e autorização no backend.
10. **Operação:** backups restaurados em testes, alertas, resposta a incidentes e carga progressiva.
11. **Interfaces:** acessibilidade testada, tema claro/escuro, idioma pt-BR e simulação com dados fictícios.
12. **Piloto:** até dez empresas, aceite operacional registrado e aprovação do proprietário.

## Evidências mínimas
Identificação do requisito GOG-xxx, versão/commit, ambiente, dados de teste, passos de reprodução, resultados, logs sanitizados, responsável e data. Registrar bloqueios, exceções e plano de reversão. Nenhuma caixa marcada significa teste executado sem evidência.
