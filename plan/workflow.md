# Phase-Contract 执行流程说明

本文件说明 Phase-Contract Workflow 如何确保全部任务按既定顺序、完整执行，以及在 AI 上下文压缩后如何继续执行。

## 环境前提

本仓库必须是 git 工作区（`git rev-parse --is-inside-work-tree` 返回 `true`）。`scripts/planctl` 的 `advance` / `next` / `resolve` / `complete` / `handoff` 在检测到非 git 工作区时会以 **exit code 3** 拒绝运行（`status` 只打警告不拦截，保证诊断可用）。仅当确需不使用 git 时，可通过 `PHASE_CONTRACT_ALLOW_NON_GIT=1` 环境变量显式绕过，且必须在 `plan/common.md` 中记录偏离风险与补偿方案。

## 目标

这套流程要解决四个问题：

- 如何开始执行全部 plan
- 如何保证 phase 顺序不能被跳过
- 如何保证每个 phase 真正完成后才进入下一个 phase
- 如何在 AI 压缩或新会话后继续执行，而不是从头手工判断

## 核心角色

### `plan/manifest.yaml`

这是唯一的流程定义来源，负责声明：

- phase 顺序
- depends_on 依赖关系
- 每个 phase 的 `plan_file`
- 每个 phase 的 `execution_file`
- 每次执行必须读取的 `required_context`
- 连续执行和压缩恢复规则

顺序和边界都以它为准，不以聊天历史或人工记忆为准。

### `plan/common.md`

这是全局硬约束。任何 phase 执行都必须带上它，用来保证长期约束不会在局部执行时丢失。

### `plan/phases/*.md`

这是阶段蓝图，定义每个 phase 的：

- 阶段定位
- 阶段目标
- 实施范围
- 本阶段产出
- 明确不做
- 完成判定

它负责说明“这个阶段是什么”和“做到什么程度”。

### `plan/execution/*.md`

这是执行合同，定义一次实际执行时的：

- 必带上下文
- 本次允许改动
- 本次不要做
- 交付检查
- 执行裁决规则

它负责限制这次执行能改什么、不能改什么，以及如何判断当前 phase 是否真的完成。

### `scripts/planctl`

这是唯一的流程入口，负责把 manifest 中的定义转成可执行流程。主要命令有：

- `resolve`: 解析指定 phase 的上下文和依赖
- `next`: 找到当前应该执行的下一个 phase
- `advance`: 输出连续执行状态机的下一动作（implement / promote_placeholder / finalize / stop）
- `lint-contracts`: 检查当前正式合同是否具备稳定 marker、非空 `allowed_paths`、required checks 与可落地的 Production Wiring
- `status`: 展示已完成、可执行、被阻塞的 phase
- `complete`: 在 phase 真完成后把状态写回 `plan/state.yaml`
- `handoff`: 生成或刷新 `plan/handoff.md`
- `finalize`: 全部 phase 完成后聚合最终执行仪表盘并给出人类下一步建议

### `plan/state.yaml`

这是执行账本，记录：

- 哪些 phase 已完成
- 完成顺序
- 每次完成的摘要、下一步焦点和时间戳

后续 phase 是否可执行，最终以它为准。

### `plan/handoff.md`

这是压缩恢复锚点，记录：

- 当前状态
- 最近完成摘要
- 下一 phase
- 下一步要读的上下文
- 压缩后的恢复顺序

它的作用是避免 AI 在压缩后重新加载全部 phase 文档。

### Agent 强制层（`.github/copilot-instructions.md` / `CLAUDE.md` / `AGENTS.md`）

以上三份文件内容保持一致，分别被 GitHub Copilot、Claude Code、Codex（及兼容的通用 agent）在会话开头自动注入，作为仓库级 AI 工作流约束，保证 AI 在 phase 相关任务里：

- 必须先读 manifest
- 必须走 `planctl`
- 不能跳过依赖检查
- 不能一次性加载全部 phase 文档
- 压缩或新会话后要从 handoff 恢复

## 如何确保顺序执行

顺序不是靠人工记忆，而是靠以下机制共同保证：

1. `plan/manifest.yaml` 明确写出 phase 的顺序和 `depends_on`
2. `planctl advance` 只围绕按 manifest 顺序找到的第一个未完成 phase 输出下一动作
3. `planctl resolve --strict`、`planctl next --strict` 和 `planctl advance --strict` 会校验依赖是否满足
4. 未完成前置 phase 时，后续 phase 会被标记为 blocked，不允许继续执行

因此，这套流程天然防止跳 phase 和乱序执行。

## 如何确保完整执行

完整执行不是“做了一部分就继续”，而是必须满足以下条件：

