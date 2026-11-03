# 从快照恢复

目标：在新机器（或重装后的同一台）恢复到 2026-11-03 12:29 的运行状态。

## 0. 前置

- 官方桌面 DeepSeek Harness **0.2.0-rc.2**（桌面 EXE）或官方 `dsh web`。
- Node.js **≥ 18**（Windows 无闪窗要 ≥ 22）。
- 确认真正在用的 `$DSH_HOME`：里面有 `profiles/desktop/package.json`，且 `"name": "dsh-profile-desktop"`。
  本机是 `~/.dsh`；便携包可能落在启动器旁边的 `.dsh`。

## 1. 代码树

仓库本身就是 1.1.71 的完整源码，直接放进 profile 依赖：

```sh
git clone https://github.com/kkunkunya/dsh-purge.git "$DSH_HOME/plugins/dsh-purge"
```

## 2. profile 接线

编辑 `$DSH_HOME/profiles/desktop/package.json`，对照 [`profiles-desktop.package.json`](profiles-desktop.package.json)：

```json
{
  "name": "dsh-profile-desktop",
  "private": true,
  "dependencies": {
    "dsh-purge": "file:../../plugins/dsh-purge"
  },
  "dsh": {
    "profile": {
      "bundles": [
        "@deepseek-ai/dsh-base",
        "@deepseek-ai/dsh-web-app",
        "dsh-purge"
      ]
    }
  }
}
```

`"dsh-purge"` 必须排在 bundles **末尾**，且只写一次。装依赖：

```sh
cd "$DSH_HOME/profiles/desktop" && pnpm install
```

成功标志：出现 `profiles/desktop/node_modules/dsh-purge/package.json`。

## 3. 配置层

```sh
# 注入正文
cp local-snapshot/prompt-inject.md "$DSH_HOME/prompt-inject.md"

# profile 覆盖层：先备份现有的
cp "$DSH_HOME/profiles/desktop/cordis.patch.yml" "$DSH_HOME/profiles/desktop/cordis.patch.yml.bak-restore"
cp local-snapshot/profiles-desktop.cordis.patch.yml "$DSH_HOME/profiles/desktop/cordis.patch.yml"
```

> `cordis.patch.yml` 里有 `baseURL: http://127.0.0.1:3425/v1`（本机 magpie 网关）。
> 新机器网关地址不同就改这三处；`apiKeyEnv` 引用的是环境变量名，别把真密钥写进文件。

状态戳不必手工拷；应用补丁时插件会自己写
`$DSH_HOME/dsh-purge/{applied.json,installed-rev,override-state.json,unpacked-asar.json}`。

## 4. 应用

1. 完全退出宿主（桌面端退出托盘，Web 端停 `dsh web`）。
2. 重新启动。
3. 会话标题旁点 **dsh-purge** → **清洗** → **应用**。
4. 成功后插件自动重启一次；没打完补丁不会重启，直接看哪些是 pending。

## 5. 验收

```sh
# 代码树是否与本快照一致
shasum -a 256 -c local-snapshot/package-files.sha256     # 需在插件根目录执行
# 清单汇总
shasum -a 256 local-snapshot/package-files.sha256         # 应得 8e06987ce2b1b8...
```

聊天里 `/purge status`：

- `DSH_HOME` 指向你实际启动的那一份
- 补丁计数应为 `66/68 applied`（本机是 #71、#80 跳过）
- `注入文件` 指向 `$DSH_HOME/prompt-inject.md`
- 桌面端若提示「app.asar 还在，补丁写在解开目录，当前进程读不到」——重启宿主后重看

## 6. 退化排查

| 现象 | 排查 |
| --- | --- |
| 补丁全显示 skipped | 宿主版本对不上（本快照只适配 0.2），或改错了另一份 `.dsh` |
| 模型自称 Claude / DeepSeek | 注入走到空路径：检查 `prompt-inject.md` 是否存在且非空，看 `inject.read` 日志的 `bytes` |
| 任务到一半「苏醒」开始拒 | 补丁被宿主升级冲掉，重新进清洗点应用；或用 `dsh-purge --apply` |
| 二轮立刻发被拒 | 确认 profile 已加载本插件（#85 followup），然后重启宿主 |
| 命令一直前台等待 | 检查是否有人把 `timeoutMs` 又调大（#21 已恢复官方 60s） |
