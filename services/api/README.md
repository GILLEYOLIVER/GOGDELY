# GOGDELY API — bootstrap

**Estado:** API executável mínima em ambiente local e de homologação. O Render
expõe `/health`, `/ready` e `/version.json`; esta branch também verifica
identidade no Supabase Auth. Esta branch prepara a leitura de vínculos entre
usuário, empresa e filial com RLS; a migration ainda não foi aplicada. Não há
pedidos ou pagamentos em nuvem.

O fluxo de pedidos abaixo permanece uma demonstração local persistida em
SQLite. Não representa pedidos, pagamentos nem autorização de produção.

## Teste integrado local dos três aplicativos

Abra a raiz `C:\Projetos\GOGDELY` no VS Code, escolha **GOGDELY • Cliente + Gestão + Entregador (F5)** em Executar e Depurar e pressione F5. A API inicia em `127.0.0.1:8765`, Gestão e Entregador abrem pelos executáveis Windows já compilados, e o Cliente abre sob depuração. A API usa `GOGDELY_LOCAL_DEMO=1`, `GOGDELY_ENV=local` e cria `services/api/.local/gogdely.sqlite3`; o diretório é ignorado pelo Git. O antigo endpoint de bootstrap na porta 8000 continua independente.

No Cliente, adicione um produto e use **Salvar pedido no banco local** no checkout. Em Gestão, abra **Pedidos** ou **KDS** e avance **Iniciar preparo** → **Marcar pronto**. No Entregador, abra **Entregas** e avance **Iniciar entrega local** → **Concluir entrega local**. O Cliente atualiza automaticamente o acompanhamento e o histórico; Gestão e Entregador também atualizam suas listas automaticamente a cada 3 segundos nas telas relevantes. Os botões de atualização manual continuam disponíveis. Trata-se de consulta periódica à API local, não de push em tempo real nem de conexão com produção.

No piloto Burger House, o Cliente pode cancelar o pedido antes do preparo e a Gestão pode cancelar até a etapa **Em preparo**, sempre informando o motivo. A opção **Ver histórico** mostra as mudanças gravadas no SQLite com data, responsável informado e motivo. Pedidos antigos não ganham eventos retroativos. O campo de responsável ainda é apenas demonstrativo, sem login/autorização real. Não há estorno nem pagamento.

No checkout local do Cliente, **Receber no endereço** mantém a taxa demonstrativa e segue para o Entregador. **Retirar na Burger House** salva o pedido sem frete; a Gestão acompanha o preparo e marca **Entregar na loja** quando o cliente retira. Esse pedido não aparece no app Entregador. O endereço de retirada ainda é apenas o nome fictício da loja.

A forma de pagamento escolhida no checkout (dinheiro, Pix ou cartão) é gravada apenas como preferência no pedido de demonstração. Cliente e Gestão exibem **pagamento não processado**; a API não tem operação para marcar como pago nem aceita dados de cartão. Pedidos anteriores à atualização aparecem como **Não escolhido**.

Em **Configurações** da Gestão, escolha as formas aceitas pela Burger House e clique em **Salvar formas de pagamento**. O Cliente consulta essas opções no checkout e a API recusa pedidos novos com opções desativadas. A configuração fica apenas no SQLite local e não possui autenticação operacional; mantenha este recurso no ambiente de demonstração.

Pedidos de retirada mostram ao Cliente um código local de seis dígitos. Quando o pedido estiver pronto, a Gestão solicita esse código antes de marcar **Entregar na loja**. O código é uma conferência demonstrativa, não autentica pessoas e não autoriza qualquer transação financeira.

No editor do cardápio da Gestão, as setas movem produtos para cima ou para baixo. A ordem é salva no SQLite e reaparece no cardápio do Cliente; a API exige todos os códigos de produto exatamente uma vez para evitar sumiço acidental.

O botão **Histórico** do editor mostra as últimas 50 mudanças locais de produtos (criação, edição e ordem), com valores anteriores e posteriores. O registro começa com este recurso e usa o ator fixo “Gestão local”: ainda não identifica funcionários nem substitui auditoria com autorização.

Em **Cardápio**, a Gestão pode informar um saldo opcional em unidades para cada produto; campo vazio mantém o produto sem limite local. A página **Estoque** mostra os saldos do SQLite e atualiza periodicamente. Cada pedido novo reserva as unidades configuradas no mesmo registro transacional do pedido; a API rejeita quantidade acima do saldo. Um cancelamento permitido repõe somente o que aquele pedido baixou, uma vez. Produto esgotado sai da vitrine e do QR de mesa.

