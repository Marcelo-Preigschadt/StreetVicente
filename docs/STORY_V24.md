# História V24 — proporção e movimento

Esta revisão responde à captura enviada com cadeira em miniatura e máquinas sobrepostas. O personagem em pé tem referência de 300 unidades. Cadeira: 113 × 172; mesa: 246 × 136. As larguras preservam a razão das imagens originais. O tamanho é compartilhado entre chão, mão, voo e colisões. Os assentos foram afastados para acomodar o novo volume.

Os robôs de corpo rígido têm pontos de apoio registrados pelo corpo opaco, sem usar faíscas ou arcos elétricos como base. Nenhuma imagem de personagem ou de inimigo foi redesenhada. O registro reproduzível está em `tools/register_story_enemies_v24.py` e `data/story/enemy-registration-v24.json`.

Solo e cooperativo usam a mesma aproximação: uma máquina de corpo a corpo e uma de disparo por lado e alvo, com as demais distribuídas em profundidade e distância. Reações, quedas e recuperação interrompem a perseguição lateral. A distância percorrida pela animação conta apenas caminhada; deslocamento diagonal conserva a velocidade. A recuperação usa as poses de queda em ordem inversa. Máquinas voadoras olham para o alvo, usam o ataque correto e sobem gradualmente depois de cair.

O protocolo de salas passa a `svf-godot-v24`, pois as regras de simulação mudaram. Saves anteriores reposicionam as cadeiras que ainda estão no chão. Energia e rostos aprovados seguem a revisão anterior.

A validação inclui proporção contra os arquivos de arte, sequência de queda/recuperação, ataque dos drones, espaçamento e retomada determinística. A conferência visual em movimento e a comparação entre personagem e móveis fazem parte da revisão. Aprovação técnica desses testes não equivale a afirmar que o jogo está pronto para comercialização; esta é uma versão em desenvolvimento.
