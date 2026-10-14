# GAW Auxiliary History 开发指导

**类型**: 开发指导与实现规划

**状态**: 核心设计已确定, 待实现

**基线**: Git Agent Workflow v0.6.0, main `801fe3b5fd80ffa34cea714816e656d15aa251e1`

**主要关联**: Issue #5, Issue #9

## 0. 背景与目标

GAW 当前以一条 first-parent 历史维护项目的权威记忆状态. 在跨 session、跨 agent 的历史整合中, 不同来源可能具有各自独立且值得保留的知识演化过程.

直接将这些过程依次重建到正式 GAW branch, 容易将来源内部的演化顺序与项目级知识整合顺序混合在一起.

本次引入 Auxiliary GAW, 简称 Aux-GAW, 为来源材料提供独立、临时的 GAW 历史.

核心目标:

1. 允许 agent 为不同来源分别重建有意义的知识状态及其 first-parent 演化.
2. 允许正式 GAW 通过 additional-parent 关系多次引用这些历史的不同 checkpoint.
3. 保持正式 GAW 为唯一的项目级当前记忆权威.
4. 在完成整合后通过 `branch -d` 安全删除 Auxiliary 的活动 branch, 同时通过正式 GAW 的 Git ancestry 保留必要历史; 也允许通过 `branch -D` 明确放弃该历史.
5. 尽可能复用现有 config、workspace、commit、check 和 hook 机制.

Aux-GAW 不是正式 GAW 的子分支, 也不是 GAW 历史 split/fusion 的实现.

本次不重新设计 GAW 的历史模型.

## 1. 核心结构

### 1.1 标识与分支

每条 Auxiliary history 使用自动生成的 UUIDv4.

采用标准小写、带连字符的 UUID 文本表示.

分支命名:

`refs/heads/_gaw_aux_<uuid>`

要求:

- UUID 仅用于结构性区分和避免路径碰撞.
- UUID 不表达来源 session、内容哈希、创建时间或 provenance.
- 初始化时使用安全随机源生成 UUIDv4.
- 分支创建必须具备原子性的不存在检查.
- 如果名称冲突, 重新生成 UUID.
- 不创建 Auxiliary 专用 ref namespace、selector 或持久注册表.
- 不要求为活动 branch 已删除的 UUID 保留注册记录.

Branch 命名约定由 CLI 和 protection hook 共同识别.

### 1.2 Git tree 布局

Auxiliary commit 的完整 Git tree 必须仅包含一个顶层目录:

`<uuid>/`

其内部结构示意:

- `<uuid>/.gaw/config`
- `<uuid>/memory/`
- `<uuid>/archive/`
- `<uuid>/skills/`

除 `<uuid>/` 外, 不允许其他 tracked entries.

其中 memory、archive、skills 只是示意. 实际 workspace 由配置声明, 不强制创建这些目录.

`<uuid>/.gaw/config` 必须存在, 并符合现有 GAW 配置协议.

Auxiliary 的逻辑 workspace root 为 `<uuid>/`, 但其 Git commit tree root 仍然是普通 Git tree root.

必须严格区分这两个根目录.

### 1.3 配置继承

`aux init` 从 `refs/gaw/HEAD` 当前选中的正式 GAW branch 的已提交 HEAD 读取 `.gaw/config`.

将其原样复制到新建 Auxiliary root commit 的 `<uuid>/.gaw/config`.

这是初始化时的一次配置快照, 不是动态继承.

要求:

- 不从工作树或 index 复制未提交配置.
- 不自动复制正式 GAW workspace 内容.
- 不将正式 GAW checkpoint 设为 Auxiliary root commit 的 parent.
- 不自动生成额外的 memory、archive 或 skills 内容.
- 继承 v0 或 v1 配置时均使用现有解析及验证规则.
- Auxiliary 后续可以按照正常 GAW commit 规则修改自身配置.

现有 workspace declaration 路径统一相对于 `<uuid>/` 解释.

例如, 配置中的 `(:directory "memory")` 对应 `<uuid>/memory/`.

保持 `.gaw/` 协议路径与普通 workspace 的隔离规则.

### 1.4 历史与提交语义

