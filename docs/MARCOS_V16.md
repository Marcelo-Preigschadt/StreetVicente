# Marcos: identidade original e judô

O conjunto novo usa como referência o retrato original aprovado (`marcos-head-menu-v3.webp`), a base e a folha de combate da versão Canvas. Rosto largo, sobrancelhas fortes, cabelo curto escuro com têmporas grisalhas, porte robusto, quimono azul, faixa preta e pés descalços foram mantidos. O retrato de seleção e as vozes individuais permanecem os mesmos.

São 88 desenhos completos de fonte e 87 desenhos distintos usados. A guarda baixa compartilha o primeiro desenho da pegada baixa para manter a anatomia ao iniciar e terminar o golpe. As sequências cobrem guarda, caminhada em tsugi-ashi, defesa, agachar, salto, reações, vitória, pegadas de gola, rasteiras, ataques aéreos e quatro projeções. Os quadros são recortados e registrados sem ampliar os pixels, deformar membros ou colar rostos em corpos. A semelhança facial foi comparada visualmente com o retrato; o marcador `face_revision: 16` verifica somente a origem dos quadros.

| Comando | Movimento preservado | Apresentação nova |
| --- | --- | --- |
| H | Sequestro de Sessão | Entrada de judô, pegada e trava digital vinculada ao alvo |
| U | Pilha Reversa | Elevação com o Marcos apoiado no chão e blocos de memória invertidos |
| Q | Kernel Panic | Rotação do quadril, projeção e ruptura de circuitos vermelhos/azuis |
| E | Ippon seoi nage | Sequência própria de entrada, encaixe, rotação e recuperação |

Os 16 desenhos de efeitos têm preparação na mão, travas de sessão, pilhas e circuitos. H e Q continuam projeções que vencem a defesa de um alvo no chão; U continua bloqueável. Nenhum dos três se tornou projétil. Nomes, custos, danos, tempos e falas foram preservados. As áreas de contato e as mãos acompanham a nova arte nos dois sentidos. A largura de colisão do corpo acompanha o porte do Marcos.

No História, a caminhada do Marcos também responde à distância percorrida na profundidade, usando o mesmo ciclo de corpo inteiro. O deslocamento W/S mantém a coordenada de salto separada.

## Fontes e integração

- `assets/source/marcos-v16/`: folhas originais, prompts, referências, hashes e registro de anatomia/contato; excluído do export.
- `tools/pack_marcos_v16.py`: empacotamento determinístico com rejeição de silhuetas encostadas, preservação de detalhes e gravação atômica.
- `data/characters/marcos-arcade-v16.json`: quadros, escala, raízes, mãos e colisões.
- `scripts/combat/marcos_pose_v16.gd`: exposição por fase do golpe e deslocamento real na caminhada.
- `scripts/presentation/marcos_fx_v16.gd`: efeitos exclusivamente visuais.
- `tests/marcos_v16.gd`: estados/golpes, escala baixa, contato bilateral, defesa, apoio no chão, caminhada em profundidade e identidade dos recursos originais.
- `tools/smoke_marcos.cjs`: seleção, golpes, defesa e História por teclado real no WASM.

## Reprodução

```bash
python3 tools/pack_marcos_v16.py
bash tools/test.sh
bash tools/export_web.sh
npm run test:web
```

Godot 4.5.1, simulação de 120 Hz e Web Compatibility sem threads. O workflow executa os testes nativos e de navegador antes de publicar. A revisão nativa passou com 78.249 verificações e zero falhas.
