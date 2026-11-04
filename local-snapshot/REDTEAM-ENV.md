# 红队环境：本机实况（2026-11-03 12:47）

配套文件：`install-darwin.sh`（工具箱安装器）、`vps.sh`（反弹 Shell 控制台）、`toolkit-versions.md`（版本表）。

## 一、为什么不用上游 `setup.sh`

上游 `$DSH_HOME/redteam/setup.sh` 假设 **Kali / Linux x86_64**：一律下 `linux_amd64` ELF，系统工具靠 `apt`。
本机是 **macOS 27.0.1 / arm64**，直接跑会下一堆跑不起来的 ELF。

因此：

- 二进制一律按 **darwin_arm64** 取，落 **同一套目录布局**（`toolkit/<tool>/<bin>`），让技能里写死的绝对路径直接命中。
- 系统工具走 **Homebrew**。
- 本机 `setup.sh` 只改了一行：`BIN[suo5]` 指向 `toolkit/suo5/suo5`（darwin 版）；`suo5-linux-amd64` 保留给目标端投递。备份在 `setup.sh.bak-mac`。

## 二、已就位

### 工具箱（`$DSH_HOME/redteam/toolkit/`，共 854 MB / 18 个目录）

| 类别 | 工具 |
| --- | --- |
| 内网扫描 | `fscan` 2.2.2 · `gogo` v2.15.0 · `naabu` · `ksubdomain` |
| 子域/解析 | `subfinder` 2.17.0 · `dnsx` · `OneForAll` 0.4.5（源码+venv） |
| HTTP 探测 | `httpx`（+ `~/.local/bin/pd-httpx`）· `nuclei` 3.11.1（模板 14104 个）· `gowitness` · `whatweb` 0.6.4 |
| 目录爆破 | `dirsearch` 0.5.0 |
| 隧道代理 | `chisel` 1.12.0 · `frpc`/`frps` 0.71.1 · `suo5` 2.2.0 · `ligolo-ng` 0.9.2（proxy+agent） |
| WebShell | `Behinder` 4.1（`Behinder.jar` 127 MB + `server/` 八套马模板） |
| VPS 控制 | `vps.sh`（13 个子命令，见下） |

### PATH 工具（Homebrew）

`nmap` 7.993 · `masscan` 1.3.2 · `sqlmap` 1.10.11 · `ffuf` 2.3.0 · `feroxbuster` 2.13.1 · `gobuster` 3.8.2 · `hydra` 9.7 · `hashcat` 8.0.0 · `john` 1.9.0 · `nikto` 2.6.1 · `amass` 5.1.3 · `socat` 1.8.1.3 · `tmux` 3.8 · `proxychains4` 4.17 · `searchsploit`（exploitdb）· `wpscan` 4.2.0 · `theHarvester` 4.11.1 · `whatweb` 0.6.4 · `nuclei` 3.11.1

### 平台补丁

- **Rosetta 2** 已装 —— `ksubdomain` 官方只发 Intel mac 包，靠转译运行。
- `nuclei` 模板实体在 `~/.local/nuclei-templates`，`~/nuclei-templates` 是软链（两边都能找到，`setup.sh` 的 `find` 也能数到）。
- **Java**：Amazon Corretto **11.0.30**；`Behinder.jar` 字节码是 Java 8（major 52），可跑。

## 三、四项的处置：全部不配（结论，2026-11-03）

判断依据与取舍细节见 [`这套装备干什么用.md`](这套装备干什么用.md)。摘要：

| 项 | 能不能简单配 | 结论 | 原因 |
| --- | --- | --- | --- |
| `FOFA_KEY` | 能 | **不配** | 手上没有 key；不填则降级为 crt.sh + subfinder/ksubdomain + 被动 DNS |
| VPS（落地机） | 能，但选哪台是生产决策 | **不配** | 探活 5 台候选，通的两台是游戏中继机与办公室看板服务器，都是业务机，不适合开 9000-9999 监听、落载荷 |
| `msfconsole` | 不能 | **不配** | cask 因 Gatekeeper 于 2026-09-01 被禁用，官方只发 Linux 包；本机 nc/socat/suo5/chisel 可替代 |
| `Godzilla` | 不能 | **不配** | 无官方公开仓库，不从不明源拉 jar；冰蝎 4.1 已装，功能重叠 |

`AntSword` 蚁剑同样未装：技能写死 `linux-x64` 路径，mac 要另取并改路径，属可选。

**顺手补的**：`toolkit/wordlists/` 7 份 SecLists 常用字典（3.3 MB，含 `common.txt`、`raft-*`、`dir-2.3-medium.txt`、`pass-top10k.txt`）—— 没有字典时 ffuf/dirsearch/gobuster 都是空转。

将来要落地时按 [`这套装备干什么用.md`](这套装备干什么用.md) 末节的四行命令补，一分钟的事。

## 四、`vps.sh` 用法

```bash
VPS=~/.dsh/redteam/toolkit/vps/vps.sh
$VPS status                        # 身份/系统/工具/9000-9999 占用/tmux 会话
$VPS listen                        # 自动挑空闲端口开持久监听（socat→nc→python 三级回退）
$VPS send 9000 'id; uname -a'      # 往已上线的反弹 Shell 下发命令
$VPS read 9000 60                  # 读回输出
$VPS kill 9000                     # 用完清理
$VPS serve 9008 /tmp               # 起 HTTP 载荷服务
$VPS push ./payload /tmp/          # 上传
$VPS get /tmp/loot.txt ./          # 取回
$VPS sh 'ss -lntp'                 # 直通执行
```

配置从 `.env` 读，也支持临时覆盖：`VPS_HOST=ubuntu@1.2.3.4 VPS_KEY=/path/key vps.sh status`。
未配置时退出码 2 并打印三种配法，不会挂死。

## 五、换机复现

```sh
# 1. 系统工具（macOS）
brew install nmap masscan sqlmap ffuf feroxbuster gobuster hydra hashcat john-jumbo \
             socat tmux nikto amass proxychains-ng exploitdb theharvester

# 2. 工具箱
bash local-snapshot/redteam/install-darwin.sh          # 幂等，可加 --check / --force

# 3. 剩下的手工项
gem install --user-install wpscan && ln -sfn ~/.gem/ruby/*/bin/wpscan ~/.local/bin/wpscan
git clone --depth 1 https://github.com/urbanadventurer/WhatWeb.git ~/.dsh/redteam/toolkit/whatweb
printf '#!/usr/bin/env bash\nexec ruby %s/whatweb "$@"\n' ~/.dsh/redteam/toolkit/whatweb > ~/.local/bin/whatweb && chmod +x ~/.local/bin/whatweb
gh release download --repo rebeyond/Behinder --pattern '*.zip' && unzip -d ~/.dsh/redteam/toolkit/Behinder  # 冰蝎 4.1
softwareupdate --install-rosetta --agree-to-license    # ksubdomain 需要
nuclei -update-templates && mv ~/nuclei-templates ~/.local/nuclei-templates
```