Auxiliary 使用独立 root commit, 后续 checkpoint 通过 first-parent 形成自身知识演化历史.

完全继承现有 GAW commit 语义, 包括:

- 当前 index 表示待提交的完整 workspace snapshot.
- First parent 为当前 Auxiliary checkpoint.
- Additional parents 记录有证据支持的外部历史关联.
- Additional-parent trees 不合并进入 Auxiliary tree.
- 继续执行已有的 workspace、parent conflict、operation state 和提交参数检查.
- `.gaw/` 协议路径变更不得与普通 workspace 变更混合提交.
- 复用现有提交身份、时间处理及受控 ref 更新原则.
- 不改变 `--allow-empty` 等现有选项的含义.

协议路径变更边界必须相对于 Auxiliary 的逻辑 root 计算.

不得因为 Auxiliary 的特殊目录布局而放宽既有 GAW 提交约束.

## 2. CLI 设计

新增三个专用命令:

| CLI | 职责 |
|---|---|
| `git gaw aux init [--worktree-path <path>]` | 创建 Auxiliary root 和 branch, 随后调用 deploy |
| `git gaw aux deploy --branch <name> [--worktree-path <path>]` | 部署已有 Auxiliary branch |
| `git gaw aux check [--branch <name>]` | 分别报告 Auxiliary 结构合法性和安全删除准备状态 |

同时扩展现有命令:

| CLI | 调整 |
|---|---|
| `git gaw commit` | 自动支持当前 Auxiliary worktree |
| `git gaw check` | 自动支持当前 Auxiliary worktree |
| `git gaw check --branch <name>` | 新增指定 branch 的 committed-state 检查 |
| `git gaw status` | 展示正式 GAW 与 Auxiliary branches |
| `git gaw undeploy` | 扩展状态报告和引用保护退出提示 |
| `git gaw branch -d <name>` | 保留正式 GAW 的现有安全删除语义; Auxiliary 使用所选正式 GAW 的整合可达性检查 |
| `git gaw branch -D <name>` | 保留正式 GAW 的现有强制删除语义; Auxiliary 表示明确放弃历史, 跳过整合可达性检查 |
| `git gaw branch -m <name>` | 仍只重命名当前选中的正式 GAW branch, 拒绝进入 Auxiliary 保留命名范围 |

`git gaw show` 原有用法保持可用, 不要求引入 Auxiliary 专用 show 命令.

不增加:

- `git gaw aux undeploy`
- `git gaw aux status`
- `git gaw aux commit`
- `git gaw aux show`
- `git gaw aux integrate`
- `git gaw aux branch -m`
- `git gaw aux retire`
- `git gaw aux abort`
- `git gaw aux discard`

不引入单独的 `git-gaw-aux` executable.

文档使用完整术语 Auxiliary GAW, CLI 使用 `aux` 缩写.

## 3. 生命周期语义

### 3.1 Init

`aux init` 创建新的 Auxiliary history, 然后调用 Auxiliary deploy.

行为尽量仿照当前 `git gaw init`.

创建前必须确认:

- `refs/gaw/HEAD` 指向有效的正式 GAW branch.
- 正式 GAW 的 repository-local reference-transaction hook 配置正确且已启用.
- 可以读取并验证正式 GAW HEAD 中的 `.gaw/config`.
- 新生成的 branch 和 `<uuid>/` 不与已存在的结构发生冲突.
- 如果指定 `--worktree-path`, 目标路径满足现有部署规则.

Root commit 仅包含 UUID 子树内的初始配置.

创建 branch 后调用同一套 Auxiliary deploy 实现.

如果部署失败, 遵循当前 GAW init 的补偿原则, 清理本次创建的 ref 和 worktree 状态. 不能假定所有失败都能够完全回滚, 需要报告残留状态.

不指定 `--worktree-path` 时, 沿用现有 GAW 的 repository-only 部署约定.

### 3.2 Deploy

`aux deploy` 只处理已经存在的 Auxiliary branch.

要求:

- 必须明确指定 `--branch`.
- 不创建新历史.
- 不执行 fetch.
- 不修改 `refs/gaw/HEAD`.
- 不创建 Auxiliary 专用 selector 或注册 ref.
- 要求有效的正式 GAW selector.
- 要求共享 protection hook 已正确启用.
- 不自行安装或修复 hook.
- 复用现有的 worktree 选择、创建、检查及失败补偿机制.

