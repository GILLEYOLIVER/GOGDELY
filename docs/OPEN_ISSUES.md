# Pendências críticas

1. Provedor de pagamento: split, recorrência, estornos, chargebacks, conciliação e contratos.
2. Emissão fiscal nacional: documentos por categoria, jurisdição, contingência e responsabilidade.
3. Banco offline e sincronização: compatibilidade, idempotência, ordenação e conflitos.
4. Segurança multiempresa: a primeira verificação de identidade GOG-075 está
   em branch isolada; a consulta de memberships e as políticas RLS de leitura
   estão preparadas em branch de integração, ainda sem aplicação ou teste real
   entre empresas/filiais. Faltam matriz de permissões, escrita auditada e
   isolamento comprovado antes de conectar lojas reais.
5. GPS e mapa: o Cliente local agora solicita a posição sob toque e mostra tiles OpenStreetMap, mas as lojas têm coordenadas fictícias e o ponto escolhido fica só na sessão. Ainda faltam geocodificação, rota, localização do entregador, consentimento/retenção de produção, privacidade e provedor contratado para escala.
6. Impressão: protocolos ESC/POS, USB/rede/Bluetooth, filas e compatibilidade desktop.
7. Testes: metas de cobertura, carga, RPO/RTO e evidências de homologação.
8. Governança: revisores técnicos, proteção de branches e política de aprovação.
9. Identidade: paleta, tipografia, marca e disponibilidade jurídica.
10. Supabase/Render: orçamento, limites, alertas e arquitetura operacional.
11. Convites de lojas (GOG-025/075/082): [ADR-0002](adr/0002-store-onboarding-invitations.md) proposta. O SMTP padrão do Supabase não entrega convites a endereços de lojas fora da organização; provedor externo, custo, MFA Master e fluxo de revogação ainda exigem revisão e aprovação antes de enviar e-mails reais.

Não considerar pendências como decisões resolvidas.

## PWA local do Cliente — validação parcial (14/10/2026)

- O proprietário confirmou tela inicial, criação e acompanhamento de pedido fictício no celular pelo hotspot. Os logs registraram HTTP 200 para PWA/cardápio, HTTP 201 ao criar o pedido #7 e HTTP 200 no acompanhamento a partir do IP do aparelho. Ainda falta homologação visual formal e validação dos demais aplicativos no dispositivo.
- Regra temporária de firewall confirmada em 14/10/2026 para o hotspot `192.168.137.0/24`, IP `192.168.137.1` e portas 8767/8768.
- Revisar acesso aos endpoints locais sem autenticação antes de usar qualquer rede que não seja privada e confiável; somente dados fictícios são permitidos neste piloto.

## Referências visuais do Cliente — validação pendente (14/10/2026)

- Conferir em aparelho a adaptação das telas de início, busca, loja, produto, sacola, revisão e endereço com as 25 capturas fornecidas; a prévia usa a paleta própria azul e grafite.
- Favoritos e endereço digitado persistem somente no armazenamento do PWA instalado neste aparelho; não há conta nem sincronização entre aparelhos, e a persistência ainda requer validação no iPhone. O ponto marcado no mapa não persiste; geocodificação, rotas, cupons e pagamentos externos não estão implementados. O mapa usa tiles reais com lojas fictícias; a geolocalização depende de HTTPS e permissão do aparelho. Os filtros só refletem os dez estabelecimentos fictícios do catálogo local.

## Expansão do laboratório multiloja — validação pendente (14/10/2026)

- Validar no celular a criação de pedidos em pelo menos um restaurante e um estabelecimento de outra categoria, atualização na Gestão e entrega pela prévia do Entregador. Os testes automatizados usam SQLite temporário; ainda não comprovam o fluxo no aparelho do proprietário.
- O seletor de loja da Gestão é somente um controle de demonstração, sem login, tenant ou autorização por empresa. Exigir isolamento, RLS e auditoria de acesso antes de conectar estabelecimentos reais.
- Fotos e cardápios são ilustrativos. Atribuição da foto da Wikimedia em `docs/THIRD_PARTY_NOTICES.md`; revisar todas as mídias e licenças antes de distribuição pública.
