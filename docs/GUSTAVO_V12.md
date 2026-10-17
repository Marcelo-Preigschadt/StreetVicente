# Gustavo · revisão v12

Revisão exclusiva do Gustavo. O problema da v11 era real: `states`, `combat` e `actions` eram ampliados em aproximadamente 12%, e o corpo agachado em `actions` tinha praticamente a altura da guarda em pé. Não era fallback para a folha antiga, mas a desproporção e a diferença de resolução produziam essa impressão.

## Desenhos e proporção

- 64 novos desenhos completos: 16 estados, 8 passos, 8 socos, 8 chutes, 8 golpes baixos, 8 aéreos e 8 quadros de preparação/execução/recuperação dos poderes.
- Rosto, cabelo preso, jaleco, camiseta oliva, jeans e tênis mantidos a partir das referências do personagem. Retrato do menu e vozes preservados.
- Fontes de 1448×1086, 1536×1024 e 1774×887, com 8 quadros por folha. As folhas de 16 poses pequenas da v11 foram substituídas.
- Escalas uniformes em X/Y entre 0,56 e 0,752 na resolução lógica do jogo. Nenhum quadro depende de ampliar os pixels da origem. As folhas são guardadas em WebP lossless, sem deformação do corpo ou composição de rostos.
- Guarda e caminhada têm aproximadamente 300 px. O agachamento e o soco baixo ficam em aproximadamente 217 px, preservando a anatomia; a altura do recorte não determina a escala.
- Agachar e começar/terminar o soco baixo compartilham **o mesmo desenho**, a mesma escala e a mesma raiz. Os quadros intermediários não mudam mais para um corpo maior.
- Fist/boot hitboxes e os sockets de emissão foram registrados novamente sobre os novos desenhos. O chute agora expõe a extensão nos quadros 3 e 4, conforme a nova sequência.

## Poderes preservados, efeitos refeitos

| Comando P1 | Poder | Apresentação v12 |
|---|---|---|
| H | Névoa Atômica | Fumaça comprimida na palma, onda com núcleo e rastro desenhados, expansão e dissipação no contato |
| U | Reação Exotérmica | Compressão do corpo, subida real com punho elevado, crescente de fumaça acompanhando o arco ativo |
| Q | Reação em Cadeia | Formação de fumaça violeta, três ondas da lógica existente, impactos e dissipação próprios |

O novo atlas contém 16 cels de efeitos: onda, impacto, crescente e preparação. A defesa tem contato menor e azulado. O flash genérico foi reduzido **somente nos poderes do Gustavo** para deixar visível a explosão de fumaça. Colisões, custo de barra, dano e comandos dos poderes permanecem os existentes. Os efeitos não decidem acertos e não ampliam o raio de colisão.

## Arquivos e reprodução

- Fontes: `assets/source/gustavo-v12/`.
- Prompts finais, referências e método: [provenance.json](../assets/source/gustavo-v12/provenance.json). Foi usada a ferramenta integrada `image_gen`, com referências de identidade; não houve geração de música.
- Registro revisado de escala, raiz, pés, mãos e colisões: `assets/source/gustavo-v12/registration.json`.
- Sprites consumidos pelo jogo: `assets/characters/gustavo/arcade-v12/`.
- Atlas de efeitos: `assets/effects/gustavo-v12/smoke.webp`.
- Manifestos: `data/characters/gustavo-arcade-v12.json` e `gustavo-effects-v12.json`.
- Apresentador: `scripts/presentation/gustavo_fx_v12.gd`.
- Reempacotamento: `python3 tools/pack_gustavo_v12.py` (Pillow, NumPy, SciPy). Apenas recorte, alpha, disposição em atlas e geometria offline; não inventa quadros intermediários.

## Validação

`bash tools/test.sh` inclui 64.548 verificações de combate/replay sem falhas, além de shell, História, configurações e controles. Novos testes verificam proporção do soco agachado em toda a duração, ausência de ampliação de pixels, contatos nos dois sentidos e emissão da fumaça pela palma desenhada. A cobertura anterior verifica todos os estados/golpes do Gustavo sem retorno ao atlas antigo.

`tests/render_gustavo_v12.gd` captura o jogo real em Compatibility: guarda, agachamento, cada ataque, preparação/execução/recuperação dos três poderes, acerto e defesa. `-- --smoke-only` limita a segunda revisão aos efeitos.

O teste de navegador `tools/smoke_presentation.cjs` usa o teclado no WASM exportado, observa a origem dos quadros e testa S+F, H, U e Q; não altera vida, posições ou relógios por JavaScript. O workflow só publica no Pages após a suíte Web completa.

Os demais personagens, arenas, áudio e mapeamento do João não foram redesenhados nesta revisão. O repositório original não recebe alterações.
