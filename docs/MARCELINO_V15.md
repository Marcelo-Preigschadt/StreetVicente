# Marcelino: rosto da referência original e energia cinética

A revisão anterior foi rejeitada por alterar o rosto. Esta revisão substitui todos os desenhos usados pelo Marcelino com um conjunto baseado na fotografia original de 1600 × 1600 e no modelo de corpo inteiro corrigido. A fotografia fica fora do repositório público; sua identificação e hash constam na proveniência.

São nove folhas de oito desenhos de corpo inteiro: guarda/defesa/salto, reações/vitória, caminhada, soco, chute, golpes baixos, golpes aéreos, poderes H/U e uma sequência própria para Q. Os 72 desenhos de fonte resultam em 70 desenhos distintos usados: a guarda baixa compartilha a mesma pose do início/fim do soco baixo para evitar mudança de modelo ao agachar. Os quadros são recortados e registrados, sem colar rostos em corpos, deformar membros ou ampliar pixels da fonte.

O Q, **Lei da Ação e Reação**, alterna extensão das palmas e recuo do corpo na mesma cadência das cinco ondas da simulação. O soco usa os quadros de braço estendido durante o contato, antes da retração.

Os 16 desenhos de efeitos usam frentes de pressão, anéis de compressão, rastros paralelos de velocidade e expansão direcional no contato. A intensidade visual considera a velocidade ao quadrado; isso não modifica o dano. H continua **Impulso Linear**, U continua **Joelhada Cinética** e Q mantém cinco impulsos. Nomes, comandos, custos, vozes e frame data foram preservados. As áreas de contato e as mãos foram registradas nos novos desenhos, nos dois sentidos de luta.

## Arquivos

- `assets/source/marcelino-v15/`: fontes selecionadas, registro, proveniência e modelo de referência.
- `tools/pack_marcelino_face_v15.py`: empacotamento reprodutível; grava os atlas completos de forma atômica.
- `scripts/combat/marcelino_pose_v15.gd`: exposição determinística para soco e Q.
- `scripts/presentation/marcelino_fx_v14.gd`: efeitos exclusivamente visuais.
- `tests/marcelino_v14.gd`: cobertura da revisão em todos os estados/golpes, escala baixa, contato/defesa, origem dos projéteis e cadência do Q.
- `tests/render_marcelino_v14.gd`: capturas do renderizador Compatibility em `test-results/marcelino-v15/`.
- `tools/smoke_marcelino.cjs`: teclado real na exportação WASM, seleção, movimento, H/U/Q, contato e defesa.

Os caminhos de runtime `arcade-v14` e os nomes de testes foram mantidos por compatibilidade. O manifesto e cada quadro têm `face_revision: 15`, verificado nos testes para impedir retorno acidental às folhas anteriores. Esse teste confere a origem dos quadros; a semelhança facial depende da comparação visual com a referência, não de uma alegação de validação automática.

## Reproduzir e validar

```bash
python3 tools/pack_marcelino_face_v15.py
bash tools/test.sh
bash tools/export_web.sh
npm run test:web
```

O workflow `Godot · Validate, export and deploy Web` executa os testes nativos e de navegador antes de publicar no GitHub Pages. A configuração Web continua Compatibility, sem threads ou dependência de cabeçalhos COOP/COEP.