1. 当前 phase 执行前，必须读取完整 `required_context`
2. 必须同时携带：
   - `plan/common.md`
   - 当前 phase 文档
   - 当前 execution 文档
3. 当前正式合同必须保留四个稳定 marker：`PHASE_CONTRACT:FACT_AUDIT`、`PHASE_CONTRACT:PRODUCTION_WIRING`、`PHASE_CONTRACT:RUNTIME_EVIDENCE`、`PHASE_CONTRACT:FAILURE_MODES`
4. `PHASE_CONTRACT:PRODUCTION_WIRING` 下必须有 `Component Adoption Table`，覆盖所有新增类 / target / config / key / log / metric；没有生产接线时必须写 `N/A: <原因>`
5. 实施时必须服从 execution 文档中的允许改动、禁止项和交付检查
6. 在 `complete` 前，当前 phase 至少要通过依赖检查、`lint-contracts`、manifest 中声明的 required checks，以及 `allowed_paths` 路径门
7. 未写入 `plan/state.yaml` 的 phase，不视为完成

因此，进入下一 phase 的前提不是“感觉差不多了”，而是“状态文件已经明确记录完成”。

## 如何开始执行全部计划

如果目标是连续执行全部 plan，标准起点如下：

1. 读取 `plan/manifest.yaml`
2. 读取 `plan/handoff.md`
3. 运行 `ruby scripts/planctl advance --strict`
4. 当输出 `ACTION: implement` 时，按输出结果读取当前 phase 的 `required_context`
5. 开始实施当前 phase

开始时不要一次性加载全部 `plan/phases/` 和 `plan/execution/`，只加载当前 phase 所需上下文。

## 连续执行的标准循环

在长流程里，每个 phase 都遵循同一个循环：

1. 运行 `advance --strict`
2. 读取当前 phase 的 `required_context`
3. 按当前 execution 文档实施
4. phase 真完成后运行 `complete --continue`
5. 按 `advance` 返回的下一 `ACTION` 继续
6. 若返回 `ACTION: promote_placeholder`，先把该 phase 的 `phases/*.md` 和 `execution/*.md` 升级成正式合同，再重跑 `advance --strict`

对应命令如下：

```bash
ruby scripts/planctl advance --strict
ruby scripts/planctl lint-contracts --phase <phase-id>
ruby scripts/planctl complete <phase-id> --summary "<summary>" --next-focus "<next-focus>" --continue
```

这样每完成一个 phase，状态、摘要和恢复锚点都会同步更新；后续 phase 若尚未正式规划，`advance` 会返回 `ACTION: promote_placeholder`，迫使 AI 先补正式合同，而不是误把 phase 边界当成用户确认点。

## 如何结束单个 Phase

单个 phase 的结束条件是：

- 当前 phase 的 execution 文档中交付检查已经满足
- 当前 phase 的阶段目标已经达到
- 当前 phase 没有违反禁止项和裁决规则
- `ruby scripts/planctl lint-contracts --phase <phase-id>` 返回 0
- manifest 中该 phase 的 required checks 全部成功，并且 Runtime Evidence 足以证明真实链路生效

然后运行：

```bash
ruby scripts/planctl complete <phase-id> --summary "<summary>" --next-focus "<next-focus>" --continue
```

此时会发生四件事：

- `complete` 先运行依赖检查 → `lint-contracts` → required checks → `allowed_paths` gate；任一 required gate 失败都会 exit 2，且不会写 `state.yaml` / `handoff.md` / git 里程碑
- 所有 required gate 通过后，`plan/state.yaml` 记录该 phase 已完成
- completion log 记录摘要、下一步焦点，以及本次执行过的 checks 摘要（含 `id / command / exit_code / duration / status / output_tail`）
- `--continue` 会立即运行 `advance`，输出后续内部动作

紧接着 `complete` 还会自动完成**里程碑提交与推送**（见下一节）：AI 需要先根据当前 phase 产生的未跟踪文件，推理哪些属于构建 / 编译 / 运行 / 测试中间产物，并在需要时把精确规则写入根目录 `.gitignore`；随后再执行 `git add -A` → `git commit -F -` → `git push`，把本 phase 的所有改动（代码、文档、`state.yaml`、`handoff.md`，以及必要时新更新的 `.gitignore`）固化为一次可回溯、可回退的里程碑记录；若仓库没有 remote，则保留为本地里程碑并继续流程。在此之前**不要**自行 `git commit` / `git push`。

## 如何进入下一 Phase

`complete --continue` 成功后，下一步不是停下来问用户“是否继续”，而是立刻做这组内部动作：

