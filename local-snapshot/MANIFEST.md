# dsh-purge 本机运行副本快照

保存时间：2026-11-03 12:29（-0600）

## 这份快照是什么

本机正**在跑**的那一份 `dsh-purge`，加上它在 `$DSH_HOME` 里的全部运行时配置。
存进本仓库的目的：换机器、宿主升级、插件被 npm 覆盖时，能按原样恢复。

## 版本与来源

| 项 | 值 |
| --- | --- |
| 插件版本 | `1.1.71`（`package.json`） |
| 本机安装方式 | profile `desktop` 的 `dependencies`：`"dsh-purge": "github:mmparko/dsh-purge"` |
| 上游署名 | `YuJunZhiXue/dsh-purge`（MIT，README 内含署名要求） |
| 本仓库 | `kkunkunya/dsh-purge`，快照时 master = `033e6bd` |
| 宿主 | 官方桌面 DeepSeek Harness `0.2.0-rc.2` |
| DSH_HOME | `/Users/kunkun/.dsh` |
| 补丁状态 | 66/68 applied；#71（梁神）、#80（极简工具表）skipped —— 本机没有对应文件，属正常 |

## 一致性结论（重要）

本机 `profiles/desktop/node_modules/dsh-purge` 与本仓库 master 工作树做逐字节比对：

```
diff -rq --exclude=.git . ~/.dsh/profiles/desktop/node_modules/dsh-purge
```

结果：**104/104 个文件完全一致，零差异**。
仓库只多出 5 个发布时被 `files` 白名单排除的文件：

- `.github/workflows/release.yml`
- `.gitignore`
- `.npmignore`
- `MIRROR-NOTICE.md`
- `release-notes.md`

也就是说：本仓库的代码树**已经等于**本机在跑的那份，这份快照补的是**配置层**（注入稿、profile 覆盖层、状态戳、校验清单）。

## 校验值

- 本机副本 104 个文件的逐文件 sha256：[`package-files.sha256`](package-files.sha256)
- 该清单的汇总 digest：`8e06987ce2b1b84fad76e519d1b49d8e58db54cc586ffe791a2307b8b1f2fa12`
- 关键文件：

| 文件 | sha256 |
| --- | --- |
| `lib/index.js` | `f3be69ec781aaae20780f5d40d5599120cc84f93bed123d009a1ef6b6e6080c6` |
| `lib/core.js` | `1bd1e83a45be6835620a3bbcd2007239a6aa4fcb584665cb9130be243f32369b` |
| `lib/identity.js` | `86ccee3166d36d6f0f48db0d57a6d8eac88691e9a52eefc5b7281fe2722c44ee` |
| `lib/asset-table.js` | `ce1321ecb003a0d3595ff8140d6f5740829aba9f086e4d343171e6b91a91fb6b` |
| `lib/table-key.js` | `cd7ab3512992f35f5bc08150da245f60bf4f11efbf83f3120583a8e7ef821cda` |
| `client.js` | `586a25ce79bd135bf7104b5f0f41121b17f2bbbc266562ed2744a73f04d6bf91` |
| `cordis.patch.yml` | `ca912d9cbc6474a5083be8e301107cb5c34a24f71b562260085b71e806d1a444` |
| `package.json` | `080b2b368096cc9d88e306b20bebe04a005637954e1331aced14de5c97cab4f1` |

## 快照内容

| 路径 | 是什么 |
| --- | --- |
| `prompt-inject.md` | 实际注入到系统提示最前的正文（25128 字节，用户文件，`revert` 不删） |
| `profiles-desktop.cordis.patch.yml` | profile 覆盖层（46 KB：模型路由、工具上限、沙箱超时等） |
| `profiles-desktop.package.json` | profile 依赖与 bundle 顺序 |
| `dsh-purge-state/applied.json` | 已应用版本戳 `1.1.71` |
| `dsh-purge-state/installed-rev` | 对应 `apply:1.1.71` |
| `dsh-purge-state/override-state.json` | 提示词自定义指纹（防止插件更新覆盖用户改过的稿） |
| `dsh-purge-state/unpacked-asar.json` | 桌面 asar 解包身份（size + mtime） |
| `dsh-purge-state/desktop-install.txt` | 桌面安装路径 |
| `package-files.sha256` | 本机副本逐文件校验值 |
| [`REDTEAM-ENV.md`](REDTEAM-ENV.md) | 红队环境实况：23 个技能、工具链清单、平台适配（darwin_arm64/Rosetta）、未完成项、换机复现 |
| [`redteam/install-darwin.sh`](redteam/install-darwin.sh) | 工具箱安装器（darwin_arm64，幂等，`--check` / `--force`） |
| [`redteam/vps.sh`](redteam/vps.sh) | 反弹 Shell 控制台（13 子命令，从 `.env` 读 VPS 配置） |
| [`redteam/toolkit-versions.md`](redteam/toolkit-versions.md) | 工具箱各二进制版本与架构 |

## 未纳入的（留在本机）

- `$DSH_HOME/AGENTS.md`：个人与公司工作规矩，与本插件无关。
- `$DSH_HOME/skills/*`：均为指向 `~/.config/magpie/library/skills` 的符号链接，快照无意义。
- `$DSH_HOME/rules/`、`redteam/engagements/`：本机当前为空或非插件产物。
- 任何密钥：`cordis.patch.yml` 只引用环境变量名（`MAGPIE_GATEWAY_KEY` / `OPENAI_API_KEY`），无明文密钥。

## 注意

`prompt-inject.md` 是本机的自定义注入稿。本仓库为公开仓库，保存即公开可见；
要收回请把仓库转为 private，或删掉该文件后再推送。

## 机制索引（对应 1.1.71 的六层）

| 层 | 位置 |
| --- | --- |
| 提示词置顶与去重 | `lib/identity.js` → `leadWithInject` / `injectMatchers` / `GLOBAL_PROMPT_ORDER` |
| 宿主身份与拒绝话术中和 | `lib/identity.js` → `stripHarnessPersona`（30 余条正则，渲染期执行） |
| 审批与沙箱授权 | `lib/core.js` → `CODE_PATCHES` / `ENGINE_PATCHES`（#6–#17、#35、#59–#63） |
| 多轮不衰减 | `lib/core.js` #18/#19；`lib/index.js` 全文注入与 v10 四重 fallback；`lib/identity.js` → `installAssembleGuard` |
| 引擎健壮性 | `lib/core.js` #55/#57/#66–#69/#72/#74/#85/#87 |
| 持久化与自愈 | `lib/reapply.js`、`lib/extract-asar.js`、`lib/overlay`、`bin/dsh-purge.js` |