Para uma ficha técnica simples, cadastre ingredientes em **Estoque** com código, nome, unidade (`un`, `g` ou `ml`) e saldo inteiro. Em **Cardápio**, edite um produto e informe uma linha por ingrediente no formato `codigo; quantidade` (ex.: `carne; 180` para 180 g por unidade). Um pedido reserva conjuntamente os saldos do produto e dos ingredientes; se qualquer saldo for insuficiente, a transação inteira é desfeita. Cancelamentos permitidos repõem somente o que foi reservado naquele pedido. Produtos antigos ficam sem receita até edição explícita. A unidade de um ingrediente cadastrado não muda; conversões, conferência física e autenticação ainda não existem.

Em **Estoque**, use **Ajustar saldo** para registrar entrada, perda ou contagem manual com motivo. A contagem inicia o controle de um produto antes ilimitado. **Movimentos** mostra os últimos 100 registros, incluindo baixa por pedido e reposição por cancelamento; movimentos anteriores à implantação deste histórico não são reconstruídos. A API local expõe `POST /api/v1/local/stores/burger-house/stock-adjustments` e `GET /api/v1/local/stores/burger-house/stock-movements`. Não há compras, custos ou integração contábil.

O **PDV** da Gestão usa `POST /api/v1/local/stores/burger-house/pos-sales` para criar pedidos de balcão sem frete. O preço vem do cardápio salvo; baixa de estoque, idempotência e histórico de pedidos usam a mesma transação dos demais canais. A forma de pagamento é apenas pretendida e `payment_status` permanece `not_processed`. O pedido segue para Pedidos/KDS e pode terminar como `served` pela Gestão. O painel **Caixa local** usa `/api/v1/local/stores/burger-house/pos-register` para consultar a sessão aberta e os fechamentos recentes; os subcaminhos `/open`, `/movements` e `/close` registram abertura, suprimento ou sangria, e fechamento manual no SQLite. O fechamento calcula a diferença entre o valor contado e o saldo esperado apenas a partir das declarações do caixa. Pedidos e pagamentos não alimentam esse saldo automaticamente; não há confirmação de recebimento, conciliação financeira ou controle de acesso por operador.

O KDS da Burger House pode ajustar a prioridade de pedidos novos ou em preparo por `PUT /api/v1/local/orders/{order_id}/kitchen-priority`, com `priority` (`normal` ou `urgent`) e `reason`. A mudança fica no pedido e no histórico local; não altera o estado do pedido nem representa autorização de operador real.

O endpoint `POST /api/v1/local/orders/{order_id}/simulate-payment` registra uma **declaração de pagamento simulado** do laboratório: exige `request_key` (idempotente; reutilizada no mesmo pedido devolve o pedido, em outro pedido é rejeitada) e motivo com pelo menos três caracteres. O pedido passa a expor `payment_status: "simulated"` e `payment_settlement: "simulated_local"`, a declaração fica na tabela `demo_order_payments` e o motivo entra no histórico do pedido. Cancelados, pedidos sem método escolhido e pedidos já simulados são rejeitados. **Nenhum provedor é acionado, nada é cobrado ou transferido, e isso nunca representa liquidação financeira real.**

Pedidos de entrega/retirada aceitam `scheduled_for` (ISO 8601) para agendamento (GOG-024): a API exige horário entre 30 minutos e 14 dias à frente, grava `scheduled_for` no pedido e registra "Pedido agendado para ..." no histórico. Pedidos concluídos podem receber uma avaliação de 1 a 5 estrelas com comentário por `POST /api/v1/local/orders/{order_id}/rating` (uma por pedido, apenas entregue/servido/retirado) e `GET /api/v1/local/stores/burger-house/ratings` devolve média, contagem e últimas avaliações (GOG-022).

O Master consome `/api/v1/local/master/overview`, `/companies`, `/plans`, `/companies/{store_id}/approval` (aprovação/recusa simulada com motivo, auditada) e `/audit`, que consolida eventos de pedidos, cardápio, pagamentos simulados, estoque, caixa e aprovações do SQLite local. Tudo é fictício: não há autenticação, MFA real ou tenant.

