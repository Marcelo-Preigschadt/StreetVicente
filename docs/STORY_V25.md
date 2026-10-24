# História v25 — Fists of Fury no Godot 4

Combate da campanha adaptado do projeto original de Nicolas Bize:
https://github.com/nicolasbize/fists-of-fury-course
Commit de origem: 0f353aea614cf57e43fb3776667c26dd3ce7714c, licença MIT.
A licença e o mapa da adaptação estão em `third_party/fists_of_fury/`.

## Integração executada

- `FuryCombat`: direção livre pelo movimento, sequência de quatro golpes
  confirmados, finalizador que lança/derruba, janela para o próximo comando,
  voadora contextual, normalização diagonal e profundidade bloqueada durante
  ataques/reação. Os quadros de contato continuam registrados aos sprites.
- `StoryEnemyMotion`: reserva persistente de posições, dono por jogador,
  aproximação separada do ataque, contorno pelo chão ao trocar de lado,
  liberação de posições e aviso visual de preparação.
- `FuryCheckpoint`: fila de reforços e limite de três inimigos simultâneos,
  preservando todos os membros, chefes e quatro atos da campanha.
- Objetos: mesas destrutíveis com fragmentos da própria imagem; estantes
  tombam; cadeiras recebem um passo de ajuste e são lançadas somente quando o pé
  registrado colide com o objeto; refrigerante libera
  projéteis; recipientes podem deixar recuperação de vida. Não existe pose
  de carregar mobília nesta versão. Saves antigos devolvem o móvel ao chão.
- O mesmo adaptador atende solo e cooperativo. Estado de combo, reservas,
  fila, fragmentos e trajetórias participam do snapshot para rollback.

Permanecem os sprites e rostos aprovados, especiais grandes, energia obtida
em luta, versus/treino e exportação Web do projeto. Nenhuma arte ou áudio
do curso foi redistribuído. Esta é uma adaptação da base de combate, não a
importação integral do jogo do curso: armas de fogo/facas e suas fases não
fazem parte da campanha Street Vicente.

## Controles

A/D: andar e virar; W/S: profundidade; Espaço: salto.
F: sequência de golpes; G: chute; no ar, F/G: voadora.
R: defesa; E: interação por golpe com o objeto próximo.
H/U: especial 25; Z: 40; Q: 100. Sem recarga passiva.

## Validação

Regressões nativas: contato real dos quatro golpes, finalizador, preparação
antes de lançar cadeira, replay por JSON com objetos em voo, reforços por
vaga, save antigo e campanhas/coop existentes. Navegador: combate por
teclado, gasto de energia ganha lutando, dois checkpoints, destruição de
mesa e lançamento de cadeira, com observação somente de leitura.

A revisão mantém o projeto em desenvolvimento; estes testes não certificam
qualidade comercial de animação ou conclusão do jogo.
