# Primeira barreira de identidade — GOG-075

**Estado:** implementação isolada na branch `feature/gog-075-auth-gate`, issue
[#37](https://github.com/GILLEYOLIVER/GOGDELY/issues/37). Não é autenticação
completa do marketplace e não foi implantada na API de homologação ou produção.

## Contrato

- `GET /api/v1/auth/me` recebe `Authorization: Bearer <access_token>` e retorna
  `{ "user_id": "<UUID confirmado>" }`.
- A API usa exclusivamente o host HTTPS `*.supabase.co` configurado no servidor.
  Envia o token e a chave publicável a `/auth/v1/user` com TLS verificado e
  limite de três segundos. Não segue redirecionamentos.
- O Supabase Auth valida o token; a API usa somente o `id` da resposta. Claims
  de `tenant_id`, papel ou filial fornecidas pelo cliente não concedem acesso.
- Token ausente/recusado: HTTP 401. Configuração, rede ou serviço Auth
  indisponível: HTTP 503. Nenhum desses caminhos retorna token, chave, e-mail
  ou detalhes internos.

## Limites e segurança

Esta consulta verifica identidade no momento da requisição. Ela não cria
sessões no GOGDELY, não autoriza empresa/filial, não abre tabelas Supabase, não
faz convites, login, pedidos ou pagamentos. A próxima fatia implementará
consulta a memberships do banco pelo servidor, política de papéis e testes
negativos entre duas empresas. A chave administrativa do Supabase permanece
fora de PWAs e deste endpoint.

O acesso remoto ao Auth acrescenta latência e depende da disponibilidade do
Supabase. Este limite é aceito para a primeira barreira; cache, JWKS e revogação
exigem decisão de segurança específica. A abordagem `/auth/v1/user` atende
projetos com chaves de assinatura simétricas ou assimétricas, sem compartilhar o
segredo de assinatura com a API.

## Evidência e dependências

`services/api/tests/test_auth.py` simula o servidor Auth e verifica sucesso,
token inválido, resposta malformada, falha de rede e destino HTTPS restrito.
Nenhuma chamada real ou credencial é usada no teste. A implementação usa
apenas a biblioteca padrão do Python e FastAPI já presente no bootstrap; não
introduz dependência externa de runtime.

Referência primária: [Supabase — JSON Web Token (JWT)](https://supabase.com/docs/guides/auth/jwts),
seção sobre verificação de tokens com chave compartilhada por `/auth/v1/user`.

## Reversão

Antes do merge, fechar o PR mantém `develop` intacta. Depois de uma integração
aprovada, reverter o commit da rota e da dependência de identidade em nova
branch, executar os testes e publicar apenas por processo de release aprovado.
