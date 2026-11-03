#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 红队工具箱 —— darwin/arm64 版安装器
#
# 上游 setup.sh 假设 Kali/Linux x86_64，会下 linux_amd64 ELF，在 macOS 上跑不起来。
# 本脚本沿用同一套目录布局（$DSH_HOME/redteam/toolkit/<tool>/<bin>），
# 但一律取 darwin_arm64 资产，好让技能里写死的绝对路径直接命中。
#
#   bash install-darwin.sh            # 装缺的
#   bash install-darwin.sh --check    # 只体检
#   bash install-darwin.sh --force    # 强制重下
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
TK="$DSH_HOME/redteam/toolkit"
TMP="$TK/.tmp"
CHECK_ONLY=0
FORCE=0

for a in "$@"; do
  case "$a" in
    --check) CHECK_ONLY=1 ;;
    --force) FORCE=1 ;;
  esac
done

mkdir -p "$TK" "$TMP" "$HOME/.local/bin"

OK=$'\033[32m'; WARN=$'\033[33m'; ERR=$'\033[31m'; DIM=$'\033[2m'; OFF=$'\033[0m'
ok()   { printf "  ${OK}✓${OFF} %s\n" "$*"; }
warn() { printf "  ${WARN}!${OFF} %s\n" "$*"; }
bad()  { printf "  ${ERR}✗${OFF} %s\n" "$*"; }
dim()  { printf "  ${DIM}%s${OFF}\n" "$*"; }
hd()   { printf "\n── %s ────────────────────────────────\n" "$*"; }

need() { [ -x "$1" ] && [ "$FORCE" != 1 ] && return 1 || return 0; }

# ghdl <repo> <pattern> <outdir>  → 下载匹配的 release 资产到 outdir
ghdl() {
  local repo="$1" pat="$2" out="$3"
  rm -rf "$out"; mkdir -p "$out"
  gh release download --repo "$repo" --pattern "$pat" --dir "$out" --clobber >/dev/null 2>&1
  local n
  n=$(find "$out" -type f | wc -l | tr -d ' ')
  [ "$n" -gt 0 ]
}

