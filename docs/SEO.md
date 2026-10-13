# SEO.md — Preparação técnica das páginas públicas GOGDELY

**Atualizado em:** 13/10/2026. **Escopo:** páginas web públicas do piloto local (cardápios de mesa servidos pela API) e shells web Flutter. **Sem domínio público, deploy ou conta externa existente** — tudo abaixo está pronto para o futuro hospedagem, ativado por configuração de ambiente e aprovado pelo proprietário.

## Princípio de proteção

Nada é indexável no laboratório: sem `GOGDELY_PUBLIC_BASE_URL`, `robots.txt` bloqueia tudo (`Disallow: /`), o sitemap fica vazio e toda página carrega `noindex, nofollow`. Páginas **privadas** (recibo do pedido, ficha de impressão, painel Master web) permanecem `noindex` **permanentemente**, mesmo no modo público. Isto atende à regra "preservar a proteção das páginas privadas" sem expor nada antes da autorização.

## Checklist — status dos 20 itens

### Eliminar
1. **noindex indevido removido**: o cardápio de mesa (única página pública real) torna-se `index, follow` automaticamente quando `GOGDELY_PUBLIC_BASE_URL` é configurado; recibo/ficha/Master web continuam protegidos.
2. **Links quebrados**: auditados na ficha de impressão, recibo e cardápio; o recibo ganhou link interno "Voltar ao cardápio da mesa"; ficha e QR apontam ao slug limpo; verificado por testes.

### Implementar e otimizar
1. **Meta títulos**: `Cardápio Burger House · Mesa MXX · GOGDELY` (API) e títulos descritivos nos index.html de Cliente/Master.
2. **Meta descrições**: em todas as páginas via template `_html_page` (local_orders.py) e nos shells web.
3. **Alt em imagens**: `alt="{produto}"` (era vazio), com `width`/`height`, `loading="lazy"` e `decoding="async"` (anti-CLS).
4. **Core Web Vitals**: CSS inline mínimo, `system-ui` (sem webfont), dimensões explícitas nas imagens, viewport, zero JS no cardápio; HTTPS/HSTS no modo produção.
5. **Sitemap.xml**: `GET /sitemap.xml` dinâmico — vazio no lab; lista os 10 cardápios de mesa (M01–M10) no modo público.
6. **og:image**: PNG 1200×630 gerado em `scripts/generate_og_image.py` (azul #2563EB + grafite #151B2B, 3 KB), servido em `/og-image.png` e pronto em `apps/cliente/web/og-image.png`. **A arte final depende da identidade visual (GOG-088 pendente).**
7. **Hierarquia de headings**: 1 `h1` (marca) por página, `h2` nas seções, produtos em `strong` — testado (`page.count("<h1>") == 1`).
8. **Backlinks**: estratégia documentada — QRs físicos nas mesas do piloto (offline→online), parcerias com as até 10 empresas piloto (GOG-124), diretórios locais e imprensa regional na expansão. **Execução depende de marketing/relacionamento externo.**
9. **Slugs limpos**: rota pública `/m/burger-house/{mesa}`; QR, ficha e links internos usam o slug; URL longa anterior continua válida (compatibilidade).
10. **Links internos**: recibo→cardápio, ficha→cardápio, sitemap→cardápios; cobertos por testes de integração.
11. **Tags canônicas**: `<link rel="canonical">` absoluto por página, emitido somente no modo público (evita canônicas para localhost).
12. **HTTPS obrigatório em produção**: middleware 308 http→https + HSTS `max-age=31536000` quando `GOGDELY_REQUIRE_HTTPS=1` (padrão em `GOGDELY_ENV=production`), respeitando `X-Forwarded-Proto` do proxy (Render); `render.yaml` já declara HTTPS na borda.
13. **Compressão de imagens**: upload limitado a 5 MB (PNG/JPEG/WebP), cache `immutable` no og-image, PNG placeholder 3 KB; compressão na borda de hospedagem fica a cargo do proxy quando implantado.
14. **Schema markup**: JSON-LD `MenuSection`/`Menu`/`MenuItem` com preços em BRL no cardápio (modo público).
15. **Google Search Console**: `GET /google{token}.html` serve a verificação quando `GOGDELY_GSC_VERIFICATION` é configurado pelo proprietário. **A verificação real exige domínio e conta Google (externo).**
16. **1 H1 por página**: garantido pelo template e testado.
17. **Robots.txt**: `GET /robots.txt` dinâmico — lab: bloqueia tudo; público: permite `/m/`, bloqueia `/api/` e `/docs`, anuncia o sitemap.
18. **Responsividade mobile**: viewport + CSS mobile-first já usados nas páginas de mesa e shells; validação visual em dispositivos é pendência de homologação (GOG-099).

## Dependências de configuração externa (não executáveis agora)

- Domínio público + DNS apontando para a hospedagem aprovada (GOG-085/GOG-117).
- `GOGDELY_PUBLIC_BASE_URL`, `GOGDELY_GSC_VERIFICATION` e hospedagem ativa (Render ou equivalente) — via secrets do painel, nunca no Git.
- Conta Google Search Console e propriedade verificada com o token.
- Arte final do og:image e identidade visual (GOG-088); execução da estratégia de backlinks.

## Verificações executadas

`pytest services/api/tests` — 28 aprovados (7 novos em `test_web_seo.py`: proteção do lab, metadados do cardápio, privacidade de recibo/ficha, modo público com canonical/OG/JSON-LD/sitemap, verificação GSC, redirecionamento HTTPS, QR apontando ao slug). Análise Dart inalterada (nenhuma mudança em código Dart nesta tarefa).
