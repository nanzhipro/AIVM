# AIVM Phase 执行规约

> **适用范围**：本文件同时作为以下三种 AI 编码工具的会话级强制约束，内容完全一致，必须保持同步：
>
> - GitHub Copilot → `.github/copilot-instructions.md`
> - Claude Code → `CLAUDE.md`（仓库根目录）
> - Codex / 通用 Agent → `AGENTS.md`（仓库根目录）
>
> 修改其中任一份，必须同步刷新另外两份。推荐维护一份真源并在 CI/pre-commit 做一致性检查。

当用户请求涉及 phase、计划执行、实施步骤、持续推进、恢复执行，或要求你遵循本仓库的规划体系开展工作时，本规约生效。生效后，必须把 `plan/manifest.yaml` 视为执行契约，而不是参考性文档。

## 一、规约定位

- 本文件用于约束 AI 在 AIVM 仓库中的 phase 执行行为，对 Copilot / Claude Code / Codex 三方等效生效。
- `plan/workflow.md` 负责解释流程；本文件负责规定行为。
- `scripts/planctl`、`plan/state.yaml`、`plan/handoff.md` 共同构成当前工程的实际执行机制；本文件必须与它们保持一致。

## 二、解释优先级

当不同文档提供的信息存在交叉时，按以下顺序解释和执行：

1. 当前应执行哪个 phase，以 `plan/manifest.yaml`、`plan/state.yaml` 和 `scripts/planctl` 的结果为准。
2. 全局长期约束，以 `plan/common.md` 为准。
3. 当前 phase 的实施边界、交付合同和完成检查，以对应的 `plan/execution/*.md` 为准。
4. 当前 phase 的阶段定位、目标与范围，以对应的 `plan/phases/*.md` 为准。
5. 压缩恢复和续跑锚点，以 `plan/handoff.md` 为准。
6. `plan/workflow.md` 仅用于说明，不得覆盖上述规则。

## 三、开始实施前的强制步骤

0. 先确认当前仓库是 git 工作区：在项目根执行 `git rev-parse --is-inside-work-tree`，必须返回 `true`。若返回非零或 `false`，停止实施并把“非 git 工作区”作为 blocker 报告给用户（除非 `PHASE_CONTRACT_ALLOW_NON_GIT=1` 已显式设置，且 `plan/common.md` 含对应风险段）。Phase-Contract 的白名单比对、回滚、完成检查都依赖 git，缺 git 时任何 `complete` 都不可信。
1. 先读取 `plan/manifest.yaml`，确认 phase 顺序、依赖关系、required_context、连续执行规则和压缩恢复规则。
2. 识别当前任务属于哪一种模式：
   - 连续推进全部计划或继续推进剩余 phase。
   - 明确指定某个已知 phase。
   - 讨论规划体系本身，而不是实施某个业务 phase。
3. 如果是连续推进全部计划、持续推进剩余 phase，或用户表达出“一口气做完/继续往下做”的意图，必须先读取 `plan/handoff.md`，再运行 `ruby scripts/planctl advance --strict`。
4. 如果用户明确指定某个已知 phase，必须运行 `ruby scripts/planctl resolve <phase-id> --format prompt --strict`。
5. 如果当前 phase 已是正式合同，开始实施前必须确认其 `plan/phases/*.md` 与 `plan/execution/*.md` 都包含四个稳定 marker：`PHASE_CONTRACT:FACT_AUDIT`、`PHASE_CONTRACT:PRODUCTION_WIRING`、`PHASE_CONTRACT:RUNTIME_EVIDENCE`、`PHASE_CONTRACT:FAILURE_MODES`；并确认 `PHASE_CONTRACT:PRODUCTION_WIRING` 下存在 `Component Adoption Table` 或显式的 `N/A: <原因>`。
6. 如果用户讨论的是规划体系本身，而不是某个业务 phase 的实施，也必须先从 `plan/manifest.yaml` 出发，再确保表述与 `plan/workflow.md` 和 `scripts/planctl` 的实际行为一致。

## 四、当前 Phase 的确定规则

1. 当前应执行哪个 phase，不得靠主观判断决定。
2. 连续执行时，`planctl advance` 返回的 `ACTION` 和 phase，是唯一合法的下一步。`ACTION: implement` 才表示可以实施；`ACTION: promote_placeholder` 表示先升级占位合同；`ACTION: stop` 表示真实 blocker；`ACTION: finalize` 表示进入最终收尾。
3. 指定 phase 时，`planctl resolve` 返回的结果，是唯一合法的当前 phase。
4. 不得跳过 `depends_on` 检查，也不得手工判定“前置 phase 基本完成”。
5. `advance --strict` 只有在真实 blocker 下才应阻断；占位合同不是 blocker，而是 `ACTION: promote_placeholder`。
6. 若 `advance` 返回 `ACTION: promote_placeholder`，下一动作必须是先把两份合同升级成正式合同，再重跑同一条 strict 命令。

