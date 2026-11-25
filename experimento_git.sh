#!/usr/bin/env bash
# TCC - Experimento Git | UM arquivo Bash autonomo para 180 operacoes Git via SSH.
# Plano FIXO: 30 blocos aleatorizados (um de cada operacao/cenario por bloco).
# Semente usada APENAS durante a elaboracao do arquivo: 20261021.
# Dentro de um bloco, as 6 combinacoes foram sorteadas; nao ha
# duas operacoes Git do mesmo tipo consecutivas (inclusive entre blocos).
# Isso equilibra a ordem; NAO limpa nem elimina o efeito do cache.
# Requer: Bash >= 5.0, cliente Git, OpenSSH OQS, chave e 2 servidores configurados.
# Nao requer outros scripts .sh; resultados em UM CSV (+ metadados.txt de apoio).
# Metricas: tempo (ms), CPU (%), RSS maximo (KB), RX/TX (bytes em enp0s8).
# Uso: bash experimento_git.sh simular
#      bash experimento_git.sh executar
# Sem modo retomar. Uma nova tentativa inicia na operacao 1 apos verificar os repositorios.
set -Eeuo pipefail
export LC_ALL=C
export GIT_TERMINAL_PROMPT=0
umask 077

BASE="$HOME/experimentos-tcc"
SSH_BIN="/home/tcc/oqs-openssh/bin/ssh"
SSH_KEY="/home/tcc/.ssh/id_ed25519_tcc"
SSH_PORT=2223
USUARIO=tcc
IP_CLASSICO=192.168.50.20
IP_PQC=192.168.50.30
KEX_CLASSICO=curve25519-sha256
KEX_PQC=mlkem768-sha256
REPO_CLONE=/home/tcc/flask.git
REPO_PULL=/home/tcc/flask-pull.git
REPO_PUSH=/home/tcc/flask-push.git
PREP_PULL=/home/tcc/flask-pull-preparacao
TAMANHO_ARQUIVO=200000
# Identificador automatico sem numero fixo de execucao.
# Permite preservar o CSV de cada tentativa separadamente.
RODADA="rodada_$(date -u +%Y%m%dT%H%M%SZ)_$$"
SAIDA="$BASE/resultados/$RODADA/resultados.csv"
META="$(dirname "$SAIDA")/metadados.txt"
LOCK="$BASE/.experimento_git.lock"
WORK="$BASE/temporarios"
DADOS="$BASE/dados/$RODADA"
INTERVALO_SEGUNDOS=2  # espera igual antes de cada Git, FORA da medicao
REDE_IFACE=enp0s8  # Interface Ethernet experimental da VM cliente
RX_FILE="/sys/class/net/$REDE_IFACE/statistics/rx_bytes"
TX_FILE="/sys/class/net/$REDE_IFACE/statistics/tx_bytes"
TIME_LOG="$(dirname "$SAIDA")/time_ultima_operacao.txt"
CABECALHO='ordem,operacao,cenario,repeticao,pasta,tempo_ms,status,commit,sha256,inicio_utc,cpu_percentual,memoria_max_kb,rx_bytes,tx_bytes'
# Git local sem manutencao/gc automatico (evita ruido dentro da janela medida).
GIT_LOCAL=(git -c gc.auto=0 -c maintenance.auto=false)

