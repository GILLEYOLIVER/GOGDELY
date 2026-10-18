# Publicação online do GOGDELY — proposta GOG-072/073/074/114/116/117/129

**Estado em 17/10/2026:** preparação em branch de recurso. Nenhum PWA ou fluxo de pedido foi homologado para produção.

## Sequência de publicação proposta

1. Revisar e integrar separadamente o piloto local e a fundação Supabase. O código local não deve operar contra o banco público por troca de URL: faltam autenticação, autorização, políticas por empresa e transações de produção.
2. Aplicar migrações versionadas primeiro em projeto isolado de testes. Verificar oito tabelas, chaves compostas, RLS, Storage privado e negação cruzada entre duas empresas. Guardar o histórico da migração fora de credenciais do aplicativo.
3. Implementar Auth e autorização da API para Cliente, Gestão e Entregador, com papéis, filiais e auditoria. A API é a autoridade de preços, pedidos e alterações; o cliente nunca recebe chave administrativa do Supabase.
4. Publicar a API no Render a partir de commit aprovado da `main`, com deploy após verificações de CI, `/health`, `/ready` e `/version.json`. Migrações são executadas por job protegido **antes** da nova API receber tráfego; o auto-deploy do Render não aplica SQL sozinho. O serviço gratuito não oferece comando pre-deploy e pode adormecer.
5. Gerar builds Web específicos de Cliente, Gestão e Entregador sem `GOGDELY_LOCAL_API=true`, publicar três origens HTTPS e verificar manifesto, ícones, cache e versão. O frontend só anuncia nova versão depois de a API do mesmo release passar `/ready` e confirmar o SHA live.
6. Para PWA, consultar a versão publicada ao abrir/retomar e atualizar recursos com política de cache revisada. Dados de cardápio e pedidos virão da API/Supabase conforme permissão; trocar dados no Supabase não atualiza o código do aplicativo. Distribuição de binários Android/iOS/desktop é um fluxo de release separado.

## Gates ainda abertos

- Aprovação técnica independente dos PRs #32 e #34; aprovação do proprietário para a release concreta.
- Migração revisada e aplicada; URL/credencial PostgreSQL armazenada somente como segredo do serviço ou job, nunca no Git ou PWA.
- API real de catálogo, pedidos, transições e entrega; Auth/RLS e testes de isolamento; pagamentos por provedor, fiscal, privacidade de GPS, backups e restauração.
- Suporte Web da Gestão, builds reproduzíveis dos três PWAs, URLs públicas, validação em dispositivo e política de atualização; revisão de licenças das imagens e dependências.
- Serviço de produção separado do `gogdely-api-testes`; plano de custo e disponibilidade aceitos pelo proprietário.

## Reversão

Se o novo deploy falhar, manter o commit anterior no ar e não publicar os PWAs. Para uma versão já publicada, restaurar o build anterior compatível com o esquema atual; migrations exigem reversão planejada separadamente. Nunca assumir que rollback de código reverte o banco.