## 五、上下文装载规约

1. 必须严格按 resolver 返回的 `required_context` 顺序读取上下文，不得调换顺序，也不得跳读。
2. `plan/common.md` 是所有 phase 的强制上下文，不得省略。
3. 当当前 phase 存在 execution 文档时，不得只读 `plan/phases/*.md` 就开始实施。
4. resolver 已经给出当前 `required_context` 时，不要擅自扩读其他 phase 的 plan 或 execution 文档，以免把未来阶段内容混入当前实施边界。
5. 长流程执行时，不得一次性把全部 `plan/phases/` 和 `plan/execution/` 文档装入同一个上下文窗口。
6. 长流程中允许保留的核心上下文，默认仅限于：
   - `plan/common.md`
   - 当前 phase 的 `plan/phases/*.md`
   - 当前 phase 的 `plan/execution/*.md`
   - `plan/handoff.md`

## 六、实施边界规约

1. 当前 phase 对应的 `plan/execution/*.md` 是本次实施的范围边界、交付合同和完成检查表。
2. 如果 execution 文档与泛化理解冲突，以 execution 文档为准。
3. 业务 phase 的实施过程中，默认不要修改下列流程基础设施文件：
   - `plan/manifest.yaml`
   - `plan/workflow.md`
   - `.github/copilot-instructions.md` / `CLAUDE.md` / `AGENTS.md`（三份同步维护）
   - `scripts/planctl`
   - `plan/state.yaml`
   - `plan/handoff.md`
4. 只有当任务本身就是修改规划体系或流程基础设施时，才允许修改上述文件。

## 七、中止条件

出现以下任一情况时，必须停止实施并先报告 blocker，不得继续编辑文件：

1. resolver 报告依赖未满足。
2. resolver 报告上下文文件缺失。
3. strict 模式因依赖缺失、上下文缺失或其他外部条件未满足而失败。若 strict 只因当前 phase 仍是占位合同而失败，不算 blocker，按第八节先补正式合同。
3a. 当前项目根不是 git 工作区，且未显式设置 `PHASE_CONTRACT_ALLOW_NON_GIT=1`。此时 `scripts/planctl` 的 `advance` / `next` / `resolve` / `complete` / `handoff` 会以 exit code 3 拒绝运行，必须先让用户补齐 `git init` 基线，不得绕过。
4. 当前工作树中存在与当前 phase 契约直接冲突、且无法在不破坏用户已有修改的前提下兼容的变更。
5. 用户请求与当前 manifest 定义的 phase 顺序、边界或完成规则直接冲突，而规划体系本身尚未被更新。

## 八、完成与推进规约

1. 只有在当前 phase 真实完成后，才能运行 `ruby scripts/planctl complete <phase-id> --summary "<summary>" --next-focus "<next-focus>" --continue` 写回执行状态并接续下一内部动作。`--summary` 和 `--next-focus` 都必须非空，空值会被拒绝（exit 2）。`complete` 会在写回前自动执行：依赖检查 → `lint-contracts` → required checks → `allowed_paths` gate。
2. “真实完成”至少意味着：
   - 当前 phase 的 execution 文档中的交付检查已经满足。
   - 当前 phase 的阶段目标已经达到。
   - 当前 phase 没有违反禁止项和裁决规则。
   - `ruby scripts/planctl lint-contracts --phase <phase-id>` 返回 0。
   - manifest 为当前 phase 声明的 required checks 全部成功，且 Runtime Evidence 足以证明真实链路生效。
