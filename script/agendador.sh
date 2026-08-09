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
HOJE_UTC=$(date -u +%Y-%m-%d)
DIA_SEMANA=$(date -u +%u)   # 1=segunda 2=terca 3=quarta 4=quinta 5=sexta 6=sabado 7=domingo
echo "Hora atual (UTC): $HORA_UTC | Dia da semana (UTC, 1=seg..7=dom): $DIA_SEMANA"

# Apenas UMA publicacao por dia, sempre as 21:30 UTC (18:30 horario de
# Brasilia), alternando o tipo pelo dia da semana:
#   segunda(1) / quarta(3) / sexta(5) -> carrossel
#   terca(2)   / quinta(4) / sabado(6) -> post
#   domingo(7) -> nada
#
# Janela util: 21:30-23:29 UTC (2h de tolerancia, mesmo motivo de sempre:
# o cron nativo do GitHub nao ticka de fato a cada 10min, entao uma janela
# curta corre risco real de nao pegar nenhum tick).
#
# Corte de duplicidade: com uma janela de 2h, mais de uma execucao do
# agendador pode cair dentro da mesma janela (ja aconteceu: duas execucoes
# na mesma noite). Sem checar, isso publicaria dois itens diferentes da
# fila no mesmo dia (nao o mesmo arquivo repetido, mas dois itens em vez de
# um). O corte aqui e so "ja publicou o tipo de hoje? entao nao publica de
# novo" — ancorado no inicio da janela de hoje (nao numa janela rolante de
# N horas), a mesma logica que ja corrigiu o bug de duplicidade anterior.

if [[ "$HORA_UTC" > "21:29" && "$HORA_UTC" < "23:30" ]]; then
  case "$DIA_SEMANA" in
    1|3|5)
      JA_PUBLICOU=$(git log --since="${HOJE_UTC}T21:30:00" --grep="Carrossel publicado automaticamente" --oneline)
      if [ -z "$JA_PUBLICOU" ]; then
        echo "Dia de carrossel (seg/qua/sex), dentro da janela. Disparando postar-carrosseis.yml..."
        gh workflow run postar-carrosseis.yml --ref main
      else
        echo "Ja publicou o carrossel de hoje. Nada a fazer."
      fi
      ;;
    2|4|6)
      JA_PUBLICOU=$(git log --since="${HOJE_UTC}T21:30:00" --grep="Post publicado automaticamente" --oneline)
      if [ -z "$JA_PUBLICOU" ]; then
        echo "Dia de post (ter/qui/sab), dentro da janela. Disparando postar-posts.yml..."
        gh workflow run postar-posts.yml --ref main
      else
        echo "Ja publicou o post de hoje. Nada a fazer."
      fi
      ;;
    7)
      echo "Domingo. Sem publicacao programada."
      ;;
  esac
fi

echo "Verificacao concluida."
