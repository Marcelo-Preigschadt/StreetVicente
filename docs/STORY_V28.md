# História v28 — escala, ambientes e combate

Os guardas da revisão anterior tinham 250–285 unidades de altura, enquanto os
jogadores usam aproximadamente 300–320. Agora os guardas têm 340–370, os chefes
425–480 e os drones 155–170. Desenho, hurtbox, alcance de agarrão, origem dos
disparos e distância do ciclo de passos acompanham essa escala. A escala é
uniforme no atlas; os desenhos dos jogadores permanecem os mesmos.

## Ambientes

Foram criados 36 objetos pintados, organizados por ambiente:

- Pátio/cantina: armários, bancos, lixeiras, plantas, carrinho de refeições,
  vitrine de troféus, mural, cadeiras empilhadas e barreira de serviço.
- Química: armário de segurança, cilindros, carrinho, bancada, lava-olhos,
  caixa de reagentes, instrumentos, ventilação e sinalização.
- Biblioteca: estante, carrinho de livros, mesa de leitura, esfera armilar,
  caixas de arquivo, globo, púlpito, busto e pilha de livros.
- NIT: rack, bancada de manutenção, carrinho de ferramentas, UPS, monitores,
  gabinete de rede, carretel de cabo, peças e ventilação.

Os quatro atos têm 43 objetos físicos e 56 elementos de composição. Móveis de
trabalho ocupam a faixa posterior, com passagem frontal contínua. Elementos de
parede e de primeiro plano compõem os ambientes sem criar colisões invisíveis.
Todos usam a projeção e a ordenação de profundidade da fase. LEDs de equipamento
têm atividade visual. As pinturas existentes de fundo foram mantidas.

## Objetos e comandos

F/G atingem móveis diretamente no quadro ativo. O contato considera o segmento
do braço ou da perna até a caixa desenhada, preservando altura, direção e faixa
de profundidade. Não há dano em móveis distantes ou atrás do personagem.

A altura de contato é comparada no plano do ator; a profundidade é verificada
separadamente. Pequenos desvios de profundidade não fazem o chute passar abaixo
dos pés da cadeira.

Em móveis baixos, F usa os golpes baixos já desenhados do personagem, alternando
as variantes. Isso evita que um soco passando acima do tampo cause dano fictício.
Chutes comuns lançam cadeiras; socos e chutes quebram outros móveis. O E continua
como atalho opcional, sem recuo ou alinhamento comandado. Inimigos em alcance de
agarrão têm prioridade sobre móveis próximos. O ganho de energia continua ligado
ao combate com inimigos.

## Combate

Os robôs ganharam 32 desenhos adicionais: chute frontal, rasteira, golpe de cima,
guarda, investida e esquiva. Os tipos de guarda alternam ataques com preparação,
altura, alcance e recuperação diferentes. Os batedores podem sair de linha;
sentinelas defendem por uma janela limitada; o segundo atacante pode flanquear
por outra profundidade. Atiradores recuam, reposicionam e alternam disparos e
rajadas. Recuar não concede defesa automática aos robôs.

Os ataques leves dos robôs têm preparação de 367 ms e recuperação de 333 ms.
A reação defensiva começa após 150 ms de ameaça visível; golpes rápidos têm
mais chance de conectar antes da esquiva. Agarrões de chefes têm 600 ms de
preparação e investidas 667 ms, com recuperação suficiente para contra-atacar.
As animações usam essas fases reais, sem alterar a velocidade dos jogadores.

A biblioteca combina sentinelas terrestres e drones, substituindo a composição
anterior inteiramente formada por atiradores.

O número de ataques simultâneos acompanha o número de jogadores ativos. Após
um golpe recebido, a proteção cobre a reação e mais 18 ticks (150 ms) para agir.
A regra é exclusiva da campanha; o versus conserva seus combos.

Os combos do jogador conservam os desenhos aprovados. F,F,G antecipa o
finalizador; um contato permite salto durante a recuperação. A entrada tem uma
janela de encadeamento maior e os golpes têm pequeno avanço físico, limitado
pelas colisões. As investidas também respeitam móveis.

## Persistência e validação

Móveis novos têm chaves estáveis. Saves anteriores recebem as novas posições
sem duplicação ao salvar e carregar novamente. Estado de tática, tiros,
destruição e combos participa do snapshot determinístico de solo/cooperativo.
O protocolo online foi atualizado para v28 para separar clientes incompatíveis.

Os testes cobrem os 13 personagens quebrando mesas e lançando cadeiras com
ataques comuns, ausência de dano à distância, nascimento de inimigos em chão
livre nos quatro atos, ramificação do combo, salto encadeado, agarrão próximo de
mobília e replay determinístico. A publicação Web continua condicionada aos
checks de combate, exportação e navegador do projeto.

## Fontes das artes

As seis imagens foram geradas pela ferramenta integrada de geração de imagens.
Os prompts integrais estão em [story-v28-image-prompts.json](story-v28-image-prompts.json).
Os originais estão em `assets/source/story-v28/`; os recortes e atlases de
execução estão em `assets/story/v28/`. `tools/pack_story_v28.py` registra corpos
completos pela transparência, sem recortar por uma grade presumida, inventar
poses ou deformar membros. Os índices estão em `data/story/scenery-v28.json`
e `data/story/actions-v28.json`.
