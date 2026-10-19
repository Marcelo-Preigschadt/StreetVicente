> Histórico: o conjunto de rostos desta revisão foi substituído. Use [Marcelino V15](MARCELINO_V15.md) e o novo empacotador.

# Marcelino v14 e correção do Aú do Gelton

## Personagem revisado nesta etapa

Marcelino é o próximo personagem após Gustavo e Gelton. A revisão mantém o
retrato, cabelo grisalho, óculos, rosto, camiseta branca, calça azul com faixa
laranja, bandagens, pés descalços, vozes, estilo Muay Thai e poderes originais.

Foram desenhados 64 cels completos de corpo inteiro. A guarda agachada usa o
mesmo desenho no estado parado e no início/fim do soco baixo: 63 desenhos
distintos são consumidos no jogo, além das exposições repetidas por frame data.
Os atlas cobrem guarda, shuffle, defesa alta/baixa, salto, aterrissagem, reações,
tontura, queda, vitória, soco, chute, golpes baixos/aéreos e poderes. Nenhum desses
estados depende do atlas antigo durante o combate normal. F4 mantém a comparação
intencional com o original.

A arte é animação 2D de corpo inteiro. Não há cabeça recortada aplicada a peças,
modelo 3D, deformação de membros ou ampliação de pixels pequenos. As fontes são
preservadas sem perdas e empacotadas sem redimensionamento. A escala de renderização
fica abaixo de 1. Cabeças e membros foram registrados por anatomia: uma pose
agachada ou no ar não é normalizada à altura da guarda.

## Poderes e frame data preservados

| Comando | Poder | Startup / active / recovery (60 fps) | Apresentação |
|---|---|---|---|
| H | Impulso Linear | 15 / 1 / 25 | Preparação nas mãos, frente de pressão e rastro |
| U | Joelhada Cinética | 6 / 14 / 29 | Compressão, joelho ascendente, subida e aterrissagem |
| Q | Lei da Ação e Reação | 11 / 40 / 27 | Cinco impulsos, com cadência de dez ticks |

O motor executa dois ticks de simulação para cada frame de dados. Permanecem
inalterados dano, custo de barra, velocidade, vozes e nomes dos poderes.
Os efeitos usam 16 cels próprios de energia cinética em ciano/âmbar: impulso,
impacto, crescente da joelhada e concentração/liberação. Acerto e defesa têm
reações diferentes. O núcleo do projétil acompanha a colisão real; os rastros
são decorativos. Os poderes partem do ponto das mãos ou do joelho registrado
no desenho atual, inclusive com o personagem espelhado.

## Gelton

Corrigida a escala do atlas do Aú das Cores de 0,63 para 0,85. As fontes continuam
sem reamostragem e as caixas/pontos acompanham a correção. A pose de descida antes
ficava em torno de 73% da altura da guarda; agora mantém o porte adulto. O teste
cobre preparação, descida e aterrissagem, e o teste Web observa a descida real.

## Arquivos e reprodução

- `assets/source/marcelino-v14/`: fontes, referências, prompts e proveniência.
- `assets/source/marcelino-v14/registration.json`: raízes, apoios, escala, áreas de golpe e pontos dos efeitos em coordenadas da fonte.
- `tools/pack_marcelino_v14.py`: empacotamento reprodutível e geração das hurtboxes por faixas de alfa.
- `assets/characters/marcelino/arcade-v14/`: atlas consumidos pelo jogo.
- `assets/effects/marcelino-v14/kinetic.webp`: efeitos animados.
- `scripts/presentation/marcelino_fx_v14.gd`: apresentação sem mutações na simulação.
- `tests/marcelino_v14.gd`: proporção, cobertura de estados, contatos nos dois lados, fase ativa, origem dos poderes, cinco ondas, acerto e defesa.
- `tests/render_marcelino_v14.gd`: capturas reais do renderizador Compatibility.
- `tools/smoke_marcelino.cjs`: seleção e comandos reais de teclado no WASM; `svfQA` serve somente para observação.

```bash
python3 tools/pack_marcelino_v14.py
bash tools/test.sh
bash tools/export_web.sh
npm ci
npx playwright install --with-deps chromium
npm run test:web
```

A publicação continua usando exportação Web sem threads e GitHub Actions; o deploy
só é liberado se as suítes passarem. O repositório Canvas original permanece intacto.
Os demais personagens serão revisados individualmente; esta etapa não redesenha
o restante do elenco nem implementa rollback online.