As páginas de mesa agora são SEO-prontas ([docs/SEO.md](../docs/SEO.md)): slug público `/m/burger-house/{mesa}` (usado pelo QR e pelos links internos), metadados completos (título, descrição, Open Graph, canonical e JSON-LD de cardápio **somente** quando `GOGDELY_PUBLIC_BASE_URL` é configurado), `robots.txt` e `sitemap.xml` dinâmicos (bloqueiam tudo no laboratório e anunciam os cardápios no modo público), verificação do Google Search Console via `GOGDELY_GSC_VERIFICATION` e HTTPS obrigatório em produção via `GOGDELY_REQUIRE_HTTPS` com HSTS. Recibos e fichas de impressão permanecem `noindex` permanentemente.

## Acessar o QR de mesa pelo celular na mesma rede (LAN)

O perfil F5 **GOGDELY API • Banco local na rede (LAN)** sobe a mesma API em `0.0.0.0:8765`, permitindo abrir os cardápios de QR no navegador do celular:

1. Inicie o perfil LAN (ele substitui o perfil local padrão enquanto estiver ativo).
2. Descubra o IP do computador na rede (ex.: `ipconfig` → `192.168.0.10`).
3. No navegador do celular, abra `http://192.168.0.10:8765/m/burger-house/M01` — o pedido vai para a mesma fila/KDS da Gestão.
4. Para gerar QRs que funcionem no celular, abra a ficha de impressão **pelo IP da rede** (`http://192.168.0.10:8765/api/v1/local/tables/burger-house/M01/print`); o QR codifica o host usado na requisição.

**Segurança:** o servidor na LAN expõe apenas dados fictícios do SQLite local; autorize no Firewall somente rede privada, nunca exponha à internet e encerre o perfil após o teste. A API local não tem autenticação — por isso o limite de rede doméstica/escritório.

Para hospedagem futura, a API lê configuração de ambiente em [gogdely_api/config.py](gogdely_api/config.py) (`GOGDELY_ENV`, `GOGDELY_DATABASE_URL`, `GOGDELY_CORS_ORIGINS`), há `Dockerfile` e modelo `render.yaml` (sem implantação) e a migration de referência para banco gerenciado com `tenant_id` e RLS está em [database/migrations/0001_foundation.sql](../database/migrations/0001_foundation.sql). Segredos nunca ficam no repositório.

Para uma entrega nova, a Gestão marca o pedido como **Pronto** e depois usa **Enviar ao Entregador**. Só então o pedido aparece no app Entregador e pode iniciar a rota local. O Cliente vê quando a loja o encaminhou. Pedidos de entrega já existentes mantêm a disponibilidade anterior; esta etapa não atribui uma pessoa específica nem aciona parceiros externos.

Quando o pedido entra **Em entrega**, o Cliente vê um código local de seis dígitos. Ao receber o pedido, informa o código ao Entregador; o app exige esse código para marcar **Entregue**. A API rejeita código ausente ou incorreto. É somente uma conferência do laboratório: a API local não autentica usuários nem mantém esse código secreto entre papéis, e o fluxo não comprova a entrega física.

Para testar pedidos de mesa, abra **Mesas QR** na Gestão e copie o link da ficha de M01. Cole no navegador **deste computador** para ver/imprimir o QR, ou copie o link do cardápio para abrir a página HTML diretamente. Escolha quantidades e envie: o pedido aparece em **Pedidos/KDS**, com mesa, número e horário, sem taxa de entrega. A Gestão pode marcá-lo como **servido**. A API do F5 escuta apenas em `127.0.0.1`; o QR impresso ainda não abre no celular de outra máquina. Acesso pela rede, autenticação operacional e homologação do uso em mesas reais são etapas posteriores.

O editor da Gestão aceita fotos PNG/JPEG/WebP de até 5 MB. O upload fica apenas em `services/api/.local/uploads`; a API rejeita formatos não permitidos e usa o cardápio SQLite como autoridade para adicionais e preços. O Cliente e a página da mesa exibem essas fotos e adicionais. Não envie dados reais para este laboratório.

Para testar só a API, a partir de `services/api`:

```powershell
$env:GOGDELY_ENV='local'
$env:GOGDELY_LOCAL_DEMO='1'
.\.venv\Scripts\python.exe -m uvicorn gogdely_api.main:app --host 127.0.0.1 --port 8765
```