# Ordem embutida neste arquivo, sem sorteio em tempo de execucao.
mapfile -t PLANO <<'PLANO_FIXO'
1 pull pqc 001 tests
2 clone pqc 001 -
3 push classico 001 tests
4 pull classico 001 tests
5 push pqc 001 tests
6 clone classico 001 -
7 push classico 002 examples
8 clone pqc 002 -
9 push pqc 002 examples
10 pull classico 002 examples
11 clone classico 002 -
12 pull pqc 002 examples
13 push pqc 003 src/flask
14 pull classico 003 src/flask
15 clone pqc 003 -
16 push classico 003 src/flask
17 clone classico 003 -
18 pull pqc 003 src/flask
19 clone classico 004 -
20 pull classico 004 docs
21 push pqc 004 docs
22 clone pqc 004 -
23 push classico 004 docs
24 pull pqc 004 docs
25 push classico 005 tests
26 clone pqc 005 -
27 pull pqc 005 tests
28 clone classico 005 -
29 push pqc 005 tests
30 pull classico 005 tests
31 push classico 006 examples
32 pull classico 006 examples
33 clone pqc 006 -
34 push pqc 006 examples
35 clone classico 006 -
36 pull pqc 006 examples
37 push classico 007 src/flask
38 clone classico 007 -
39 pull pqc 007 src/flask
40 clone pqc 007 -
41 pull classico 007 src/flask
42 push pqc 007 src/flask
43 clone pqc 008 -
44 pull pqc 008 docs
45 push classico 008 docs
46 pull classico 008 docs
47 push pqc 008 docs
48 clone classico 008 -
49 push pqc 009 tests
50 clone classico 009 -
51 pull classico 009 tests
52 clone pqc 009 -
53 push classico 009 tests
54 pull pqc 009 tests
55 push classico 010 examples
56 pull classico 010 examples
57 clone pqc 010 -
58 push pqc 010 examples
59 clone classico 010 -
60 pull pqc 010 examples
61 push classico 011 src/flask
62 pull classico 011 src/flask
63 clone pqc 011 -
64 push pqc 011 src/flask
65 clone classico 011 -
66 pull pqc 011 src/flask
67 clone classico 012 -
68 pull classico 012 docs
69 clone pqc 012 -
70 push classico 012 docs
71 pull pqc 012 docs
72 push pqc 012 docs
73 clone pqc 013 -
74 pull pqc 013 tests
75 push classico 013 tests
76 clone classico 013 -
77 push pqc 013 tests
78 pull classico 013 tests
79 clone classico 014 -
80 pull classico 014 examples
81 push pqc 014 examples
82 pull pqc 014 examples
83 push classico 014 examples
84 clone pqc 014 -
85 pull classico 015 src/flask
86 clone pqc 015 -
87 push classico 015 src/flask
88 pull pqc 015 src/flask
89 clone classico 015 -
90 push pqc 015 src/flask
91 pull pqc 016 docs
92 push pqc 016 docs
93 pull classico 016 docs
94 clone pqc 016 -
95 push classico 016 docs
96 clone classico 016 -
97 push pqc 017 tests
98 pull classico 017 tests
99 clone pqc 017 -
100 push classico 017 tests
101 pull pqc 017 tests
102 clone classico 017 -
103 pull classico 018 examples
104 clone pqc 018 -
105 push classico 018 examples
106 pull pqc 018 examples
107 push pqc 018 examples
108 clone classico 018 -
109 pull classico 019 src/flask
110 push pqc 019 src/flask
111 clone classico 019 -
112 push classico 019 src/flask
113 clone pqc 019 -
114 pull pqc 019 src/flask
115 push classico 020 docs
116 pull pqc 020 docs
117 push pqc 020 docs
118 clone classico 020 -
119 pull classico 020 docs
120 clone pqc 020 -
121 push classico 021 tests
122 pull classico 021 tests
123 push pqc 021 tests
124 clone classico 021 -
125 pull pqc 021 tests
126 clone pqc 021 -
127 pull classico 022 examples
128 push classico 022 examples
129 clone pqc 022 -
130 push pqc 022 examples
131 clone classico 022 -
132 pull pqc 022 examples
133 clone classico 023 -
134 push pqc 023 src/flask
135 clone pqc 023 -
136 pull classico 023 src/flask
137 push classico 023 src/flask
138 pull pqc 023 src/flask
139 clone pqc 024 -
140 push pqc 024 docs
141 pull classico 024 docs
142 push classico 024 docs
143 pull pqc 024 docs
144 clone classico 024 -
145 pull pqc 025 tests
146 push classico 025 tests
147 clone pqc 025 -
148 pull classico 025 tests
149 push pqc 025 tests
150 clone classico 025 -
151 pull pqc 026 examples
152 clone classico 026 -
153 push classico 026 examples
154 clone pqc 026 -
155 push pqc 026 examples
156 pull classico 026 examples
157 clone classico 027 -
158 push pqc 027 src/flask
159 pull pqc 027 src/flask
160 push classico 027 src/flask
161 clone pqc 027 -
162 pull classico 027 src/flask
163 clone classico 028 -
164 push pqc 028 docs
165 pull pqc 028 docs
166 push classico 028 docs
167 pull classico 028 docs
168 clone pqc 028 -
169 pull classico 029 tests
170 push pqc 029 tests
171 clone classico 029 -
172 push classico 029 tests
173 clone pqc 029 -
174 pull pqc 029 tests
175 clone classico 030 -
176 pull pqc 030 examples
177 push classico 030 examples
178 pull classico 030 examples
179 push pqc 030 examples
180 clone pqc 030 -
PLANO_FIXO