1. 自动运行 `ruby scripts/planctl advance --strict`
2. 如果输出 `ACTION: implement`，读取 required_context 并直接开始实施
3. 如果输出 `ACTION: promote_placeholder`，先把两份文件升级成正式合同，再重跑 `advance --strict`
4. 如果输出 `ACTION: stop`，报告真实 blocker；如果输出 `ACTION: finalize`，进入整体收尾

这一步属于 Golden Loop 内部步骤，不是用户确认点。

## 里程碑提交与推送（`complete` 自动）

每次 `complete` 成功写回 `state.yaml` / `handoff.md` 之后，`scripts/planctl` 会按下列顺序自动执行 git 收尾，用来给每个 phase 留下一次地道英文、可审计、可回退的里程碑记录：

1. `git add -A` 之前先做 `.gitignore` 卫生：AI 结合未跟踪文件、命令输出、路径语义和可再生性，判断哪些是构建 / 编译 / 运行 / 测试中间产物，并把精确规则写入根目录 `.gitignore`。
2. 然后执行 `git add -A`：把 phase 产出与 plan 写回一起入栈。
3. 若暂存区为空 → 打印 `Nothing to commit`，跳过提交（例如重复 `complete`）。
4. 否则以如下格式 `git commit -F -`（stdin）：
   - Subject：`chore(plan): complete <phase-id> — <phase title>`（自动截断到 100 字符内）
   - Body：用户传入的 `--summary`（缺省时为通用提示语）
   - Trailers：`Phase-Id: <id>`、`Next-Focus: <...>`、`Automated-By: scripts/planctl complete`
   - 保留 pre-commit / commit-msg hook，不使用 `--no-verify`。
5. `git push`：若仓库已配置 remote，则优先推送到当前分支的 upstream；若无 upstream，则回退到 `git push -u origin HEAD`（无 `origin` 时使用第一个可用 remote）。若仓库没有任何 remote，则脚本只打印 warning、跳过 push，并继续后续流程。
6. 失败语义：commit 或 push 失败只打印 warning，**不会**回滚 `state.yaml`；无 remote 也属于 warning-only 的降级场景，而不是阻塞条件。后续由操作者手动处置（鉴权、补 remote、保护分支、hook 失败等）。

环境变量（仅用于特殊场景，默认不要设置）：

- `PHASE_CONTRACT_SKIP_PUSH=1`：只做本地 commit，不推送。
- `PHASE_CONTRACT_SKIP_COMMIT=1`：跳过 commit 与 push。
- `PHASE_CONTRACT_ALLOW_NON_GIT=1`：非 git 工作区模式，整段 git 收尾跳过。

## 如何回退某个已完成的 Phase

当某个 phase 做坏需要回滚时，运行：

```bash
ruby scripts/planctl revert <phase-id> [--mode revert|reset] [--summary "<reason>"]
```

- `--mode revert`（默认，推荐）：`git revert` 里程碑 commit，保留历史，可安全推送。
- `--mode reset`：`git reset --hard` 到里程碑 commit 之前，**重写历史**，脚本自动跳过 push，由操作者自行 `git push --force-with-lease` 处置。仅适用于无协作者的私有分支。

无论哪种模式，脚本都会：

1. 通过 `git log --grep "^Phase-Id: <id>$"` 找到对应里程碑 commit；找不到则仅回滚 `state.yaml`，并提醒你手动对账。
2. 拒绝回退存在**已完成下游依赖**的 phase（必须按 `depends_on` 逆序回退）。
3. 从 `completed_phases` 中剔除该 phase，在 `completion_log` 追加 `reverted_at` 条目。
4. 重写 `plan/handoff.md`，以 `chore(plan): revert <phase-id>` 提交 ledger 并推送（`revert` 模式）。

回退后再跑一次 `planctl advance --strict`，该 phase 会重新进入队列。

## 如何结束全部计划

当全部 phase 都完成后，先运行：

```bash
ruby scripts/planctl advance --strict
```

如果没有剩余 phase，脚本会返回 `ACTION: finalize`，并提示进入整体收尾。此时：

- `plan/state.yaml` 中应包含全部 phase
- `plan/handoff.md` 中不再有下一 phase
- `planctl status` 会显示没有 remaining queue

但**到此还没有真正结束**。Phase-Contract 把“全部 phase 完成”和“项目可交付收尾”刻意分成两步：前者由 `complete --continue` / `advance` 表示，后者必须由 AI 主动跑一次 `finalize`，并把仪表盘和决策权交回给人类。

```bash
ruby scripts/planctl finalize
```

`finalize` 只在 `state.yaml` 已包含全部 manifest phase，且每个 phase 都在 `completion_log` 中有 `completed_at` 与全部 required checks 成功证据时才会运行（否则 exit 2，且不输出仪表盘）。首次成功执行时，它会先按以下顺序写入最终 ledger，再输出仪表盘：