Em outro terminal, dentro de `apps/cliente`, execute `dart run tool/local_api_smoke.dart`. O teste cria apenas pedidos fictícios. `pytest` usa outro SQLite temporário e não modifica o banco de demonstração. Sem a variável `GOGDELY_LOCAL_DEMO=1`, as rotas locais retornam 404.
## Requisitos
Python 3.11+ no Windows.

## Executar localmente
No PowerShell, a partir da pasta `services/api`:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[test]"
.\.venv\Scripts\python.exe -m uvicorn gogdely_api.main:app --reload --host 127.0.0.1 --port 8000
```

Abrir `http://127.0.0.1:8000/docs` ou `http://127.0.0.1:8000/health`.

## Identidade Supabase (GOG-075, issue #37)

Configure `GOGDELY_SUPABASE_URL` com o endereço HTTPS do projeto
`*.supabase.co` e `GOGDELY_SUPABASE_PUBLISHABLE_KEY` **somente no servidor**.
`GET /api/v1/auth/me` exige `Authorization: Bearer <access_token>`, consulta
diretamente `/auth/v1/user` no Supabase Auth e devolve apenas o UUID confirmado.
O token não é decodificado localmente. Sem configuração, com token inválido ou
com Auth indisponível, o endpoint falha fechado. Não usa chave administrativa.

Esta etapa não autoriza acesso a loja, filial, pedido ou dados privados. A
próxima etapa precisa consultar vínculos confiáveis no banco e testar RLS entre
empresas antes de habilitar endpoints de negócio. Consulte
[`docs/AUTH_IDENTITY.md`](../../docs/AUTH_IDENTITY.md).

## Vínculos de empresa e filial — GOG-074

`GET /api/v1/auth/memberships` usa a identidade verificada e uma consulta
PostgreSQL transacional sob o papel `authenticated`. A migration de políticas
de leitura está em [`0002_membership_read_policies.sql`](../../database/migrations/0002_membership_read_policies.sql).
O fluxo, as verificações necessárias em homologação e a reversão estão em
[`docs/ONLINE_TENANCY.md`](../../docs/ONLINE_TENANCY.md). Até a revisão
independente e o teste real de isolamento, o endpoint não deve ser implantado.

## Testar
```powershell
.\.venv\Scripts\python.exe -m pytest
```

## Verificações de publicação

- `/health` verifica somente o processo.
- `/ready` aceita `GOGDELY_DATABASE_URL` ou as variáveis separadas `GOGDELY_DATABASE_HOST`, `GOGDELY_DATABASE_USER`, `GOGDELY_DATABASE_PASSWORD`, `GOGDELY_DATABASE_PORT` (padrão 5432) e `GOGDELY_DATABASE_NAME` (padrão postgres). A senha separada é codificada na URL internamente, inclusive quando contém caracteres especiais. Exige TLS com validação de certificado e oito tabelas `gogdely` com RLS forçado. Responde 503 sem banco ou esquema; não divulga a URL ou exceções de conexão. A CA pública oficial do Supabase está empacotada em `gogdely_api/certs/prod-ca-2021.crt` (SHA-256 `700723581420DD1AC98FD7E9AC529F0EF210EADCAF87FC868A3AD7D114C2F3B7`); a verificação de hostname permanece ativa.
- No host `*.pooler.supabase.com`, a checagem de prontidão remove apenas `VERIFY_X509_STRICT` porque a CA intermediária atualmente servida pelo pooler não contém a extensão Key Usage (erro OpenSSL 92 no Python recente). A confiança na CA, a validação da cadeia e do hostname continuam obrigatórias. Revisar e retirar esta exceção quando o certificado do pooler for corrigido; não a aplicar a outros hosts.
- Em caso de 503, os logs do servidor registram somente a etapa da falha, a classe da exceção ou o SQLSTATE validado. Mensagens de erro do driver, URL e segredos não são registrados.
- `/version.json` mostra somente o SHA fornecido por `RENDER_GIT_COMMIT`, com `Cache-Control: no-store`.

## Limites
Não utilizar em produção. `/ready` verifica apenas a fundação do banco, não autenticação, permissões, Storage ou fluxos de negócio. A migração inicial do esquema Supabase é bloqueada por RLS e não concede acesso à API. A dependência pg8000 (BSD-3-Clause) e sua árvore transitiva exigem revisão de licença e segurança antes de produção. Dependências exigem lockfile e revisão antes de produção. A autorização multiempresa no servidor virá em tarefa própria.
