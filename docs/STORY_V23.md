# História V23

Base de campanha revisada: inimigos animados por deslocamento e fases reais de ataque; móveis organizados em áreas de assentos; perspectiva e profundidade comuns aos personagens, poderes e objetos.

## Combate

- Campanha solo e cooperativa começam com energia zero.
- H e U custam 25; Z custa 40; Q custa 100. Socos e chutes continuam livres.
- Contatos de golpes normais e impactos recebidos carregam a barra. Poderes não devolvem energia pelos próprios acertos. Não existe recarga passiva.
- Contra máquinas baixas, o golpe normal usa a pose de ataque baixo aprovada, com contato na altura do inimigo.
- A formação e o recuo de cada inimigo ficam dentro da área de combate da onda; não deixam uma máquina fora do alcance atrás da barreira de progressão.
- Custos, energia, objetos e movimento continuam serializados para save/load e rollback. Versus mantém seus custos anteriores.

## Objetos e apresentação

- Dois conjuntos de mesas e cadeiras ficam afastados da faixa principal de combate; a máquina de refrigerante fica junto à parede.
- Móveis têm pegada no piso, sombra e ordenação pela faixa de profundidade. Personagens e poderes usam a mesma projeção.
- O panorama conserva sua proporção original.
- E pega o móvel próximo; F/E arremessa. Há uma sequência de abaixar, levantar, segurar e liberar na fase ativa. A pega acompanha a mão do quadro aprovado.
- O móvel conserva seu tamanho entre chão, mão e voo. A trajetória é balística e o chão usa a base do objeto.
- Levantar é interrompido quando o personagem recebe um golpe; não concede invulnerabilidade.
- Rostos, retratos e atlas aprovados dos lutadores não foram redesenhados.

## Arte

Ferramenta: `image_gen.imagegen`, modo integrado, com referência ao robô original e transparência. Os prompts completos estão em [story-v23-image-prompts.json](story-v23-image-prompts.json). O empacotamento apenas codifica WebP e registra as células e suas bases alfa; não inventa ou interpola poses.

Arquivos finais:

- `assets/story/v23/snack.webp`
- `assets/story/v23/turnstile.webp`
- `assets/story/v23/cleaner.webp`
- `assets/story/v23/vial.webp`
- `assets/story/v23/scanner.webp`
- `assets/story/v23/book.webp`
- `assets/story/v23/projector.webp`

Metadados, escalas, sequências e hashes das fontes: `data/story/enemy-animation-v23.json`. Cada novo atlas tem 16 quadros; os atlas existentes dos outros inimigos passam pelo mesmo seletor de caminhada, preparação, contato, recuperação, impacto e queda. O empacotador é `tools/pack_story_v23.py`.

## Validação

Regressões nativas cobrem energia, contato real, custos de Versus, levantamento, liberação na fase ativa, trajetória e save/load dos móveis, todos os atlas e a regra compartilhada do cooperativo. O teste de navegador `tools/smoke_story_v23.cjs` usa exclusivamente teclado normal e observações de leitura: batalha, energia, mesas e cadeiras.

O protocolo de salas é `svf-godot-v23`, para que clientes de revisões com regras diferentes não entrem na mesma simulação. Nenhuma alteração de esquema do backend foi necessária.
