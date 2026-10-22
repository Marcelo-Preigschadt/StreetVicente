# Khauãny v21 — rosto refeito e MMA de contra-ataque

Pedido de 22 de outubro de 2026: reconstruir o rosto pela nova foto e refazer o conjunto inteiro no padrão de movimentos e grandes poderes aprovado na Tais v17. A revisão substitui a identidade desenhada anterior da Khauãny; Dienes continua aguardando sua própria revisão.

## Arte e identidade

- Nova fotografia fornecida pelo usuário como autoridade facial em todas as gerações de corpo e retrato. O arquivo pessoal não é incluído no repositório; seu SHA-256 fica na procedência.
- Rosto oval arredondado, bochechas cheias, nariz largo de ponta arredondada, lábios cheios, olhos castanhos e cabelo preto longo e liso com divisão lateral.
- Figurino preservado: jaqueta preta curta com faixas roxas, top preto, calça cargo preta, corrente lateral, luvas de MMA e botas pretas.
- 88 desenhos completos de corpo produzidos em 11 folhas; 87 desenhos distintos usados. O agachamento compartilha o primeiro quadro da sequência baixa para manter continuidade.
- Retrato novo compartilhado por seleção, HUD e entrada do super. Nenhum recorte de rosto colado sobre os corpos.
- Sprites empacotados sem reamostragem, ampliação, deformação por partes ou interpolação inventada. Registro revisado de quadril, sola projetada, pontos de emissão e contatos. Uma escala anatômica fixa por sequência.

## Movimento e poderes

MMA de contra-ataque: esquiva e soco por cima da guarda, chute circular, soco baixo, varrida, martelo e chute aéreos, cotovelada ascendente e queda por gancho externo. A caminhada desloca o corpo inteiro também em profundidade no modo História.

| Comando | Poder preservado | Apresentação v21 |
| --- | --- | --- |
| H | Chuva de Garfos | Leque de garfos prateados, frente de 350 × 280 px, rastro nas posições anteriores e explosão própria |
| U | Contra-ataque Ascendente | Cotovelada com salto físico e arco ascendente de garfos de 360 × 465 px |
| Q | Banquete de Garfos | Cinco ondas com alternância de palmas, frente de 570 × 470 px e impacto de 650 × 540 px |

24 cels VFX: carga, rajada, arco ascendente, impacto comum, tempestade e impacto do super. Frentes e rastros ficam abaixo dos atores para conservar a leitura dos rostos. Os núcleos densos de H/Q têm raios de contato de 64/150 px; rastros e coroas de impacto não causam contato extra. Dano, velocidade, cinco ondas, custo de 100 do super, nomes, comandos e áudios PT-BR seguem o catálogo original.

## Fontes e verificação

Fontes, prompts e procedência: `assets/source/khauany-v21/`. Ferramenta: ImageGen integrado, modo padrão. Referência antiga usada somente para figurino; a nova foto prevalece para identidade.

Empacotamento reproduzível: `python tools/pack_khauany_v21.py`. Dados de quadros e contatos: `data/characters/khauany-arcade-v21.json`; efeitos: `data/characters/khauany-effects-v21.json`.

Verificações obrigatórias: `bash tools/test.sh`, `bash tools/export_web.sh` e `node tools/smoke_khauany.cjs`. A verificação Web usa somente teclado real e observações imutáveis: identidade v21, escala baixa, H/Q com projéteis e bloqueio, cinco ondas, cotovelada aérea, dano, gasto da barra e caminhada em profundidade. A suíte completa continua obrigatória antes de publicar via Pages.
