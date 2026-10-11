# Checklist de revisão — Issue #4

- [ ] Áreas de responsabilidade dos quatro apps e serviços aprovadas.
- [ ] Dependências entre pacotes não criam ciclos.
- [ ] Contratos API/eventos têm estratégia de versionamento.
- [ ] Tenant/filial autorizados no backend e protegidos por RLS.
- [ ] Nenhuma chave privilegiada em app cliente ou artefato distribuído.
- [ ] Pagamentos e operações críticas possuem idempotência e auditoria planejadas.
- [ ] Offline tem decisões pendentes explícitas; nenhuma suposição de pagamento confirmado.
- [ ] Impressão local e comunicação com backend possuem fronteiras de confiança.
- [ ] Fluxos e cenários de teste são rastreáveis a GOG-xxx.
- [ ] Compatibilidade Windows/macOS/Android/iOS/Web será validada por plataforma.
- [ ] Custos, deploy e produção continuam bloqueados sem aprovação específica.
- [ ] Revisão técnica independente e aprovação do proprietário registradas.

**Não marcar como concluído sem evidência.**