- 写入 `plan/state.yaml.finalized_at`（UTC ISO8601）
- 同步刷新 `plan/state.yaml.updated_at`
- 刷新 `plan/handoff.md`
- 执行最终 git 收尾：`git add -A` → `git commit -F -` → `git push`
- 最后打印最终执行仪表盘

若 commit 或 push 失败，只打印 warning；**不会**回滚 `finalized_at`、`state.yaml` 或 `handoff.md`。若仓库没有 upstream，则回退到 `git push -u <remote> HEAD`；若没有任何 remote，则保留本地 finalization commit 并继续。

一旦 `finalized_at` 已存在，后续重复 `finalize` 必须保持只读：不再重写 ledger、不再创建第二个 finalization commit、不再重复 push，只重新生成仪表盘。

最终执行仪表盘会一次性聚合：

- 项目总览（phase 总数、完成数、首/末完成时间、`Finalized at`、累计 elapsed）
- Phase 台账（每个 phase 的标题、完成时间、summary、next_focus、对应里程碑 commit SHA）
- 仓库状态（当前分支、upstream、ahead/behind、工作树是否干净、未推送 commit、最近 commit）
- Health 检查（manifest 引用、state/handoff 一致性、三份 agent 指令 SHA256 对齐）
- 推荐的人类下一步（基于上面四块自动推导，例如有未推送 commit 就提示 `git push`，没有 remote 就提示先补 remote）

AI 拿到 finalize 输出后，必须做一次**深入审视**：核对仪表盘与仓库实情是否一致、把通用建议翻译成本项目可执行的命令与责任人、识别 finalize 没显式列出但客观存在的风险（例如某个 phase 的 summary 与 diff 不符），并以**最终执行仪表盘**的形式向人类汇报。汇报最后必须显式把以下决策点交还人类：是否上线/发版、是否打 release tag、是否归档 `plan/`、是否安排长期维护、是否需要外部审阅。

即便 `finalize` 首次成功执行会自动 commit/push finalization ledger，在人类没有显式指示之前，AI 仍不得自行 `git tag`、推 tag、删除/移动 `plan/`、开启下一轮规划或继续修改 `state.yaml`。这才算整个计划真正结束。

## 如何在压缩或新会话后继续执行

AI 会遇到上下文窗口限制，所以恢复流程不能依赖聊天记忆，必须依赖仓库内持久文件。

标准恢复顺序如下：

1. 读取 `plan/manifest.yaml`
2. 读取 `plan/handoff.md`
3. 运行 `ruby scripts/planctl advance --strict`
4. 若返回 `ACTION: promote_placeholder`，先把该 phase 的两份合同升级成正式合同，再重跑同一条 strict 命令
5. 若返回 `ACTION: implement`，按输出结果读取当前 phase 的 `required_context`
6. 继续执行

恢复时不要重新全量加载全部 phase 文档；只读取：

- `plan/manifest.yaml`
- `plan/handoff.md`
- 当前 `advance` 返回的 `required_context`

## 压缩控制原则

为了避免上下文窗口被历史内容占满，执行时必须遵守以下原则：

- 永远不要一次性加载全部 phase 文档
- 长流程时只保留：`plan/common.md` + 当前 phase plan + 当前 phase execution + `plan/handoff.md`
- 每完成一个 phase 后，立即再次解析下一 phase；若 current phase 仍是占位合同，先补正式合同
- 压缩后优先从 handoff 恢复，而不是重放整段历史聊天

## 推荐命令清单

查看当前整体状态：

```bash
ruby scripts/planctl status --format json
```

解析指定 phase：

```bash
ruby scripts/planctl resolve <phase-id> --format prompt --strict
```

连续执行下一个 phase：

```bash
ruby scripts/planctl advance --strict
```

标记当前 phase 完成：

```bash
ruby scripts/planctl complete <phase-id> --summary "<summary>" --next-focus "<next-focus>" --continue
```

手动重放交接文件（仅补救）：

```bash
ruby scripts/planctl handoff --write
```

整体收尾仪表盘（所有 phase 完成后唯一的最后一步）：

```bash
ruby scripts/planctl finalize
```

## 一句话总结

这套流程通过 manifest 定义顺序，通过 planctl 推进状态，通过 state 记录完成事实，通过 handoff 处理压缩恢复，并在 phase 边界把“先补正式合同再实现”写成脚本可阻断的内部动作；最后由 `finalize` 把全部状态、里程碑和健康检查汇聚成最终执行仪表盘，再把发版、归档、维护等决策权显式交还人类，从而保证全部任务能按既定顺序、完整执行、稳定续跑，并以一次审计可见的收尾真正结束。
