# AGENTS.md — GOGDELY

Escopo: todo o repositório. Documento Mestre v1.0, decisões GOG-001 a GOG-141, é a referência de requisitos. **Estado atual: documentação; nenhum app homologado.**

## Antes de atuar
1. Ler README.md, CONTRIBUTING.md, docs/ARCHITECTURE.md, docs/MEMORY.md, docs/ATA.md, docs/DESIGN_SYSTEM.md e docs/OPEN_ISSUES.md.
2. Confirmar issue, requisito GOG-xxx, escopo, aprovação e critérios de aceite. Se houver conflito, pedir decisão; não presumir autorização.
3. Trabalhar em feature/* a partir de develop. Não editar main diretamente.

## Regras obrigatórias
- Conventional Commits com referência GOG-xxx; PR com evidências, testes, documentação, riscos e plano de reversão.
- PR requer revisão técnica independente e aprovação do proprietário. Agentes só podem integrar alterações **já aprovadas** após verificações; nunca aprovar em nome de humanos.
- Mudança arquitetural requer proposta e aprovação prévia. Sem deploy de produção ou serviço pago sem autorização expressa.
- Não expor segredos ou dados reais; ambientes local, testes, homologação e produção separados.
- Testar unitário, integração, UI, segurança e fluxos críticos conforme escopo; não declarar teste não executado.
- Migrations versionadas/revisadas; nenhum acesso cruzado entre empresas ou filiais.
- Dependências externas só após revisão de licença, segurança, manutenção e compatibilidade.
- Atualizar documentação e manter rastreabilidade.

## Invariantes
- Flutter: Cliente Android/iOS; Gestão Windows/macOS; Entregador Android/iOS; Master multiplataforma.
- FastAPI como autoridade de comandos e transações; Supabase PostgreSQL/Auth/Storage/Realtime; Render para backend.
- Isolamento por tenant_id, RLS e autorização da API.
- Pagamentos confirmados por provedor, idempotentes e auditáveis; offline não pode simular liquidação financeira.
- Master com MFA e auditoria; privacidade desde a concepção.
- Simulador de iPhone no Windows é prévia responsiva, não iOS Simulator nativo.

## Conclusão de tarefas
Requisito rastreado, testes e evidências, documentação, licença e segurança revisadas, PR aprovado. Nenhum merge ou deploy implícito.
