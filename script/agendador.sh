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
echo "Hora atual (UTC): $HORA_UTC"

# Corte de duplicidade: inicio da JANELA DE HOJE (nao uma janela rolante de
# N horas, nem "desde a meia-noite"). Motivo: uma publicacao atrasada de um
# dia anterior NAO pode contar como "ja publicado hoje" e bloquear a janela
# de hoje — isso ja aconteceu de verdade em 2026-08-07 e bloqueou o
# carrossel do dia por engano. Ancorar o "--since" no inicio da propria
# janela (10:30 UTC pra posts, 21:30 UTC pra carrosseis) resolve os dois
# problemas ao mesmo tempo: ignora publicacoes de outros horarios/dias, e
# ainda evita duplicar se o agendador rodar mais de uma vez dentro da mesma
# janela.
#
# As janelas comecam EXATAMENTE no horario alvo (nunca disparam antes) e se
# estendem por 2h pra frente. Motivo da largura: dados reais mostraram que o
# cron nativo "*/10 * * * *" do GitHub so tickou de fato ~3-4 vezes em 7h
# (nao ~42 vezes como o "a cada 10min" prometeria) — entao uma janela curta
# (~40min) corre risco real de nao pegar nenhum tick em algum dia e o
# agendador simplesmente nao rodar. 2h da folga suficiente pros intervalos
# reais observados entre ticks (~1h30-2h), sem deixar a publicacao atrasar
# indefinidamente.

# Janela dos posts: alvo 10:30 UTC (07:30 horario de Brasilia). Janela util:
# 10:30-12:29 UTC.
if [[ "$HORA_UTC" > "10:29" && "$HORA_UTC" < "12:30" ]]; then
  JA_PUBLICOU=$(git log --since="${HOJE_UTC}T10:30:00" --grep="Post publicado automaticamente" --oneline)
  if [ -z "$JA_PUBLICOU" ]; then
    echo "Dentro da janela dos posts. Disparando postar-posts.yml..."
    gh workflow run postar-posts.yml --ref main
  else
    echo "Ja publicou um post na janela de hoje. Nada a fazer."
  fi
fi

# Janela dos carrosseis: alvo 21:30 UTC (18:30 horario de Brasilia). Janela
# util: 21:30-23:29 UTC (fica dentro do mesmo dia UTC, nao cruza meia-noite).
if [[ "$HORA_UTC" > "21:29" && "$HORA_UTC" < "23:30" ]]; then
  JA_PUBLICOU=$(git log --since="${HOJE_UTC}T21:30:00" --grep="Carrossel publicado automaticamente" --oneline)
  if [ -z "$JA_PUBLICOU" ]; then
    echo "Dentro da janela dos carrosseis. Disparando postar-carrosseis.yml..."
    gh workflow run postar-carrosseis.yml --ref main
  else
    echo "Ja publicou um carrossel na janela de hoje. Nada a fazer."
  fi
fi

echo "Verificacao concluida."
