# Contribuição — GOGDELY

Documento Mestre v1.0: decisões GOG-001 a GOG-141.

- Branches: main (estável), develop (integração), feature/* (trabalho isolado).
- Commits: Conventional Commits com referência GOG-xxx.
- PRs: revisão técnica independente e aprovação explícita do proprietário; integração automática somente após aprovação e verificações.
- Alterações arquiteturais: proposta técnica e aprovação prévia.
- Testes: unitários, integração, interface, segurança e fluxos críticos; atualizar documentação.
- Banco: migrations versionadas e revisadas; isolamento tenant_id + RLS + autorização backend.
- Credenciais: nunca no Git; ambientes separados.
- Homologação: automação apenas depois da configuração e aprovação da infraestrutura.
- Produção: aprovação do proprietário, validação técnica independente e plano de reversão.
- Custos: nenhuma contratação, upgrade ou serviço pago sem autorização explícita.
