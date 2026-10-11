# Arquitetura inicial — GOGDELY

- Monorepositório Flutter para Cliente (Android/iOS), Gestão (Windows/macOS), Entregador (Android/iOS) e Master (todas as plataformas).
- API FastAPI hospedável no Render; Supabase PostgreSQL/Auth/Storage/Realtime.
- Dados compartilhados com tenant_id, políticas RLS e validação independente de autorização no backend.
- Comandos/transações pela API; Realtime para eventos e atualização de interfaces.
- Offline avançado: banco local ainda não escolhido, fila idempotente e revisão humana de conflitos críticos.
- Ambientes isolados: local, testes, homologação e produção.
- Pagamentos, fiscal, impressão térmica e mapas requerem homologação específica.
- Sem deploy ou serviços contratados nesta inicialização.