Auxiliary 可以同时存在多条独立历史, 各自拥有不同的 worktree.

### 3.3 Commit

在 Auxiliary worktree 中直接使用:

`git gaw commit`

通过当前 worktree HEAD 的规范 branch 名称识别 Auxiliary 类型.

不增加 `--auxiliary` 等模式参数.

提交必须仍在 Git worktree root 执行.

需要适配 index、配置及 staged tree 的 UUID 根目录, 但不应复制出第二套 commit 实现.

**暂不改变现有 commit 对 GAW 部署状态的要求.**

特别是, 本次不因 `undeploy` 而增加新的 commit 禁用规则.

### 3.4 Check

`git gaw check` 保留原有 worktree readiness 语义.

当当前 worktree 属于 Auxiliary branch 时, 使用对应逻辑 root 完成 committed-state 与 staged candidate 校验.

新增的 `git gaw check --branch <name>` 只检查指定 branch 的 committed state, 不检查当前 index 和 Git 操作环境.

`git gaw aux check` 分别报告 Auxiliary 历史结构合法性和安全删除准备状态.

当存在当前 Auxiliary worktree 时, 可以省略 `--branch`. 否则要求明确指定.

安全删除尚未就绪不应使一条结构合法的 Auxiliary history 在普通检查意义下失败. 未完成整合不构成历史结构错误.

### 3.5 通用 Branch 删除与重命名

取消独立的 `git gaw aux retire`, 统一使用现有 `git gaw branch -d/-D` 管理正式 GAW 和 Auxiliary branches 的删除. 不执行知识整合, 不新增其他删除命令.

**共同约束**:

- 两种操作均要求目标 branch 具有合法的 committed state, 且不存在关联 worktree. `-D` 不绕过这些约束.
- 正式 GAW branch 的 `-d/-D` 保留现有安全/强制删除行为及其他既有约束.
- 两种操作均不自动移除 worktree 或清理其他历史引用. 用户通过 Git 原生命令移除关联 worktree 后, 再请求删除 branch.

**Auxiliary 的安全删除 `branch -d`**:

1. `refs/gaw/HEAD` 必须存在, 且指向有效的正式 GAW branch.
2. Auxiliary branch tip 必须是该正式 GAW branch tip 的 Git 祖先, 表示当前 Auxiliary 历史已经被正式 GAW 保留.
3. 目标 refs 与需要检查的状态必须能够可靠读取.

`refs/gaw/HEAD` 是唯一整合目标, 不支持通过参数指定其他目标, 不得直接依赖 Git 原生 `branch -d` 的 upstream 或 HEAD 合并判断. 使用 `git merge-base --is-ancestor` 的 ancestry 语义, 不要求 Auxiliary tip 是正式 GAW tip 的直接 parent.

`aux check` 与 Auxiliary `branch -d` 复用同一套 Haskell 结构化安全删除检查逻辑. 检查结果包含目标 Auxiliary branch/tip、观察到的 selector 目标、正式 GAW tip 和各项准备条件, 并区分历史结构错误、未满足安全删除条件和 Git 操作失败.

安全删除必须在同一 Git ref transaction 中核对 selector 目标、正式 GAW tip 和 Auxiliary tip. 对 worktree 关联状态进行独立检查与竞态处理, 不能把 ref 条件更新视为 worktree 状态稳定的保证.

**Auxiliary 的主动废弃 `branch -D`**:

`-D` 表示明确放弃该 Auxiliary 历史, 不要求正式 GAW 的祖先可达性. 仍需合法 committed state、无关联 worktree, 并采用 expected-old-OID 条件化 ref 删除, 防止误删已变化的 branch; worktree 竞态仍须处理.

对未被正式 GAW 历史保留的 Auxiliary 执行 `-D` 时, 明确提示这是主动废弃, 不能保证删除后历史继续可达. 不把 `-D` 描述为已经完成整合的安全删除.

**重命名**:

`git gaw branch -m` 仍只管理当前选中的正式 GAW branch, 不允许重命名进入 Auxiliary 保留命名范围, 不提供 Auxiliary 重命名模式.

