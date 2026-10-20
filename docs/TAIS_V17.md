# Tais: rosto original, Savate e poderes de grande escala

Referências: `tais-identity-head-v1.webp` de 1254 × 1254 do projeto original, retrato aprovado `tais-head-menu-v4.webp` e folhas originais de corpo inteiro. Os desenhos preservam a mesma mulher adulta: formato do rosto, olhos, nariz, bochechas, cabelo castanho liso repartido de lado e preso em rabo baixo. Mantidos polo verde-azulado, calça preta com listra branca, luvas pretas, tênis brancos, retrato de seleção e vozes individuais em português brasileiro.

São 88 desenhos completos de fonte, 87 distintos consumidos, e 24 desenhos de efeitos. A guarda baixa compartilha o primeiro quadro do direto baixo. Guarda, caminhada, agachamento, defesa, salto, aterrissagem, reações, vitória, socos, chassés, coup de pied bas, golpes aéreos, agarrão e três poderes usam o conjunto v17. A semelhança facial foi comparada visualmente às referências; `face_revision: 17` verifica a origem dos quadros, sem pretender medir semelhança facial automaticamente.

## Poderes

| Comando | Nome original | Revisão |
| --- | --- | --- |
| H | Pulso Atlético | Chassé emite uma crista de pressão pelo tênis estendido; desenho de 280 × 230 px e núcleo físico de raio 58 px |
| U | Salto Olímpico | Impulsão, chute ascendente, ápice, descida e aterrissagem; vórtice de 350 × 450 px acompanha a subida física |
| Q | Circuito Campeão | Quatro grandes frentes de 460 × 440 px, rastros de até 680 px e explosão de 620 × 500 px; núcleo físico de raio 146 px |

Os rastros e halos ficam atrás das lutadoras. Cristas, emissão e impacto usam desenhos próprios em turquesa, branco e dourado, com expansão e dissipação. A explosão do Q persiste por 0,85 s, reduzida visualmente na defesa. O raio ampliado participa da colisão varrida determinística; o tamanho não foi obtido apenas decorando o projétil antigo. Halos e rastros têm função visual e não causam contatos adicionais.

Danos, velocidades, quatro ondas, cadência, comandos, nomes, falas e custo de 100 da barra do Q foram preservados. H/Q continuam bloqueáveis. U continua um salto real. Os pontos de emissão acompanham os tênis dos desenhos de chassé em ambos os sentidos. As áreas dos golpes normais foram registradas nos novos membros; o golpe baixo inclui a parte visível da canela/tênis, evitando atravessar a perna da frente do oponente entre dois quadros.

A caminhada também acompanha a profundidade W/S no História. Coordenada de faixa e salto continuam separadas.

## Arquivos e reprodução

- `assets/source/tais-v17/`: referências originais, modelo, folhas selecionadas, prompts, proveniência com hashes e registro de anatomia/contato; excluído do export.
- `assets/characters/tais/arcade-v17/`: dez atlas de runtime.
- `assets/effects/tais-v17/`: atlas atlético e atlas exclusivo do Circuito Campeão.
- `tools/pack_tais_v17.py`: recorte/empacotamento reproduzível, sem redimensionar pixels da fonte, deformar membros ou compor rostos em corpos.
- `scripts/combat/tais_pose_v17.gd`: exposição sincronizada com os quatro disparos e o salto.
- `scripts/presentation/tais_fx_v17.gd`: apresentação de emissão, frentes, rastros e explosão.
- `tests/tais_v17.gd`: cobertura de identidade de recursos, escala, contato bilateral, defesa, salto e emissão.
- `tools/smoke_tais.cjs`: teclado real no WASM e medição dos pixels novos de energia na arena.

```bash
python3 tools/pack_tais_v17.py
bash tools/test.sh
bash tools/export_web.sh
npm run test:web
```

O conjunto foi gerado com ImageGen integrado. As fontes selecionadas mantêm a resolução nativa; agachar ou dobrar as pernas não altera o fator de escala dentro da sequência. A revisão nativa passou com 84.937 verificações e zero falhas. A publicação permanece condicionada à bateria completa no navegador pelo workflow do repositório.
