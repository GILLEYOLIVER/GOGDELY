# Contribuição — GOGDELY

Documento Mestre v1.0: decisões GOG-001 a GOG-141.

- Branches: main (estável), develop (integração), feature/* (trabalho isolado).
- Commits: Conventional Commits com referência GOG-xxx.
- PRs: escopo, evidências, riscos e reversão documentados; revisão técnica independente é opcional. Um pedido explícito de entrega do proprietário autoriza merge e deploy de homologação após concluir os ajustes, sem nova aprovação por PR.
- Alterações arquiteturais: proposta técnica e aprovação prévia.
- Testes: unitários, integração, interface, segurança e fluxos críticos conforme escopo; uma dispensa expressa do proprietário vale para a entrega indicada e deve constar nas evidências.
- Banco: migrations versionadas e revisadas; isolamento tenant_id + RLS + autorização backend.
- Credenciais: nunca no Git; ambientes separados.
- Homologação: automação apenas depois da configuração e aprovação da infraestrutura.
- Produção: autorização expressa do proprietário para a publicação, verificação de compatibilidade de banco e plano de reversão; revisão independente não é obrigatória.
- Custos: nenhuma contratação, upgrade ou serviço pago sem autorização explícita.
