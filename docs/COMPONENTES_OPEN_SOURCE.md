# Catálogo de componentes candidatos

**Nenhuma dependência foi incorporada, instalada ou homologada.**

| Módulo | Projeto | Licença identificada | Decisão |
|---|---|---|---|
| Mapas Flutter | https://github.com/fleaflet/flutter_map | BSD-3-Clause | Avaliar tiles, atribuição e custos |
| Leitura QR Code | https://github.com/juliansteenbakker/mobile_scanner | BSD-3-Clause | Testar Android/iOS |
| Backend | https://github.com/fastapi/full-stack-fastapi-template | MIT | Referência parcial: frontend React não atende à escolha Flutter |
| Impressão térmica | https://github.com/wwandreww/esc_pos_printer | Licença permissiva com condições | Verificar suporte Windows/macOS e manutenção |
| PDV/estoque | https://github.com/opensourcepos/opensourcepos | MIT | Referência; não copiar o sistema inteiro |
| Banco offline | https://github.com/isar/isar | Apache-2.0 | Apenas candidato; comparar alternativas conforme GOG-078 |

## Componentes rejeitados

| Módulo | Projeto | Decisão e motivo |
|---|---|---|
| Pagamentos (GOG-055/056/057/068) | https://github.com/youpi-pg/YouPI-PG | **Rejeitado pelo proprietário em 19/10/2026. Não instalar, incorporar, copiar código nem usar como integração do GOGDELY.** O projeto atende UPI/INR, não Pix/BRL; confirma créditos por observação de SMS/notificações/e-mails bancários e não oferece o split de comissões exigido. O `package.json` declara licença `Commercial`, enquanto o arquivo `LICENSE` referido pelo README não estava disponível na revisão. Avaliação do commit `6c82cfb`; a seleção do provedor Pix continua pendente. |

## Admissão de componentes
Verificar licença e avisos da versão exata, manutenção, vulnerabilidades, compatibilidade, protótipo isolado, testes e aprovação técnica antes da incorporação. Registrar origem, versão e obrigações de atribuição.
