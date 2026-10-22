# Revisão dos poderes do elenco · v20

Pedido de 22 de outubro de 2026: revisar todos os personagens, exceto Khauãny
(`khauany`) e Dienes, com a Tais v17 como referência de presença dos poderes.

O inventário confirmou quatro caminhos antigos (Marcelo, Adriano, Rafael e João)
e quatro conjuntos próprios ainda pequenos (Gustavo, Gelton, Marcelino e Marcos).
Tais, Luciana e Ruan já tinham a escala aprovada. Nenhum desenho de personagem,
rosto, retrato, figurino ou voz foi substituído nesta revisão.

| Personagem | Resultado da revisão |
|---|---|
| Marcelo | Novos cels de código, Firewall, drone e explosão de laser; cinco sentinelas no super; feixes em quatro camadas, carga e mira |
| Adriano | Novos selo imperial, estandartes, muralha ascendente e ruptura dourada |
| Rafael | Novos pergaminhos, espiral temporal, trilha de crônicas e explosão de páginas |
| João | Novos Super Soco, Curto-Circuito e coroa elétrica; Q continua sendo o próprio corpo rolando, com três contatos e rebote |
| Gustavo | Névoa ampliada, carga química, rastro de fumaça, arco ascendente e grande reação final |
| Gelton | Frente larga de tinta, rastros multicoloridos, arco do aú e grande respingo final |
| Marcelino | Impulsos ampliados, anéis de pressão, joelhada ascendente e explosão cinética |
| Marcos | Sequestro de Sessão, Pilha Reversa e Kernel Panic ampliados, mantendo o kit de contato e a subida sem salto |
| Tais | Conferência de H/U/Q; conjunto v17 aprovado preservado |
| Luciana | Conferência de H/U/Q; conjunto v18 aprovado preservado |
| Ruan | Conferência de H/U/Q; conjunto v19 aprovado preservado |

Khauãny e Dienes ficam fora do despacho v20, da mudança de duração de impactos e
da sobreposição de alcance. Seus arquivos permanecem intactos.

## Apresentação e contato

As frentes dos projéteis revisados usam área de 350 × 280 px no H e 570 × 470 px
nos supers de ondas. O U tem arco de 360 × 465 px. Impactos de super chegam a
640 × 520 px; dissipam em 0,85 s. Drones, rolinho e Kernel Panic têm composição
própria, adequada ao funcionamento original, sem convertê-los em ondas genéricas.
Rastros e arcos largos são desenhados abaixo dos atores para preservar a leitura
do rosto e da postura. O contato mantém o clarão à frente.

Os núcleos H têm raio físico de aproximadamente 64 px; supers de ondas, 146 px.
O fator original do Adriano é aplicado uma única vez. Dano, custo, velocidade,
número/cadência de ondas, defesa, vozes e comandos permanecem. As coronas de
impacto e os rastros não criam hitboxes extras. Marcelo mantém cinco drones e
lasers de raio 10; João mantém a simulação determinística de rolamento.

`EffectCelV20` registra cels e aplica transparência gradual somente nas bordas
dos efeitos, evitando cortes retangulares e vazamento entre células. Não altera
pixels de origem, poses, rostos, corpos ou colisões. Malhas 2D ficam em cache;
não são criadas a cada frame.

## Fontes

Ferramenta: **image_gen.imagegen integrada**, modo geração, fundo transparente.
São 104 desenhos VFX novos: três folhas de 16 cels de código/império/crônicas,
16 cels elétricos, oito cels de sentinela/laser e quatro folhas de oito cels
de supers de química/tinta/física/Kernel Panic. Fontes e prompts completos:
[`assets/source/powers-v20`](../assets/source/powers-v20/). As quatro revisões
anteriores de fumaça/tinta/impulso/circuitos mantêm seus desenhos H/U aprovados
com nova composição e escala e recebem Q e impactos finais novos. Não houve geração de rostos.

```bash
python3 tools/pack_powers_v20.py
bash tools/test.sh
bash tools/export_web.sh
node tools/smoke_roster_v20.cjs
npm run test:web
```

O teste nativo percorre contatos de H/U/Q nos dois lados dos oito kits alterados,
encerramento de entidades/efeitos e isolamento dos dois personagens excluídos.
O teste Web seleciona os 11 lutadores pelo menu, executa 33 poderes com teclado,
confere dano/custo e mede pixels das capturas; cada super precisa ocupar mais de
6 mil pixels alterados luminosos fora das silhuetas e mais de 250 px de altura,
com a faixa SUPER já encerrada e a câmera sem vibração. As capturas de
guarda, emissão e impacto ficam no artefato de QA do workflow. O mesmo script
aceita `SVF_AUDIT_URL` para verificar o pacote publicado sem modificar o jogo.