CURRENT='validacao'
CSV_ATIVO=0
INICIO_UTC=''
# Trava vale para executar; simular nao toca no ambiente.
falha() {
  echo "ERRO [$CURRENT]: $*" >&2
  if (( CSV_ATIVO )); then
    echo "CSV parcial preservado: $SAIDA. Nao repita a operacao sem verificar o estado Git." >&2
  fi
  exit 1
}
modo="${1:-simular}"
[[ "$modo" == simular || "$modo" == executar ]] || falha "Use: $0 simular|executar"
[[ "${#PLANO[@]}" -eq 180 ]] || falha 'Plano nao possui 180 operacoes'

# Validacao estrutural do plano (blocos, sequencia, pastas coerentes).
declare -A contagem=() visto=() pasta_rep=()
anterior=''; idx=0
for registro in "${PLANO[@]}"; do
  idx=$((idx + 1))
  read -r ordem op cenario rep pasta <<< "$registro"
  [[ "$ordem" =~ ^[0-9]+$ && "$rep" =~ ^[0-9]{3}$ ]] || falha "Plano invalido: $registro"
  (( 10#$ordem == idx )) || falha "Ordem fora de sequencia: $registro"
  (( 10#$rep == (idx - 1) / 6 + 1 )) || falha "Repeticao fora do bloco esperado: $registro"
  [[ "$op" == clone || "$op" == pull || "$op" == push ]] || falha "Operacao invalida: $op"
  [[ "$cenario" == classico || "$cenario" == pqc ]] || falha "Cenario invalido: $cenario"
  [[ "$anterior" != "$op" ]] || falha "Operacoes iguais consecutivas: $op"
  anterior="$op"
  if [[ "$op" == clone ]]; then
    [[ "$pasta" == '-' ]] || falha "Clone nao usa pasta: $registro"
  else
    case "$pasta" in
      tests|examples|src/flask|docs) ;;
      *) falha "Pasta invalida: $registro" ;;
    esac
    if [[ -n "${pasta_rep[$op/$rep]:-}" ]]; then
      [[ "${pasta_rep[$op/$rep]}" == "$pasta" ]] || falha "Pasta difere entre cenarios: $op/$rep"
    else
      pasta_rep[$op/$rep]="$pasta"
    fi
  fi
  chave="$op/$cenario/$rep"
  [[ -z "${visto[$chave]:-}" ]] || falha "Repeticao duplicada: $chave"
  visto[$chave]=1
  c="$op/$cenario"; contagem[$c]=$(( ${contagem[$c]:-0} + 1 ))
done
for op in clone pull push; do
  for cenario in classico pqc; do
    [[ ${contagem[$op/$cenario]:-0} -eq 30 ]] || falha "Contagem incorreta: $op/$cenario"
  done
done
if [[ "$modo" == simular ]]; then
  printf 'EXPERIMENTO GIT: ORDEM PREDEFINIDA (nenhum Git executado)\n'
  printf 'Ordem | Operacao | Cenario | Repeticao | Pasta\n'
  for registro in "${PLANO[@]}"; do
    read -r ordem op cenario rep pasta <<< "$registro"
    printf '%3d | %-5s | %-8s | %s | %s\n' "$ordem" "$op" "$cenario" "$rep" "$pasta"
  done
  printf 'Total: 180 operacoes, 30 por combinacao. Nenhuma operacao Git executada.\n'
  exit 0
fi

CURRENT='pre-requisitos'
[[ -n "${EPOCHREALTIME:-}" ]] || falha 'Requer Bash >= 5.0 (variavel EPOCHREALTIME)'
for cmd in git sha256sum stat head sleep wc tail cut awk sort flock date; do
  command -v "$cmd" > /dev/null || falha "Comando ausente: $cmd"
done
[[ -x "$SSH_BIN" ]] || falha "Cliente OQS SSH ausente: $SSH_BIN"
[[ -r "$SSH_KEY" ]] || falha "Chave SSH ausente: $SSH_KEY"
[[ -d "$WORK" ]] || falha "Pasta de repositorios locais ausente: $WORK"
[[ -x /usr/bin/time ]] || falha 'Instale GNU time: sudo apt install time'
[[ -r "$RX_FILE" && -r "$TX_FILE" ]] || falha "Contadores de rede indisponiveis em $REDE_IFACE"
# Impede duas instancias simultaneas, inclusive se o arquivo CSV ainda nao existe.
exec 9>"$LOCK"
flock -n 9 || falha "Outra execucao esta em andamento: $LOCK"

# Toda tentativa inicia na operacao 1. Nao ha recuperacao automatica.
[[ ! -e "$SAIDA" ]] || falha "Arquivo ja existente; nao sobrescrevo: $SAIDA"
[[ ! -e "$DADOS" ]] || falha "Pasta de dados ja existe: $DADOS"

# Nao habilita multiplexacao: nova conexao SSH por operacao Git.
selecionar_cenario() {
  local c="$1"
  if [[ "$c" == classico ]]; then IP="$IP_CLASSICO"; KEX="$KEX_CLASSICO"
  else IP="$IP_PQC"; KEX="$KEX_PQC"; fi
  # Um unico KexAlgorithms: se o algoritmo nao for negociado, a conexao FALHA
  # (nao ha fallback silencioso para outro KEX).
  SSH_OPTS=(-F /dev/null -p "$SSH_PORT" -i "$SSH_KEY"
    -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10
    -o ServerAliveInterval=15 -o ServerAliveCountMax=4
    -o StrictHostKeyChecking=yes -o ControlMaster=no -o ControlPath=none
    -o ControlPersist=no -o "KexAlgorithms=$KEX")
  # O Git interpreta GIT_SSH_COMMAND como uma linha de comando.
  printf -v GIT_SSH_COMMAND '%q ' "$SSH_BIN" "${SSH_OPTS[@]}"
  export GIT_SSH_COMMAND
  REMOTO="$USUARIO@$IP"
}
ssh_sem_entrada() { "$SSH_BIN" "${SSH_OPTS[@]}" -n "$REMOTO" "$@"; }
ssh_com_entrada() { "$SSH_BIN" "${SSH_OPTS[@]}" -T "$REMOTO" "$@"; }

# Mede um comando Git com CPU/memoria via GNU time e bytes da interface.
# A criacao dos commits permanece fora da janela medida.
# O tempo total inclui a pequena sobrecarga de iniciar /usr/bin/time.
medir_git() {
  local rx_antes rx_depois tx_antes tx_depois
  read -r rx_antes < "$RX_FILE"
  read -r tx_antes < "$TX_FILE"
  inicio=${EPOCHREALTIME//[.,]/}
  /usr/bin/time -v -o "$TIME_LOG" "$@"
  fim=${EPOCHREALTIME//[.,]/}
  read -r rx_depois < "$RX_FILE"
  read -r tx_depois < "$TX_FILE"
  RX_BYTES=$((rx_depois - rx_antes))
  TX_BYTES=$((tx_depois - tx_antes))
  (( RX_BYTES >= 0 && TX_BYTES >= 0 )) || falha 'Contadores de rede foram reiniciados durante a operacao'
  read -r CPU_PERCENTUAL MEMORIA_MAX_KB < <(
    awk -F: '
      /Percent of CPU this job got/ {
        cpu=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", cpu); sub(/%$/, "", cpu)
      }
      /Maximum resident set size \(kbytes\)/ {
        mem=$2; gsub(/[[:space:]]/, "", mem)
      }
      END { print cpu, mem }
    ' "$TIME_LOG"
  )
  [[ "$CPU_PERCENTUAL" =~ ^[0-9]+([.][0-9]+)?$ ]] || falha "CPU nao identificada em $TIME_LOG"
  [[ "$MEMORIA_MAX_KB" =~ ^[0-9]+$ ]] || falha "Pico de memoria nao identificado em $TIME_LOG"
  rm -f -- "$TIME_LOG"
}

gerar_dado() {
  local arquivo="$1"
  if [[ ! -e "$arquivo" ]]; then
    # Escrita atomica: um arquivo parcial nunca fica com o nome final.
    head -c "$TAMANHO_ARQUIVO" /dev/urandom > "$arquivo.tmp"
    mv "$arquivo.tmp" "$arquivo"
  fi
  [[ $(stat -c %s "$arquivo") -eq "$TAMANHO_ARQUIVO" ]] || falha "Tamanho de dado incorreto: $arquivo"
}

# Confere alinhamento LOCAL x REMOTO antes de produzir resultados.
CURRENT='verificacao inicial'
echo 'Verificando os quatro repositorios, servidores e a troca de chaves...'
clone_head_referencia=''
for c in classico pqc; do
  selecionar_cenario "$c"
  ssh_sem_entrada 'true' || falha "SSH indisponivel: $c"
  head_clone="$(ssh_sem_entrada "git --git-dir='$REPO_CLONE' rev-parse refs/heads/main")"
  if [[ -z "$clone_head_referencia" ]]; then
    clone_head_referencia="$head_clone"
  else
    [[ "$head_clone" == "$clone_head_referencia" ]] || falha 'Repositorios clone nao estao na mesma revisao'
  fi
  for op in pull push; do
    repo="$WORK/${op}_${c}"
    alvo="$REPO_PULL"; if [[ "$op" == push ]]; then alvo="$REPO_PUSH"; fi
    [[ -d "$repo/.git" ]] || falha "Repositorio local ausente: $repo"
    [[ "$(git -C "$repo" branch --show-current)" == main ]] || falha "Branch nao e main: $repo"
    [[ -z "$(git -C "$repo" status --porcelain)" ]] || falha "Repositorio com modificacoes: $repo"
    origem="$(git -C "$repo" remote get-url origin)"
    [[ "$origem" == *"$IP"* && "$origem" == *"$alvo"* ]] || falha "origin de $repo nao aponta para $IP:$alvo (origin=$origem)"
    if [[ "$op" == push ]]; then
      [[ -n "$(git -C "$repo" config user.email || true)" && -n "$(git -C "$repo" config user.name || true)" ]] || falha "Identidade Git (user.name/user.email) ausente em $repo"
    fi
    "${GIT_LOCAL[@]}" -C "$repo" fetch --quiet origin main
    [[ "$(git -C "$repo" rev-list --left-right --count HEAD...origin/main)" == $'0\t0' ]] || falha "Repositorio local e remoto fora de sincronia: $repo (reconcilie antes de continuar)"
  done
  ssh_sem_entrada "test -d '$PREP_PULL/.git' -a -d '$REPO_CLONE' -a -d '$REPO_PULL' -a -d '$REPO_PUSH'" || falha "Repositorio no servidor nao encontrado: $c"
  ssh_sem_entrada "test \"\$(git -C '$PREP_PULL' rev-parse HEAD)\" = \"\$(git --git-dir='$REPO_PULL' rev-parse refs/heads/main)\"" || falha "Worktree preparacao pull dessincronizada: $c"
  ssh_sem_entrada "test -n \"\$(git -C '$PREP_PULL' config user.email)\" -a -n \"\$(git -C '$PREP_PULL' config user.name)\"" || falha "Identidade Git ausente em $PREP_PULL ($c)"
  autogc="$(ssh_sem_entrada "git --git-dir='$REPO_PUSH' config --get receive.autogc || true")"
  [[ "$autogc" == false ]] || echo "AVISO ($c): receive.autogc != false em $REPO_PUSH; o gc automatico do servidor pode inflar tempos de push." >&2
done
ntp="$(timedatectl show -p NTPSynchronized --value 2> /dev/null || true)"
[[ "$ntp" == yes ]] || echo "AVISO: sincronizacao NTP nao confirmada neste cliente (valor: '${ntp:-indisponivel}')." >&2

# Criar uma unica saida CSV (e um diretorio interno de dados sinteticos).
mkdir -p "$(dirname "$SAIDA")"
mkdir "$DADOS"
  printf '%s\n' "$CABECALHO" > "$SAIDA"
  {
    echo "execucao=$RODADA"
    echo "inicio_utc=$(date -u +%FT%TZ)"
    echo "host=$(hostname)"
    echo "kernel=$(uname -srm)"
    echo "bash=$BASH_VERSION"
    echo "git=$(git --version)"
    echo "ssh=$("$SSH_BIN" -V 2>&1 || true)"
    echo "script_sha256=$(sha256sum "$0" | cut -d' ' -f1)"
    echo "kex_classico=$KEX_CLASSICO ip_classico=$IP_CLASSICO"
    echo "kex_pqc=$KEX_PQC ip_pqc=$IP_PQC"
    echo "intervalo_s=$INTERVALO_SEGUNDOS tamanho_arquivo=$TAMANHO_ARQUIVO"
    echo "interface_medida=$REDE_IFACE"
    echo 'cpu_memoria=/usr/bin/time -v; CPU e pico RSS do Git e processos filhos'
    echo 'rx_tx=variacao dos contadores da interface; inclui eventual trafego concorrente'
    echo 'tempo_ms=tempo de parede incluindo pequena sobrecarga do GNU time' 
    echo "commit_referencia_clone=$clone_head_referencia"
    echo "ntp_sincronizado=${ntp:-indisponivel}"
  } > "$META"
CSV_ATIVO=1

on_erro() {
  local exit_code="$?"
  # Em subshell ($(...)), deixa o shell principal reportar uma unica vez.
  if [[ "$BASHPID" != "$$" ]]; then return 0; fi
  trap - ERR
  printf '\nERRO durante: %s (codigo %s)\n' "$CURRENT" "$exit_code" >&2
  printf 'Execucao interrompida. CSV parcial preservado: %s\n' "$SAIDA" >&2
  printf 'Para reiniciar do zero, confira e sincronize os repositorios Git antes de uma nova tentativa.\n' >&2
  exit "$exit_code"
}
trap on_erro ERR

for registro in "${PLANO[@]}"; do
  read -r ordem op c rep pasta <<< "$registro"
  CURRENT="ordem=$ordem operacao=$op cenario=$c repeticao=$rep"
  selecionar_cenario "$c"
  echo "[$ordem/180] $op | $c | repeticao $rep"
  hash='-'; commit='-'; arquivo=''; destino=''
  if [[ "$op" != clone ]]; then
    arquivo="$DADOS/${op}_${rep}.bin"
    gerar_dado "$arquivo"
    hash="$(sha256sum "$arquivo")"; hash="${hash%% *}"
    destino="$pasta/tcc_${op}_${RODADA}_${rep}.bin"
  fi

  # Relogio: $EPOCHREALTIME (sem fork de "date" dentro da janela medida), em us.
  case "$op" in
    clone)
      destino_clone="$WORK/clone_${c}_${RODADA}_${rep}"
      [[ ! -e "$destino_clone" ]] || falha "Clone anterior existe: $destino_clone"
      url="ssh://$USUARIO@$IP:$SSH_PORT$REPO_CLONE"
      sleep "$INTERVALO_SEGUNDOS"
      INICIO_UTC="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
      medir_git "${GIT_LOCAL[@]}" clone --quiet "$url" "$destino_clone"
      commit="$(git -C "$destino_clone" rev-parse HEAD)"
      [[ "$commit" == "$clone_head_referencia" ]] || falha 'Clone recebeu um commit diferente da referencia'
      ;;
    pull)
      # Preparar exatamente 1 novo commit no servidor (fora do tempo Git pull).
      repo="$WORK/pull_${c}"
      [[ ! -e "$repo/$destino" ]] || falha "Arquivo ja existe no pull: $destino"
      temporario="/home/tcc/.tcc_${RODADA}_pull_${rep}.bin"
      # Recebe o MESMO dado aleatorio usado pelo outro cenario desta repeticao.
      ssh_com_entrada "cat > '$temporario'" < "$arquivo"
      ssh_com_entrada "bash -s -- '$destino' '$temporario' '$hash' '$rep'" <<'REMOTO_PULL'
set -euo pipefail
die() { echo "REMOTO: $*" >&2; exit 1; }
rel="$1"; tmp="$2"; esperado="$3"; rep="$4"
prep=/home/tcc/flask-pull-preparacao
bare=/home/tcc/flask-pull.git
[[ -f "$tmp" ]] || die "temporario ausente: $tmp"
[[ ! -e "$prep/$rel" ]] || die "arquivo ja existe na preparacao: $rel"
[[ "$(sha256sum "$tmp" | cut -d' ' -f1)" == "$esperado" ]] || die "hash do temporario difere do esperado"
[[ "$(git -C "$prep" rev-parse HEAD)" == "$(git --git-dir="$bare" rev-parse refs/heads/main)" ]] || die "preparacao fora de sincronia com o bare"
mkdir -p "$(dirname "$prep/$rel")"
mv "$tmp" "$prep/$rel"
git -C "$prep" add -- "$rel"
git -c gc.auto=0 -C "$prep" commit -q -m "TCC ${rep}: pull"
git -c gc.auto=0 -C "$prep" push -q "$bare" HEAD:refs/heads/main
REMOTO_PULL
      remoto_head="$(ssh_sem_entrada "git --git-dir='$REPO_PULL' rev-parse refs/heads/main")"
      sleep "$INTERVALO_SEGUNDOS"
      INICIO_UTC="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
      medir_git "${GIT_LOCAL[@]}" -C "$repo" pull --quiet --ff-only origin main
      commit="$(git -C "$repo" rev-parse HEAD)"
      [[ "$commit" == "$remoto_head" ]] || falha 'Pull nao recebeu o commit esperado'
      [[ -f "$repo/$destino" ]] || falha 'Pull nao recebeu o arquivo esperado'
      recebido="$(sha256sum "$repo/$destino")"; recebido="${recebido%% *}"
      [[ "$recebido" == "$hash" ]] || falha 'Arquivo recebido com hash diferente'
      ;;
    push)
      # Preparar exatamente 1 novo commit no CLIENTE (fora do tempo Git push).
      repo="$WORK/push_${c}"
      [[ ! -e "$repo/$destino" ]] || falha "Arquivo ja existe no push: $destino"
      [[ -z "$(git -C "$repo" status --porcelain)" ]] || falha "Push com modificacoes locais: $repo"
      [[ "$(git -C "$repo" rev-list --left-right --count HEAD...origin/main)" == $'0\t0' ]] || falha "Push fora de sincronia: $repo"
      mkdir -p "$(dirname "$repo/$destino")"
      cp "$arquivo" "$repo/$destino"
      git -C "$repo" add -- "$destino"
      git -C "$repo" commit -q -m "TCC ${rep}: push"
      commit="$(git -C "$repo" rev-parse HEAD)"
      [[ "$(git -C "$repo" rev-list --left-right --count HEAD...origin/main)" == $'1\t0' ]] || falha "Push nao tem exatamente 1 commit"
      sleep "$INTERVALO_SEGUNDOS"
      INICIO_UTC="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
      medir_git "${GIT_LOCAL[@]}" -C "$repo" push --quiet origin main
      remoto_head="$(git -C "$repo" ls-remote origin refs/heads/main)"
      remoto_head="${remoto_head%%$'\t'*}"
      [[ "$remoto_head" == "$commit" ]] || falha 'Push nao chegou ao servidor'
      recebido="$(sha256sum "$repo/$destino")"; recebido="${recebido%% *}"
      [[ "$recebido" == "$hash" ]] || falha 'Arquivo do push alterado'
      ;;
  esac

  # Duracao em microssegundos -> ms com 3 casas. O relogio deve permanecer estavel.
  duracao_us=$((10#$fim - 10#$inicio))
  (( duracao_us > 0 )) || falha "Duracao invalida em $CURRENT"
  printf -v ms '%d.%03d' "$((duracao_us/1000))" "$((duracao_us%1000))"
  printf '%s,%s,%s,%s,%s,%s,sucesso,%s,%s,%s,%s,%s,%s,%s\n' \
    "$ordem" "$op" "$c" "$rep" "$pasta" "$ms" "$commit" "$hash" "$INICIO_UTC" \
    "$CPU_PERCENTUAL" "$MEMORIA_MAX_KB" "$RX_BYTES" "$TX_BYTES" >> "$SAIDA"
  echo "  Tempo: $ms ms | CPU: $CPU_PERCENTUAL% | Memoria: $MEMORIA_MAX_KB KB | RX: $RX_BYTES B | TX: $TX_BYTES B | sucesso"
done
trap - ERR
CURRENT='resumo'

# Resumo rapido apenas para conferencia (a analise estatistica fica a seu cargo).
printf '\nResumo (ms): operacao/cenario | n | mediana | media\n'
for op in clone pull push; do
  for cen in classico pqc; do
    awk -F, -v o="$op" -v c="$cen" 'NR > 1 && $2 == o && $3 == c { print $6 }' "$SAIDA" | sort -n |
      awk -v k="$op/$cen" '{ a[NR] = $1; s += $1 }
        END { if (NR) printf "  %-14s | %3d | %9.3f | %9.3f\n", k, NR, (NR % 2 ? a[(NR+1)/2] : (a[NR/2] + a[NR/2+1]) / 2), s / NR }'
  done
done
printf '\nEXPERIMENTO CONCLUIDO: 180 operacoes; resultados em %s\n' "$SAIDA"