3. 未写入 `plan/state.yaml` 的 phase，不视为完成。
4. `complete` 会在一次调用内原子地刷新 `plan/state.yaml` 与 `plan/handoff.md`（tmp+rename），正常情况下**不需要**再额外跑 `ruby scripts/planctl handoff --write`；后者仅作为手工补救手段，当发现 handoff 与 state 失步或手动编辑过其中之一时再用。
5. 不得在未运行 `complete` 的情况下，直接开始后续 phase。
6. `complete` 时默认使用 `--continue`，即运行 `ruby scripts/planctl complete <phase-id> --summary "<summary>" --next-focus "<next-focus>" --continue`。该命令会在完成写回与 git 里程碑后立即执行 `advance` 并输出下一内部动作。若 manifest 中 `execution_rule.continuation.mode` 为 `autonomous`，即使遗漏 `--continue`，`complete` 也会自动接上 `advance`。
7. 任一 required gate 失败或超时，`complete` 必须以 exit 2 退出，且不写 `state.yaml` / `handoff.md` / git 里程碑，也不得把 phase 口头宣告为已完成。
8. optional checks 失败只会 warning，但必须被写进 `completion_log[*].checks`，并在后续 handoff / finalize / 人类汇报中可见。
9. `complete` 会在写回 `state.yaml` / `handoff.md` 之后执行 `git add -A` → `git commit -F -`（地道英文 commit message：`chore(plan): complete <phase-id> — <title>`，带 `Phase-Id` / `Next-Focus` trailers） → `git push`（无 upstream 时回退到 `git push -u origin HEAD`；若仓库没有任何 remote，则只保留本地 commit 并继续，不得因此中止任务）。但在调用 `complete` 之前，AI 必须先根据当前 phase 产生的未跟踪文件自行推理哪些属于构建 / 编译 / 运行 / 测试中间产物，并在需要时更新根目录 `.gitignore`；判断标准以“是否可从源码或命令重新生成、是否属于真实交付物、是否被项目约定要求入库”为准，不能把 fixture、快照基线、lockfile、必须提交的生成代码/文档误判为垃圾。在当前 phase 实施期间**不得**自行 `git commit` 或 `git push`，以免产生半成品提交或提交信息风格漂移；把里程碑记录权统一交给 `complete`。
10. 允许设置 `PHASE_CONTRACT_SKIP_PUSH=1`（仅本地 commit）或 `PHASE_CONTRACT_SKIP_COMMIT=1`（跳过整条 git 收尾）仅用于离线 / 排障等特殊场景，默认不要使用；若仓库天然没有 remote，也不要把它当成阻塞条件，应继续执行并在对用户的汇报里明确说明当前只落本地里程碑。若 AI 基于上述推理更新了 `.gitignore`，应将其视为正常基础设施变更，而不是越界编辑。
11. 若 `complete` 的 commit 或 push 失败，`state.yaml` 仍会保持已完成状态（不回滚）；应当向用户报告 warning 原文并提示手动处置（鉴权、保护分支、pre-commit hook 等），而不是尝试手动 `git reset` 或伪造提交。
12. 回退某个已完成 phase 时必须走 `ruby scripts/planctl revert <phase-id>`，不得手工 `git revert` / `git reset` 也不得手工改 `state.yaml`；script 会负责定位里程碑 commit、保护下游依赖、重写 state/handoff 并提交 ledger。

## 九、压缩恢复规约

1. 如果发生上下文压缩或进入新会话，恢复顺序固定为：
   - 先读 `plan/manifest.yaml`
   - 再读 `plan/handoff.md`
   - 然后运行 `ruby scripts/planctl advance --strict`
2. 恢复后只进入当前应执行的 phase，不得自行回到更早或跳到更晚的 phase。
3. 恢复后只读取 `advance` 返回的当前 `required_context`，不要重新全量装载全部 phase 文档。

## 十、禁止行为

- 不得在 resolver 或 advance 完成之前，开始任何与 phase 实施相关的代码或文档编辑。
- 不得绕过 `planctl` 手工选择当前 phase。
- 不得跳过 `depends_on` 检查。
- 不得把未来 phase 的目标、交付或代码实现提前混入当前 phase。
- 不得把 phase 边界或占位合同升级误判成需要用户确认的停顿点；连续执行时，这属于 Golden Loop 内部步骤。只有 `ACTION: stop`、破坏性操作、必须由人类决策的发布/归档/法务/安全事项，才是停顿点。
- 不得一次性加载全部 phase 文档，导致当前上下文被未来阶段信息污染。
- 不得手工编辑 `plan/state.yaml` 和 `plan/handoff.md` 来伪造进度或恢复状态，除非任务本身就是维护流程基础设施。
- 不得在未满足当前 phase 完成条件时宣告完成。
- 不得在当前 phase 实施期间自行 `git commit` / `git push` / `git tag`；提交权统一由 `scripts/planctl complete` 自动行使。
- 不得在所有 phase 完成后跳过 `ruby scripts/planctl finalize`，直接对人类宣告“项目结束”或自行执行收尾动作（打 tag、归档 plan、发布等）。最终决策必须由人类基于 finalize 输出做出。

## 十一、流程基础设施维护例外

当任务本身就是修改规划体系、执行流程或其基础设施时，可以修改：

- `plan/manifest.yaml`
- `plan/workflow.md`
- `.github/copilot-instructions.md` / `CLAUDE.md` / `AGENTS.md`（三份同步维护）
- `scripts/planctl`
- `plan/state.yaml`
- `plan/handoff.md`

但此时必须同时满足以下要求：