# pick <dir> <name>  → 解压后文件名常带版本号：精确名 → 前缀名（排除 nolocal/web）→ 任意前缀 → 最大文件
pick() {
  local d="$1" n="$2" f=""
  f="$(find "$d" -type f -name "$n" ! -name "*.txt" ! -name "*.zip" ! -name "*.gz" 2>/dev/null | head -1)"
  [ -n "$f" ] && { printf '%s' "$f"; return; }
  f="$(find "$d" -type f -name "${n}[-_.]*" ! -name "*nolocal*" ! -name "*web*" ! -name "*.txt" ! -name "*.zip" ! -name "*.gz" 2>/dev/null | head -1)"
  [ -n "$f" ] && { printf '%s' "$f"; return; }
  f="$(find "$d" -type f -name "${n}*" ! -name "*.txt" ! -name "*.zip" ! -name "*.gz" 2>/dev/null | head -1)"
  [ -n "$f" ] && { printf '%s' "$f"; return; }
  ls -S "$d"/* 2>/dev/null | grep -vE "\.(txt|zip|gz|tar)$" | head -1
}

verify() { # verify <path> → 能跑起来（截断/错架构会失败）
  local p="$1"
  [ -x "$p" ] || return 1
  # 投递到目标的 Linux 二进制在本机不跑，只看格式完整
  case "$(basename "$p")" in
    *linux*) file "$p" 2>/dev/null | grep -q "ELF" && return 0 || return 1 ;;
  esac
  file "$p" 2>/dev/null | grep -q "Mach-O" || return 1
  "$p" -h >/dev/null 2>&1 || "$p" --help >/dev/null 2>&1 || "$p" -version >/dev/null 2>&1 || "$p" version >/dev/null 2>&1
}

install_bin() { # install_bin <名字> <repo> <pattern> <解压后二进制名> <目标路径>
  local name="$1" repo="$2" pat="$3" binname="$4" dest="$5"
  if [ -x "$dest" ] && [ "$FORCE" != 1 ]; then
    if verify "$dest" >/dev/null 2>&1; then ok "$name 已就位（$(basename "$dest")）"; return 0; fi
    warn "$name 存在但跑不起来，重下"
  fi
  [ "$CHECK_ONLY" = 1 ] && { warn "$name 缺失"; return 1; }
  dim "$name ← $repo ($pat)"
  local d="$TMP/$name"
  if ! ghdl "$repo" "$pat" "$d"; then bad "$name 下载失败"; return 1; fi
  # 解压
  local f
  for f in "$d"/*; do
    case "$f" in
      *.zip) python3 -c "import zipfile,sys;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$f" "$d" 2>/dev/null ;;
      *.tar.gz|*.tgz) tar xzf "$f" -C "$d" 2>/dev/null ;;
      *.gz) gunzip -f "$f" 2>/dev/null ;;
    esac
  done
  local found
  found="$(pick "$d" "$binname")"
  [ -z "$found" ] && found="$(find "$d" -type f -perm +111 ! -name "*.zip" ! -name "*.gz" ! -name "*.txt" | head -1)"
  [ -z "$found" ] && { bad "$name 解压后没找到 $binname"; return 1; }
  mkdir -p "$(dirname "$dest")"
  cp -f "$found" "$dest" && chmod +x "$dest"
  if verify "$dest" >/dev/null 2>&1; then ok "$name → $dest"; else warn "$name 已落地但自检未通过（可能架构不符）"; fi
}

hd "① 单二进制工具（darwin_arm64）"
install_bin fscan      shadow1ng/fscan        '*mac_arm64*'                  fscan     "$TK/fscan/fscan"
install_bin gogo       chainreactors/gogo     'gogo_darwin_arm64'            gogo      "$TK/gogo/gogo"
install_bin suo5-mac   zema1/suo5             'suo5-darwin-arm64'            suo5-darwin-arm64 "$TK/suo5/suo5-darwin-arm64"
install_bin suo5-linux zema1/suo5             'suo5-linux-amd64'             suo5-linux-amd64  "$TK/suo5/suo5-linux-amd64"
install_bin chisel     jpillora/chisel       'chisel_*_darwin_arm64.gz'     chisel    "$TK/chisel/chisel"
install_bin gowitness  sensepost/gowitness    'gowitness-*-darwin-arm64'     gowitness "$TK/gowitness/gowitness"

hd "② ProjectDiscovery 四件套（解压 zip）"
install_bin subfinder  projectdiscovery/subfinder 'subfinder_*_macOS_arm64.zip' subfinder "$TK/subfinder/subfinder"
install_bin dnsx       projectdiscovery/dnsx      'dnsx_*_macOS_arm64.zip'      dnsx      "$TK/dnsx/dnsx"
install_bin naabu      projectdiscovery/naabu     'naabu_*_macOS_arm64.zip'     naabu     "$TK/naabu/naabu"
install_bin httpx      projectdiscovery/httpx     'httpx_*_macOS_arm64.zip'     httpx     "$TK/httpx/httpx"
install_bin nuclei     projectdiscovery/nuclei    'nuclei_*_macOS_arm64.zip'    nuclei    "$TK/nuclei/nuclei"

hd "③ frp / ligolo / ksubdomain"
if [ -x "$TK/frp/frpc" ] && [ -x "$TK/frp/frps" ] && [ "$FORCE" != 1 ]; then
  ok "frp 已就位"
elif [ "$CHECK_ONLY" = 1 ]; then warn "frp 缺失"
else
  d="$TMP/frp"; if ghdl fatedier/frp 'frp_*_darwin_arm64.tar.gz' "$d"; then
    for f in "$d"/*.tar.gz; do tar xzf "$f" -C "$d" 2>/dev/null; done
    mkdir -p "$TK/frp"
    cp -f "$(pick "$d" frpc)" "$TK/frp/frpc" && chmod +x "$TK/frp/frpc"
    cp -f "$(pick "$d" frps)" "$TK/frp/frps" && chmod +x "$TK/frp/frps"
    ok "frp → $TK/frp/{frpc,frps}"
  else bad "frp 下载失败"; fi
fi

if [ -x "$TK/ligolo/proxy" ] && [ -x "$TK/ligolo/agent" ] && [ "$FORCE" != 1 ]; then
  ok "ligolo-ng 已就位"
elif [ "$CHECK_ONLY" = 1 ]; then warn "ligolo-ng 缺失"
else
  mkdir -p "$TK/ligolo"
  for pair in "proxy:proxy:ligolo-ng_proxy_*_darwin_arm64.tar.gz" "agent:agent:ligolo-ng_agent_*_darwin_arm64.tar.gz"; do
    nm="${pair%%:*}"; rest="${pair#*:}"; binname="${rest%%:*}"; pat="${rest#*:}"
    d="$TMP/lig-$nm"
    if ghdl nicocha30/ligolo-ng "$pat" "$d"; then
      for f in "$d"/*.tar.gz; do tar xzf "$f" -C "$d" 2>/dev/null; done
      cp -f "$(pick "$d" "$binname")" "$TK/ligolo/$binname" && chmod +x "$TK/ligolo/$binname" && ok "ligolo $binname"
    else bad "ligolo $binname 下载失败"; fi
  done
fi

if [ -x "$TK/ksubdomain/ksubdomain" ] && [ "$FORCE" != 1 ]; then
  ok "ksubdomain 已就位"
elif [ "$CHECK_ONLY" = 1 ]; then warn "ksubdomain 缺失"
else
  d="$TMP/ksub"; if ghdl knownsec/ksubdomain 'ksubdomain_mac.zip' "$d"; then
    python3 -c "import zipfile,sys;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$d"/*.zip "$d" 2>/dev/null
    mkdir -p "$TK/ksubdomain"
    found="$(find "$d" -type f -name 'ksubdomain*' ! -name '*.zip' | head -1)"
    if [ -n "$found" ]; then cp -f "$found" "$TK/ksubdomain/ksubdomain"; chmod +x "$TK/ksubdomain/ksubdomain"; ok "ksubdomain"; else warn "ksubdomain 包内结构未知，跳过"; fi
  else bad "ksubdomain 下载失败"; fi
fi

hd "④ 包装与 PATH"
if [ -x "$TK/httpx/httpx" ]; then
  printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$TK/httpx/httpx" > "$HOME/.local/bin/pd-httpx"
  chmod +x "$HOME/.local/bin/pd-httpx"; ok "pd-httpx → $TK/httpx/httpx"
fi
if [ -x "$TK/nuclei/nuclei" ]; then
  ln -sf "$TK/nuclei/nuclei" "$HOME/.local/bin/nuclei"; ok "nuclei → ~/.local/bin/nuclei"
fi

hd "⑤ OneForAll（python 源码 + venv）"
OF_DIR="$TK/oneforall/OneForAll-0.4.5"
if [ -f "$OF_DIR/oneforall.py" ]; then
  ok "OneForAll 源码已就位"
elif [ "$CHECK_ONLY" = 1 ]; then warn "OneForAll 缺失"
else
  mkdir -p "$TK/oneforall"
  if curl -sL --retry 3 -m 300 "https://github.com/shmilylty/OneForAll/archive/refs/tags/v0.4.5.tar.gz" -o "$TK/oneforall/of.tar.gz" \
     && python3 -c "import tarfile;tarfile.open('$TK/oneforall/of.tar.gz').extractall('$TK/oneforall')" 2>/dev/null; then
    ok "OneForAll 源码就位"
  else bad "OneForAll 源码下载失败"; fi
fi
if [ -f "$OF_DIR/oneforall.py" ] && [ ! -x "$OF_DIR/.venv/bin/python" ]; then
  dim "建 venv 并装依赖（1-2 分钟）"
  ( cd "$OF_DIR" && python3 -m venv .venv >/dev/null 2>&1 \
    && .venv/bin/python -m pip install -q --no-cache-dir --upgrade pip setuptools wheel >/dev/null 2>&1 \
    && .venv/bin/python -m pip install -q --no-cache-dir requests exrex fire beautifulsoup4 dnspython loguru tqdm PySocks tenacity termcolor treelib colorama future "SQLAlchemy<2" >/dev/null 2>&1 ) \
    && ok "OneForAll 依赖就绪" || warn "OneForAll 依赖安装失败"
elif [ -x "$OF_DIR/.venv/bin/python" ]; then ok "OneForAll venv 已存在"; fi

hd "⑥ dirsearch（技能引用 $TK/dirsearch/dirsearch）"
if [ -f "$TK/dirsearch/dirsearch" ] && [ "$FORCE" != 1 ]; then
  ok "dirsearch 已存在"
elif [ "$CHECK_ONLY" = 1 ]; then warn "dirsearch 缺失"
else
  mkdir -p "$TK/dirsearch"
  if [ ! -d "$TK/dirsearch/repo/.git" ]; then
    git clone --depth 1 https://github.com/maurosoria/dirsearch.git "$TK/dirsearch/repo" >/dev/null 2>&1
  fi
  if [ -f "$TK/dirsearch/repo/dirsearch.py" ]; then
    ( cd "$TK/dirsearch/repo" && python3 -m venv .venv >/dev/null 2>&1 && .venv/bin/pip install -q -r requirements.txt >/dev/null 2>&1 ) || true
    printf '#!/usr/bin/env bash\nexec "%s/repo/.venv/bin/python" "%s/repo/dirsearch.py" "$@"\n' "$TK/dirsearch" "$TK/dirsearch" > "$TK/dirsearch/dirsearch"
    chmod +x "$TK/dirsearch/dirsearch"
    ok "dirsearch → $TK/dirsearch/dirsearch"
  else warn "dirsearch 克隆失败"; fi
fi

hd "⑦ 体检表"
for p in fscan/fscan gogo/gogo suo5/suo5-darwin-arm64 suo5/suo5-linux-amd64 chisel/chisel \
         frp/frpc frp/frps subfinder/subfinder dnsx/dnsx naabu/naabu httpx/httpx nuclei/nuclei \
         ksubdomain/ksubdomain ligolo/proxy ligolo/agent gowitness/gowitness dirsearch/dirsearch; do
  f="$TK/$p"
  if [ -x "$f" ]; then ok "$p"; else bad "$p"; fi
done
for c in nmap masscan sqlmap ffuf feroxbuster gobuster hydra hashcat john socat tmux nikto amass proxychains4 searchsploit nuclei; do
  if command -v "$c" >/dev/null 2>&1; then ok "PATH: $c"; else bad "PATH: $c"; fi
done

rm -rf "$TMP"
printf "\n完成。缺的项见上面 ✗。\n"