Branch 删除成功不代表原始 session 已被完整整理; 这一判断仍属于 agent 和 reviewer. `-d` 保留来源历史的保证与 `-D` 主动放弃的后果必须在诊断和文档中区分.

### 3.6 正式 GAW Undeploy

不增加 Auxiliary 专用 undeploy.

`git gaw undeploy` 继续清理 repository-local 的 GAW selector、hook 配置及既有兼容性注册信息.

它表示整个 repository 退出 GAW 活动部署和共享引用保护.

不删除任何正式或 Auxiliary branch、历史或 worktree.

执行清理时, 增加信息报告:

- 正式 GAW branches, 特别是原选中 branch.
- 当前存在的 Auxiliary branches.
- 各 branch 对应的 worktree 路径.
- 未关联 worktree 的 branch.
- 实际清理结果和未能清理的残留状态.

这些信息可以通过现有 Git refs 和 `git worktree list --porcelain -z` 获取.

建议在清理前读取必要的状态快照, 以便 selector 删除后仍可报告原选中 branch.

如果共享 hook 已成功移除, 统一提示:

`Warning: GAW reference-transaction protection has been disabled.`

不必单独重复 Auxiliary branches 不再受保护.

该提示非阻塞, 不改变正常成功的退出码. 信息采集失败也不应无故中止既有清理流程, 但必须准确标记未知信息.

若 hook 未能移除, 不得错误报告保护已经停用.

## 4. 开发节点

### N1. 统一历史结构与检查基础

**优先级**: P0

目标是让现有 GAW 配置与 workspace 检查支持显式的逻辑根目录.

主要工作:

- 设计共享的历史布局描述, 至少区分正式 GAW 和指定 UUID 根目录.
- 复用 `parseConfig`、`effectiveWorkspace`、`validateWorkspace` 和 committed-state 校验.
- 支持从指定 Git subtree 中读取 `.gaw/config`.
- 检查 Auxiliary commit tree 不存在 UUID 子树外的 tracked entries.
- 保留对整个 Git tree 的 snapshot 校验.
- 正确处理协议路径和 workspace 路径的根目录转换.
- 校验 additional-parent 路径冲突时使用真实 Git tree 路径, 避免因为错误的前缀转换产生漏报或误报.
- 实现 `git gaw check --branch`.
- 保证正式 GAW 的既有行为不变.

应优先复用现有 `Gaw.Protocol.*` 和 `Gaw.Application.State` 的逻辑, 不要复制配置解析器和验证器.

**完成标准**:

- 正式 GAW committed-state 检查保持兼容.
- 合法 Auxiliary tree 可以通过检查.
- 非法顶层路径、缺失配置、未声明 workspace 路径等能够被拒绝.
- `check --branch` 可以在没有目标 worktree 的情况下运行.
- `check --branch` 不会将缺失 index 检查误报为 worktree readiness 成功.

### N2. Auxiliary branch 识别与共享 Hook

**优先级**: P0

实现规范的 Auxiliary branch 识别及引用保护.

主要工作:

- 统一 UUIDv4 与 `_gaw_aux_<uuid>` 解析.
- 明确 Auxiliary 保留命名范围, 使现有 `branch -m` 拒绝将正式 GAW 重命名进入该范围.
- 扩展 reference-transaction hook 对 Auxiliary refs 的识别.
- 保护活动 Auxiliary branch 不被普通 Git 操作修改、删除或重命名.
- 在可能涉及损坏历史时保持保守的保护与诊断.
- 保留当前对 `refs/gaw/*` 和正式 GAW source branches 的保护行为.
- 合法 GAW 内部操作沿用受控 hook bypass 机制.
- 不增加第二套 hook 安装协议.

Hook 不应依赖 Auxiliary root `.gaw/config` 出现在 Git tree 顶层.

对于命名符合 Auxiliary 约定的 refs, 需要避免由于内容已经损坏或缺失而错误地将其视为不受保护的普通分支.

**完成标准**:

- 共享 hook 能保护正式 GAW 和 Auxiliary branches.
- 普通 Git 对活动 Auxiliary refs 的非法更新被拒绝.
- GAW CLI 的受控更新可以正常执行.
- 普通非 GAW branch 的既有行为不变.
- 非法类型重命名被拒绝; Auxiliary 的授权删除走通用 `branch -d/-D` 的相应检查, 不依赖普通 Git 删除绕过 hook.
- Hook 被 `gaw undeploy` 移除后, 不再声称仍存在 GAW 引用保护.

### N3. Init、Deploy 与通用 Commit

**优先级**: P0

实现 Auxiliary history 的创建与日常工作.

主要工作:

- 新增 `gaw aux init`.
- 新增 `gaw aux deploy`.
- 初始化时复制正式 GAW 的已提交 config.
- 创建独立 root commit 和规范 branch.
- 复用已有 init/deploy 的操作与补偿结构.
- 让现有 `gaw commit` 支持 Auxiliary worktree.
- 让现有 `gaw check` 支持 Auxiliary staged candidate.
- 保留原有提交信息、提交身份、additional parents 和变更隔离约束.
- 支持多条 Auxiliary histories 并存.

**完成标准**:

可以创建 Auxiliary history, 部署到 worktree, 通过普通 `gaw commit` 创建多个 checkpoint, 并从任意后续会话恢复该历史.

不同 Auxiliary 的工作区和 refs 不互相干扰.

### N4. Auxiliary 安全删除检查与通用 branch 生命周期扩展

**优先级**: P0

实现只读安全删除准备检查, 并扩展现有 `git gaw branch -d/-D`, 不改变正式 GAW branch 的既有删除行为.

主要工作:

- 新增 `gaw aux check`.
- Auxiliary 删除统一使用现有 `gaw branch -d/-D`, 不新增 `aux retire` 或其他删除命令.
- 复用已有 committed-state 校验.
- 为 Auxiliary `-d` 验证 `refs/gaw/HEAD` 所选正式历史的有效性及 tip 祖先可达性, 不采用 Git 原生 upstream/HEAD 合并判断.
- 为两种删除检查所有相关 worktree 关联; `-D` 不跳过结构或 worktree 约束.
- 实现供 `aux check` 和 Auxiliary `branch -d` 复用的结构化安全删除报告和纯判断逻辑.
- Auxiliary `-d` 在同一 ref transaction 中核对 selector 目标、正式 GAW tip 和 Auxiliary tip; 独立处理 worktree 检查竞态.
- Auxiliary `-D` 跳过整合可达性, 仍使用条件化 ref 删除, 并提示未被正式历史保留的来源可能不再可达.
- 明确区分结构错误、未满足安全删除条件、主动废弃和 Git 操作失败.

除保留的 `aux check` 外, 不新增删除检查模式, 也不增加 `aux abort`、`aux discard` 等命令.

**完成标准**:

- 未被所选正式 GAW 历史包含当前 tip 的 Auxiliary, `-d` 拒绝; `-D` 可主动废弃并给出相应提示.
- 两种删除均拒绝非法 committed state 或关联 worktree, 不自动清理 worktree/其他历史引用.
- 条件满足的 `-d` 删除后历史仍从所选正式 GAW tip 可达; 不对 `-D` 作同样保证.
- 检查后 selector 改选、正式 tip 改变或 Auxiliary tip 更新时, 安全删除不能使用过期结果成功; `-D` 也不能误删变化后的 tip.
- Worktree 关联状态变化被独立检查和处理.
- 正式 GAW 的 `-d/-D` 行为保持兼容, 非法类型重命名被拒绝.

### N5. Status、Undeploy、Skill 与完整验收

**优先级**: P1, 发布前必须完成

主要工作:

- 扩展 `gaw status`, 明确区分正式 GAW、Auxiliary 和普通 branches.
- 继续报告 selector、hook 和 worktree 状态.
- 扩展 `gaw undeploy` 的状态报告.
- 更新 CLI usage 和各命令 help, 特别是 `branch`、`aux` 对安全删除与主动废弃的区别.
- 更新 bundled Git Agent Workflow skill.
- 完成多 Auxiliary、跨 session/agent 整合及生命周期回归测试, 覆盖正式 GAW/Auxiliary 的 `-d/-D`、未整合/已整合、worktree、并发 ref 更新和非法类型重命名.
- 检查旧版本 GAW 数据和命令兼容性.