1. 修改后的规则、文档和脚本行为保持一致。
2. 如涉及 `scripts/planctl`，必须验证命令行为与文档描述一致。
3. 如涉及文档入口或恢复规则，必须同步更新相关入口文档。
4. 不得只改说明文字而不改实际流程，也不得只改脚本而不改说明文字。

## 十二、整体收尾规约（Finalization）

当且仅当 `manifest.yaml` 中所有 phase 都已写入 `plan/state.yaml` 的 `completed_phases`、每个 phase 都在 `completion_log` 中有 `completed_at` 与全部 required checks 成功证据、且 `ruby scripts/planctl advance --strict`（或最近一次 `complete --continue`）输出 `ACTION: finalize` 时，进入整体收尾流程。

1. 必须立刻运行 `ruby scripts/planctl finalize`（默认 `text` 格式即可，需要结构化数据时再加 `--format json`）。
2. `finalize` 在所有 phase 真正完成并成功前会以 exit 2 拒绝执行；缺失 `completion_log` 成功证据、required check 失败、unknown/duplicate `completed_phases` 都会阻断仪表盘输出。不得用 `PHASE_CONTRACT_*` 环境变量或手工修改 `state.yaml` 的方式绕过。
3. 首次成功的 `finalize` 必须先写入最终 ledger，再输出仪表盘：
   - 写 `plan/state.yaml.finalized_at`，并同步刷新 `updated_at`
   - 刷新 `plan/handoff.md`
   - 运行 `git add -A` → `git commit -F -` → `git push`
   - 若 commit 或 push 失败，只打印 warning，**不得**回滚已经写入的 ledger
4. 一旦 `finalized_at` 已存在，重复 `finalize` 必须保持只读：
   - 不得重写 ledger
   - 不得再次 commit
   - 不得再次 push
   - 只允许重新生成最终执行仪表盘
5. 拿到 `finalize` 输出后，必须做一次**深入审视**，不要只复述：
   - 通读 `manifest.yaml`、`plan/state.yaml`、`plan/handoff.md` 和最近 N 个里程碑 commit，确认 finalize 仪表盘里的 phase ledger、git 状态、health 检查与实际仓库吻合。
   - 找出 finalize 没明说但客观存在的风险：例如某个 phase 的 summary 与其实际 diff 不一致、某条 recommended next step 在本项目语境下不适用、health notes 提示的轻警告是否需要升级为 issue。
   - 把 finalize 的“Recommended human next steps” 翻译成针对本项目的具体动作（带命令、目标分支、责任人/审阅者、时限），而不是原样转述通用建议。
6. 必须以**最终执行仪表盘**的形式向人类汇报，至少包含：
   - 项目总览：phase 总数、完成数、首/末完成时间、总 elapsed。
   - Finalized at：finalization ledger 的 UTC 时间戳。
   - Phase 台账：每个 phase 的 id、标题、完成时间、summary、对应里程碑 commit。
   - 仓库状态：当前分支、upstream、ahead/behind、working tree 是否干净、未推送 commit、最近 commit。
   - Health 检查：finalize 的 issues / notes 是否全绿，必须人工处置的项明确列出。
   - 风险与遗留：本次 plan 留下的已知 TODO、未覆盖范围、需要人工复核的灰色地带。
   - 推荐人类下一步：分“立即”、“短期”、“可选”三档，每条带可执行命令或决策点。
7. 在仪表盘最后必须明确把决策权交还人类：
   - 是否上线 / 发版 / 对外公布；
   - 是否对成果打 release tag；
   - 是否把 `plan/` 归档（`git mv plan plan-archive-<date>`）后开启下一项规划，或保留 `plan/` 作为长期档案；
   - 是否安排长期维护、轮值或回归测试；
   - 是否需要安全 / 合规 / 法务审阅。
8. 在人类未明确指示之前，**不得**自行执行任何收尾动作：
   - 不得 `git tag` / `git push --tags` / 创建 release；
   - 不得删除、重命名、移动 `plan/` 或 `scripts/planctl`；
   - 不得进入下一项规划（不要重跑本 Skill 的脚手架），除非人类显式要求；
   - 不得在 finalize 之后再运行 `complete`、`revert` 或修改 `state.yaml`；如发现需要回退，先把回退请求作为 blocker 报告给人类，由人类决定是否走 `revert`。
9. 若 finalize 的 health 检查报告 issue（exit 0 但有 issue 项时不会非零退出，需自行解读），按 §七 把它当作 blocker 处理：先汇报，由人类决定是先修问题再宣告完成、还是接受现状收尾。
10. finalize 是会话级别的“最后一公里”，每一项 plan 仅运行一次（除非 plan 被显式延展、新 phase 被加入 manifest 后又跑完一轮）。重复 `finalize` 不会产生副作用，但应避免把它当成 status 替代品频繁调用。
