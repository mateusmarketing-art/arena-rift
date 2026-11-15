# Arena Rift

MOBA 5v5 original para Android, feito em Godot 4.3. É inspirado no gênero de jogos como o Wild Rift, mas os heróis, o mapa, os nomes e a arte são próprios.

## Como instalar no celular

1. Abra a aba **Releases** deste repositório (ou a página *Actions* → última execução → *Artifacts*).
2. Baixe o arquivo `arena-rift.apk` no celular.
3. Abra o arquivo e permita "instalar apps desconhecidos" quando o Android pedir.

Cada envio para a branch `main` gera um APK novo automaticamente (workflow `Gerar APK Android`).

## Como jogar

- **Joystick** (lado esquerdo): andar.
- **ATACAR**: segure para atacar o inimigo mais próximo (prioriza heróis).
- **Q, W, E, R**: toque para mirar sozinho, ou arraste para mirar e solte para lançar. A habilidade R libera no nível 5.
- **Base**: volta para a base em 4 segundos (cancela se levar dano).
- **Loja**: compre itens na base ou enquanto espera renascer.
- **Placar**: abates, mortes, assistências e itens de todos.

Destrua as torres de uma rota para liberar as próximas; com qualquer torre interna caída, o Nexus inimigo fica vulnerável.

## Jogar com amigos

1. Todos instalam o mesmo APK e ficam no **mesmo Wi‑Fi** (ou conectados ao roteador do celular de quem cria a sala).
2. Um jogador toca em **Criar sala com amigos**; a tela mostra o IP da sala.
3. Os outros tocam em **Entrar na sala de um amigo** e escolhem a sala da lista (ou digitam o IP).
4. Cada um escolhe herói e time; o anfitrião toca em **Iniciar partida**. Bots completam as vagas até 5v5.

Jogar pela internet (cada um em sua casa) exige um servidor intermediário e ainda não está disponível.

## Heróis

| Herói | Função | Destaque |
|---|---|---|
| Kaelor, a Lâmina Rubra | Lutador (rota superior) | Investida, escudo, giro e salto que atordoa |
| Brontus, o Bastião | Tanque (selva) | Avanço que atordoa, couraça, tremor e fortaleza em área |
| Nyxara, a Tecelã do Vazio | Maga (meio) | Orbe, poço que deixa lento, teleporte curto e explosão estelar |
| Vesper, a Caçadora do Crepúsculo | Atiradora (rota inferior) | Tiro perfurante, frenesi, rolamento e flecha que cruza o mapa |
| Aurelia, a Guardiã Solar | Suporte (rota inferior) | Raio que atordoa, cura, escudo em aliados e aurora |

## Estrutura

- `scripts/data.gd` — heróis, itens, tropas e mapa.
- `scripts/sim.gd` — simulação da partida (roda no aparelho que hospeda).
- `scripts/bot.gd` — inteligência dos bots.
- `scripts/world_view.gd` — visual 3D gerado por código.
- `scripts/hud.gd` — controles de toque e interface.
- `scripts/net.gd` / `scripts/game.gd` — sala, rede e partida.
- `tests/` — partida completa só com bots (`godot --headless --path . --script tests/sim_test.gd`).