Bundled skill 需要说明:

- 何时创建独立 Auxiliary history.
- 如何选择具有独立恢复价值的来源 checkpoint.
- 如何处理原始证据、archive snapshot 和 provenance 不确定性.
- 如何将 Auxiliary 的结论整合进正式 GAW memory.
- 如何通过 additional parents 保留来源历史.
- 如何检查 Auxiliary, 对已整合历史使用 `branch -d`, 或通过 `branch -D` 主动放弃未整合历史, 并理解其可达性后果.
- 如何避免重复归档或将旧证据重新当成当前指令.

Skill 负责知识充分性与来源解释, CLI 只负责可验证的结构条件.

**完成标准**:

Agent 能在不修改正式 GAW 历史模型的情况下, 独立整理多个来源, 在正式 GAW 中形成当前知识, 并区分已整合 Auxiliary branch 的安全删除与未整合历史的主动废弃.

## 5. 集成验收场景

以下场景建议全部覆盖.

| 场景 | 预期结果 |
|---|---|
| 初始化时正式 GAW 未部署 | 拒绝, 不产生残留活动 branch |
| 初始化时 hook 缺失或冲突 | 拒绝, 不自行安装或修复 |
| 从 v0/v1 正式配置初始化 | 原样复制并正确解释 |
| 新 Auxiliary 只有配置文件 | 有效初始状态 |
| Auxiliary tree 出现 UUID 根目录外文件 | 校验失败 |
| Auxiliary 混合修改协议与 workspace | 提交失败 |
| 多条 Auxiliary 同时存在 | 相互独立且受共享 hook 保护 |
| 普通 Git 修改 Auxiliary ref | 在 hook 生效时被拒绝 |
| 正式 GAW 引用 Auxiliary 的中间 checkpoint | 允许引用, 当前 tip 未被保留时 `-d` 拒绝; `-D` 可主动废弃并提示后果 |
| 正式 GAW 引用 Auxiliary tip | 满足 `-d` 的整合可达性条件 |
| Auxiliary upstream/调用者 HEAD 已包含 tip, 所选正式 GAW 未包含 | `-d` 拒绝, 不采用原生 Git 合并目标 |
| 未整合但结构合法的 Auxiliary | `aux check` 分别报告结构合法与安全删除未就绪 |
| Auxiliary 仍附有 worktree | `-d/-D` 均拒绝, 不自动移除 worktree |
| Auxiliary committed state 非法 | `-d/-D` 均拒绝, `-D` 不绕过结构检查 |
| 删除 worktree 后检查 Auxiliary | 通过 `aux check --branch` 正常检查 |
| 删除检查后 Auxiliary tip 改变 | `-d/-D` 的条件删除失败, 不误删新 tip |
| 安全删除检查后 selector 改选或正式 GAW tip 改变 | 同一 ref transaction 的状态核对失败, 不使用过期可达性结果 |
| 删除检查后出现 worktree 关联 | 独立检查并处理竞态, 不把 ref transaction 当成 worktree 锁 |
| 将正式 GAW branch 重命名进入 Auxiliary 保留范围 | `branch -m` 拒绝 |
| 对 Auxiliary 请求 `branch -m` | 拒绝, 不提供 Auxiliary 重命名模式 |
| 正式 GAW 的 `branch -d/-D` | 保留现有安全/强制删除行为与约束 |
| 执行正式 GAW undeploy | 保留所有 branches 和 worktrees, 输出状态与保护提示 |
| Undeploy 后执行已有 commit | 保留原有语义, 不增加新的部署限制 |
| 重新执行正式 GAW deploy | 恢复共享 hook 保护 |
| Auxiliary 经 `branch -d` 删除后 | 来源历史仍从所选正式 GAW tip 可达 |
| 未整合 Auxiliary 经 `branch -D` 删除后 | 明确属于主动废弃, 不保证来源历史继续可达; 不清理其他历史引用 |
| 正式 GAW 普通生命周期 | 现有回归测试全部通过 |

对于复杂失败路径, 还应测试部分操作成功后的补偿、残留信息报告以及重新执行时的行为.

## 6. 明确不在本次实现范围内的功能

