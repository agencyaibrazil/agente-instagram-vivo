#!/usr/bin/env bash
set -e

if [ "${FORCAR_MODO:-nenhum}" = "posts" ]; then
  echo "Forcado manualmente: disparando postar-posts.yml sem checar janela/duplicidade."
  gh workflow run postar-posts.yml --ref main
  exit 0
fi

if [ "${FORCAR_MODO:-nenhum}" = "carrosseis" ]; then
  echo "Forcado manualmente: disparando postar-carrosseis.yml sem checar janela/duplicidade."
  gh workflow run postar-carrosseis.yml --ref main
  exit 0
fi

HORA_UTC=$(date -u +%H:%M)

# Determina a "rodada" pendente (a data de referencia do ultimo horario-alvo,
# 21:30 UTC, que ja passou). Se ainda nao chegamos nas 21:30 UTC de hoje, a
# rodada pendente ainda e a de ONTEM (pode nao ter sido cumprida ainda).
# Isso evita ficar preso a "hoje" no sentido do relogio, o que quebraria a
# logica se um disparo atrasar o suficiente pra cruzar a meia-noite UTC
# (nosso alvo, 21:30 UTC, fica so 2h30 antes da virada do dia).
if [[ "$HORA_UTC" < "21:30" ]]; then
  DATA_RODADA=$(date -u -d "yesterday" +%Y-%m-%d)
else
  DATA_RODADA=$(date -u +%Y-%m-%d)
fi
DIA_SEMANA_RODADA=$(date -u -d "$DATA_RODADA" +%u)   # 1=segunda...7=domingo

echo "Hora atual (UTC): $HORA_UTC | Rodada pendente: $DATA_RODADA (dia da semana $DIA_SEMANA_RODADA)"

# SEM JANELA DE FECHAMENTO (sem "so ate tal hora"). Motivo: comparando com
# outro workflow do mesmo projeto (repor-conteudo.yml, cron nativo 1x/dia,
# sem nenhuma janela) que sempre dispara -- so que atrasado (2h30 a 5h de
# atraso observados em 4 dias seguidos, nunca falhou de verdade), ficou
# claro que o problema real nao e o agendador nativo do GitHub ser lento --
# e QUALQUER corte de horario ("so ate tal hora") que transforma um atraso
# (inofensivo) numa falha total (perde o dia). Tirando o corte, o agendador
# so para de tentar quando a publicacao da rodada realmente sair -- do
# mesmo jeito que o resto dos workflows deste projeto ja funciona.
#
# Apenas UMA publicacao por rodada, alternando o tipo pelo dia da semana da
# rodada (nao o dia do relogio no momento da checagem -- ver acima):
#   segunda(1) / quarta(3) / sexta(5) -> carrossel
#   terca(2)   / quinta(4) / sabado(6) -> post
#   domingo(7) -> nada
#
# Corte de duplicidade: ancorado no inicio da janela DA RODADA (nao do dia
# do relogio), pra continuar valendo mesmo se a checagem atual ja estiver
# no dia seguinte (rodada de ontem ainda pendente).

case "$DIA_SEMANA_RODADA" in
  1|3|5)
    JA_PUBLICOU=$(git log --since="${DATA_RODADA}T21:30:00" --grep="Carrossel publicado automaticamente" --oneline)
    if [ -z "$JA_PUBLICOU" ]; then
      echo "Rodada de carrossel (seg/qua/sex) ainda pendente. Disparando postar-carrosseis.yml..."
      gh workflow run postar-carrosseis.yml --ref main
    else
      echo "Rodada de carrossel ja cumprida."
    fi
    ;;
  2|4|6)
    JA_PUBLICOU=$(git log --since="${DATA_RODADA}T21:30:00" --grep="Post publicado automaticamente" --oneline)
    if [ -z "$JA_PUBLICOU" ]; then
      echo "Rodada de post (ter/qui/sab) ainda pendente. Disparando postar-posts.yml..."
      gh workflow run postar-posts.yml --ref main
    else
      echo "Rodada de post ja cumprida."
    fi
    ;;
  7)
    echo "Rodada de domingo: sem publicacao programada."
    ;;
esac

echo "Verificacao concluida."