本次不实现:

- 正式 GAW 历史 split 或 fusion.
- 多个权威 GAW first-parent 分支的自动合并.
- 新的 Git parent 类型或 parent position 角色协议.
- 动态配置继承.
- Auxiliary 专用配置版本.
- Auxiliary 专用 refs namespace 或 selector.
- 永久 Auxiliary 注册表.
- 独立的 `git-gaw-aux` executable.
- 自动 session 导入、自动知识整合或完整性判断.
- 自动保留全部对话、工具日志和其他原始材料.
- 自动复制 Auxiliary archive 到正式 GAW archive.
- 自动清理或删除 Auxiliary worktree.
- 跨 repository 的 Auxiliary 同步协议.
- 历史重写、OID 稳定化或持久语义标识机制.

不要因为代码复用方便而引入与当前需求无关的抽象层.

## 7. 与现有 GAW 历史模型的关系

正式 GAW 始终通过自己的 first-parent 链表达项目记忆演化.

Auxiliary 自身也具有独立的 first-parent 链, 但不是正式 GAW 的另一条权威记忆分支.

正式 GAW 引用 Auxiliary checkpoint 时, Auxiliary commit 是外部历史关联, 而不是正式 GAW 的另一位 first-parent 前驱.

这会使当前文档中将 additional parents 一律描述为 project commits 的措辞不再完全充分.

应在相关文档和 skill 中明确 Auxiliary history 作为外部历史证据的合法用途.

但本次不要求修改 Git parent 位置规则, 不引入额外的 parent type, 也不要求大规模重命名现有代码中的 project-parent 概念.

这属于 Issue #9 所讨论的历史模型边界, 可以记录观察结果, 但不应扩展为 split/fusion 的实现任务.

关于持久引用, 继续遵守 Issue #6 的约束: 不把 Auxiliary 或正式 GAW checkpoint OID 作为长期语义身份. Git ancestry 负责结构关联, workspace 内容负责知识解释.

## 8. 开发执行原则

1. 按 N1 -> N2 -> N3 -> N4 -> N5 线性推进, 每个节点结束后完成针对性测试.
2. 节点可以包含多个 GAW 或项目 Git commit, 不要求节点与 commit 一一对应.
3. 优先复用现有 Haskell Protocol、Application 和 System 层接口.
4. 保持检查函数返回结构化数据, 渲染与状态转换分离.
5. 对明确的 Git 错误、结构损坏和无法确定的状态采取保守处理.
6. 对正常的未整合、未部署和未满足安全删除条件状态, 不错误宣称历史损坏.
7. 不在实现中偷偷引入额外的 ref 注册、强制同步、回溯修复或自动历史重写.
8. 保持 v0.6.0 的既有 CLI 和历史行为兼容, 除明确列出的扩展外不做无关重构.
9. 在每个节点结束时记录实际实现、验证结果、尚存问题及其与设计的差异.
10. 如果实现暴露新的协议级矛盾, 先报告问题及最小备选方案, 不擅自扩大设计.

## 9. 完成判据

本阶段完成应满足:

- 既有 GAW 功能与测试不发生回归.
- Auxiliary 使用独立 root 和 UUID 子树, 共享标准 GAW config 与 commit 语义.
- 多条 Auxiliary history 可以并行维护.
- 正式 GAW 可以通过现有 additional-parent 机制关联任意有必要的 Auxiliary checkpoints.
- GAW selector 和 hook 的职责边界保持清晰.
- 全局 status、undeploy 可以发现并报告 Auxiliary 及其 worktrees.
- Auxiliary `branch -d` 依赖唯一的正式 GAW selector 和可验证的 Git ancestry, 删除后保留已整合的来源历史.
- Auxiliary `branch -D` 明确表示主动废弃, 跳过整合可达性, 但仍遵守合法 committed state、无 worktree 和条件删除要求.
- 正式 GAW branch 的既有 `-d/-D` 行为不变, `branch -m` 不允许进入 Auxiliary 保留命名范围.
- Bundled skill 足以指导跨 session、跨 agent 的历史整理和知识整合.

完成后, Auxiliary GAW 应被视为 GAW 的一项受控历史整理能力, 而不是第二套持久记忆系统.
