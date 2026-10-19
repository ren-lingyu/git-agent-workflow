# GAW Knowledge Establishment and Consolidation Workflow Extension

**类型**: Skill 开发指导文档

**基线**: `git-agent-workflow` v0.7.0 及其后续已提交修改

**范围**: `cabal/share/skills/git-agent-workflow/`

**目标**: 在现有 Memory, Archive, Auxiliary 和 checkpoint 规则上, 扩展通用知识建立与跨来源整合工作流.

## 0. 总体目标与设计约束

GAW 已经提供持久记忆维护、单源历史重建、选择性归档和 Auxiliary 生命周期管理.

本轮主要补充:

1. 从空白或不充分的 GAW Memory 建立知识基线.
2. 使 Formal 与 Auxiliary 复用同一套单源知识建立和维护工作流.
3. 支持在已有 Formal Memory 上进行跨来源知识整合.
4. 支持集中式、分布式以及混合式 agent 执行.
5. 分别判断知识整合、原始证据归档和 Git 来源历史保留.
6. 支持必要的清洁历史重建、来源退役和整合验收.

### 不属于本轮范围的事项

- 不修改 GAW CLI、Git refs、commit 协议或配置格式.
- 不引入新的持久 source ID、parent 角色或元数据协议.
- 不要求一个 session、agent 或输入文件对应一个 Auxiliary.
- 不强制创建 Auxiliary、Archive 或固定数量的 checkpoints.
- 不要求归档完整会话、rollout 或工具日志.
- 不将 Git GC 变成 Auxiliary 删除的自动行为.
- 不修改普通项目历史.
- 不追溯改写既有 GAW checkpoints.
- 不新增不必要的 scripts、templates 或自动化系统.

新编写的 skill 文本统一使用英文. 本文作为开发指导使用中文, 不要求翻译已存在的历史资料.

## N0. 基线检查与现有规则盘点

**性质**: 只读调查, 不修改文件.

### 工作内容

检查当前 `main` 的:

- `SKILL.md`
- `references/memory.md`
- `references/archive.md`
- `references/auxiliary.md`
- `references/skills.md`

确认现有规则的实际位置和含义, 特别是:

- Memory 的当前状态维护与 retrospective reconstruction.
- Archive 的选择标准、快照完整性和不可变性.
- Auxiliary 的独立 root、checkpoint 和生命周期.
- Exact-snapshot provenance 与 additional-parent 选择.
- Formal Memory 的权威性和 GAW workspace snapshot 完整性.
- GAW checkpoint 的选择性创建和 index 审阅.
- Skill 的授权边界及现有文档引用方式.

特别确认此前已经提交的两项修改存在:

1. 每次获得新材料时重新进行归档判断, 不降低归档门槛.
2. 新编写的 GAW 内容优先使用英文, 不受原材料语言影响.

### 交付与验收

形成一份简短的规则复用清单, 区分可直接复用、需要补充和确实缺失的内容.

不得因重新表述相同原则而增加重复规定.

**完成条件**: 明确本轮所需修改的准确文件和章节, 无需提交。

---

## N1. 固定知识工作流的语义边界

**性质**: 设计确认, 不引入 CLI 或数据协议.

### 1.1 单源知识工作流

Single-source establishment 指在明确限定的证据范围内建立和维护 GAW 知识.

Source 不必是一个文件、一次 session 或一个 agent. 一个连贯的工作范围可以包含多个 sessions、不同工具输出及多个 agent 的连续工作.

Formal 和 Auxiliary 均采用相同的单源工作流, 包括:

- 当前知识建立和维护.
- 重要动机、决定与验证结果的提炼.
- 有证据支持的历史状态重建.
- 选择性 Archive.
- First-parent checkpoints.
- Exact-snapshot project provenance.
- Handoff 和恢复.

Auxiliary 不具有单独的知识语义. 它只增加来源范围、独立 Git history、生命周期和权威性边界.

### 1.2 知识整合工作流

Consolidation 指将来自不同知识范围的内容整合到已有的实质 Formal Memory.

它可以涉及一个或多个外部来源. 普通 Formal Memory 的持续更新仍由 `memory.md` 负责, 不应一律升级为 Consolidation.

当 Formal 尚无实质记忆, 且需要同时处理多个来源时, 可以结合 Establishment 和 Consolidation 的规则形成初始知识基线.

### 1.3 三种独立判断

明确区分:

**Knowledge integration**

判断哪些结论、动机、理由、证据限制和未决问题值得进入 Formal Memory.

**Evidence archival**

判断哪些原始材料具有独立解释、复现、审计或恢复价值. 继续由 `archive.md` 负责.

**Git source-history retention**

判断某个来源的 Git 历史是否值得通过 additional parent 纳入 Formal ancestry.

三者互不构成充分条件.

### 1.4 Additional-parent 的保留后果

额外 parent 不仅关联一个来源 checkpoint, 还会使其完整祖先闭包进入 Formal 的可达历史.

因此, 来源被实际阅读或其知识得到采纳, 不应自动导致 Git ancestry 保留.

决定关联时必须同时满足:

- 来源 checkpoint 与本次整合实际相关.
- 其确切身份和使用范围有证据支持.
- 长期保留该可达历史具有独立价值.
- 已确认对应的授权和保留边界.

当不保留来源历史时, Formal 仍须保存足以理解整合结果的知识与证据限制, 不依赖未来可能消失的分支、OID 或路径.

### 交付与验收

形成确定的概念与职责边界, 供 N2-N4 复用.

**完成条件**: 普通维护、单源建立、多源整合和 Auxiliary 生命周期之间没有含糊的强制依赖。

---

## N2. 实现 Establishment 工作流

**主要文件**:

- 新增 `references/establishment.md`
- 必要时小幅修改 `references/memory.md`

**依赖**: N1 完成.

### 2.1 适用条件

Establishment 用于建立此前不存在或明显不充分的持久知识状态.

支持以下情形:

- 项目尚未建立实质 Formal Memory.
- GAW 已初始化, 但 workspace 中还没有足够的项目知识.
- 一个新的 Auxiliary 刚刚初始化, 需要建立其来源知识.
- 需要根据早期材料恢复有独立价值的历史状态.

如果 Formal 已有充分的当前知识, 一般日常更新应直接使用现有 `memory.md`, 不必进入完整 Establishment 流程.

### 2.2 建立流程

在新 reference 中描述:

1. 确认合法 GAW 状态与权限.
2. 确定本次知识范围及证据 horizon.
3. 检查已有记忆, 不重复已经持久化的知识.
4. 粗略覆盖完整材料范围, 识别重要事件、状态与缺口.
5. 提炼当前可恢复的知识基线.
6. 按需重建具有独立恢复价值的历史 checkpoints.
7. 按既有规则独立进行 Archive 判断和 provenance 判断.
8. 验证最终 workspace snapshot 可以独立解释.
9. 使后续工作自然进入普通 Memory maintenance.

不得要求先保存所有原始材料才能建立知识.

### 2.3 与 `memory.md` 的关系

已有 `Reconstruct supported earlier states` 规则继续是单源历史重建的权威规范.

`establishment.md` 只解释建立工作流的组织过程及适用条件, 不重新定义时间顺序、恢复粒度或 parent 规则.

`memory.md` 可以补充说明: 重要的 GAW 知识建立、整合和维护裁决本身也可能具有持久记忆价值.

### 2.4 验收场景

- 空 Formal, 只有一份来源, 能建立可恢复的当前知识.
- 空 Auxiliary, 有跨 session 的连续资料, 能恢复选定历史状态.
- 只有最终结论有可靠证据时, 不制造虚假的中间 checkpoints.
- 材料不足时, 明确记录恢复限制.
- 没有独立原始证据保留价值时, 不自动创建 Archive.
- 初始建立完成后, 不强制继续使用 Establishment 处理普通更新.

### 交付

完成 `establishment.md` 及必要的 `memory.md` 修改.

检查内容自洽后可以作为独立的开发节点提交. 尚未完成全局 routing 时, 不应声称新工作流已经正式集成.

---

## N3. 实现 Consolidation 工作流

**主要文件**:

- 新增 `references/consolidation.md`

**依赖**: N2 完成.

这是本次扩展的主要新内容.

### 3.1 适用范围

Consolidation 负责不同知识范围之间的比较、选择和整合.

来源可以是:

- 已有 Auxiliary GAW.
- 其他已建立的知识记录.
- 外部项目文档或历史材料.
- 直接取得的会话或工具资料.

不要求全部来源先转化为 Auxiliary.

### 3.2 来源盘点

开始整合前, 识别:

- 本次目标及 Formal 当前已知内容.
- 各来源覆盖的工作范围和证据 horizon.
- 来源之间的重叠、fork、先后关系和缺口.
- 已形成的结论、被撤回的方案和未完成的决定.
- 各来源的证据强度和历史验证范围.
- 是否存在不适合长期保留的材料.

不要根据 session 数量或 Auxiliary 数量机械决定最终 Formal checkpoints 数量.

### 3.3 内容比较与裁决

针对需要整合的知识:

1. 与 Formal 当前结论比较.
2. 区分补充、重复、冲突、过时及未决内容.
3. 对重大冲突核对支持证据.
4. 当前项目事实必要时重新验证.
5. 区分历史原始判断、后续纠错和本次新增判断.
6. 只将具有持续价值的结果写入 Formal.
7. 保留重要设计动机及尚未消除的证据限制.

不能因为来源时间更近或多个摘要一致, 就自动认定其结论正确.

未能解决的实质冲突可以明确保留为未决问题.

### 3.4 执行模式

支持三种模式:

**Centralized**

一个 agent 完成来源盘点、知识判断和 Formal 整合.

**Distributed**

多个 agent 在各自授权范围内分别建立来源知识, 再由指定整合者统一处理 Formal.

**Hybrid**

部分来源由独立 agent 整理, 其余来源由整合者直接处理.

三种模式共享相同的知识与 checkpoint 标准.

并行工作不得暗中产生多个互相竞争的 Formal 写入者. Formal 更新需要协调, 在提交前重新核对当前状态与完整候选 snapshot.

### 3.5 分阶段整合

允许根据主题、知识依赖或阶段结果分批形成 Formal checkpoints.

每个 checkpoint 应具有独立恢复价值, 不要求一个来源对应一个 Formal commit.

整合中间状态应当足以支持跨 session 恢复, 但不需要保留逐条 CLI 操作进度.

当一次整合被中断时, 后续 agent 应能判断:

- 哪些知识已被采纳.
- 哪些来源已被审阅.
- 哪些内容仍存在争议.
- 哪些历史关联已建立.
- 下一步需要完成什么.

### 3.6 来源历史保留

Consolidation 必须独立判断知识整合与来源 Git 历史保留.

来源的实际阅读和知识采纳不自动要求 additional parent.

如果选择保留来源, 采用 `auxiliary.md` 已有的准确 checkpoint 关联与 Git 生命周期规则.

如果不保留来源, Formal Memory 不能依赖其未来可用性.

不得为了让整合记录看起来具有 provenance 而创建猜测性的 parent 关联.

### 3.7 整合验收

验收时分别检查:

- 当前 Formal Memory 的正确性与完整性.
- 来源覆盖及未恢复的缺口.
- 重要历史演化是否仍可恢复.
- 决策冲突及纠错是否得到适当处理.
- 静态与运行验证边界是否准确.
- 被保留 Git ancestry 的实际范围.
- 不保留来源时是否留下失效依赖.
- 当前工作是否具备后续恢复入口.

整合完成不意味着所有历史主张都已经重新验证, 也不意味着所有来源必须退役.

### 交付

完成 `consolidation.md`.

使用 NixOS 清洁重建的已知经验作为设计检验案例, 但不将其特定目录、来源数或历史清理方式变成通用强制要求.

---

## N4. 调整 Auxiliary 工作流

**主要文件**:

- 修改 `references/auxiliary.md`

**依赖**: N2 和 N3 完成.

### 4.1 复用通用单源工作流

在 `auxiliary.md` 开头明确:

Auxiliary 在其限定来源范围内, 使用与 Formal 相同的 Establishment、Memory maintenance、Archive、checkpoint 和 provenance 规则.

Auxiliary 专有规则只涉及:

- 独立 Git root 和 workspace 结构.
- 创建、部署及结构检查.
- 来源范围和 Formal 权威边界.
- 与 Formal 的历史关联.
- 分支删除、恢复和退役.

避免为 Auxiliary 另写一套知识建立步骤.

### 4.2 修正整合时的 parent 选择

重点调整现有 `Integrate selected knowledge into formal GAW` 中的来源 parent 规则.

不再将关联来源 checkpoint 描述为每次知识整合都应执行的默认步骤.

明确:

- 相关性、确切证据和独立保留价值必须共同考虑.
- Additional parent 的保留范围包括完整祖先闭包.
- 知识可以整合而来源 Git 历史不保留.
- 选择不保留时, Formal 仍需自解释.
- 现有 project-parent exact-snapshot 规则不放宽.
- Source ancestry 的保留不表示采纳其全部主张.

### 4.3 清洁重建

补充特殊情况:

当现有来源历史不适合长期保留, 但其知识演化仍有价值时, 允许建立新的独立 Auxiliary.

复用 Establishment 规则进行重建, 并要求:

- 以有证据支持的历史知识状态为基础.
- 保留重要的设计理由、纠错和验证限制.
- 不继承被排除的旧来源 ancestry.
- 不默认复制旧 Archive.
- 不伪造原始事件时间或原始验证记录.
- 将新审阅结论与历史阶段已有认识区分.
- 先验收替代知识, 再考虑放弃旧历史.

清洁重建不是创建 Auxiliary 的默认步骤.

### 4.4 退役与清理

保留既有 `branch -d`、`branch -D`、worktree 和可达性规则.

只补充必要的边界:

- 知识整合完成不自动表示可以删除来源.
- `branch -D` 不保证相关对象已经消失.
- GC 与分支退役是不同的授权决策.
- 任何可能清除其他不可达对象的操作都应重新评估范围.
- 清理结果只对被检查的仓库对象库有效, 不保证外部副本被清除.
- 不将激进 GC 设为每次退役的常规步骤.

实际 Git 操作仍应使用现有公共接口与宿主授权机制.

### 交付

完成 `auxiliary.md` 的调整.

检查其与 `establishment.md`、`consolidation.md` 的交叉引用, 删除不必要的重复规则, 保留完整生命周期说明.

---

## N5. 主 Skill 集成与最终验收

**主要文件**:

- 修改 `SKILL.md`
- 必要时修正已新增或已修改的 references.

**依赖**: N2-N4 全部完成.

### 5.1 更新 Routing

在 `Load workflow details when needed` 中提供清晰的入口:

| 任务 | 主要工作流 |
| --- | --- |
| 普通记忆维护 | `memory.md` |
| 空或不充分的知识基线建立 | `establishment.md` |
| 单源历史重建 | `memory.md` + 按需 `establishment.md` |
| Auxiliary 内部知识建立 | `establishment.md` + `auxiliary.md` |
| 跨来源知识整合 | `consolidation.md` |
| 选择性原始证据归档 | `archive.md` |
| Auxiliary 生命周期与来源恢复 | `auxiliary.md` |
| 项目 Skill 的维护与移植 | `skills.md` |

避免把所有 reference 都变成每次任务必须读取的文件.

### 5.2 跨文件一致性

重点检查:

1. 是否存在不同文件对同一概念给出不同定义.
2. 是否意外要求普通维护使用复杂的 Establishment 或 Consolidation.
3. 是否把 Auxiliary 描述为知识整合的必需中间层.
4. 是否仍然存在默认强制关联来源 parent 的条文.
5. 是否重复或削弱了 Archive 的选择性门槛.
6. 是否保留了既有 exact-snapshot provenance 规则.
7. 是否允许已有历史采用旧文档约定.
8. 是否保持 Formal Memory 为当前知识权威.
9. 是否维持授权和执行工具的既有边界.

### 5.3 工作流场景验收

至少对以下场景进行桌面推演或可行的受控测试:

| 场景 | 预期行为 |
| --- | --- |
| 单个 session 的普通开发 | 直接维护现有 Memory |
| 空 Formal, 一个来源 | 建立单源知识基线 |
| 空 Formal, 多个来源 | Establishment 与 Consolidation 组合 |
| 一个来源跨多个 sessions | 可以在同一知识范围内持续维护 |
| Auxiliary 的连续知识工作 | 复用普通单源规则 |
| 多个 agent 分别整理来源 | 支持协调后汇入 Formal |
| 多个来源观点冲突 | 保存裁决理由或未决状态 |
| 来源只有最终结论值得保留 | 不强制创建 Auxiliary 或保留整段历史 |
| 来源历史本身具有恢复价值 | 可以经确认关联相应 Auxiliary checkpoint |
| 来源包含不宜长期保留的归档 | 可以清洁重建或不保留来源历史 |
| 已整合来源准备放弃 | 单独判断历史保留与删除授权 |
| 重新获取相同路径的材料 | 重新判断归档价值, 不默认归档 |

重点验证 agent 能够依据规则做出正确选择, 不要只测试特定句子或标题是否存在.

### 5.4 工程验收

按项目既有开发环境执行适用检查:

- Markdown 链接与资源路径检查.
- Skill 元数据及 reference 完整性检查.
- 已安装或打包后的实际 Skill 路径检查.
- 相关自动化测试.
- 项目现有构建与格式检查.

如果某些测试因环境限制无法运行, 明确报告, 不将未执行的测试记为通过.

### 5.5 最终交付

完成后提供:

1. 修改文件和新增文件清单.
2. 两个新工作流的适用条件.
3. 与原有 Memory、Archive、Auxiliary 规则的关系.
4. 关键行为变化, 特别是来源 parent 的选择.
5. 各验收场景的实际结果.
6. 未解决的设计问题或实现限制.

若实际开发发现规范无法在不改变 CLI 协议的前提下实现, 停止扩大实现范围, 说明具体冲突, 不擅自引入新协议.

---

## 6. 节点推进与提交规则

严格按照 N0 → N1 → N2 → N3 → N4 → N5 的顺序推进.

每个节点开始时, 先读取上一节点已完成的实际结果, 不从最初计划假设中间工作已经成功.

每个节点结束时:

- 检查相关文件与既有规范是否一致.
- 报告完成内容、验证结果和仍未解决的问题.
- 只有在形成独立、完整、有恢复价值的状态时才提交.
- 如果需要 Git commit, 遵守项目现有 git-maintenance 和 GAW 规则.
- 不把尚未完成的后续节点描述为已实施.
- 不为了满足节点数量而制造无意义的中间提交.

如果相邻节点的修改存在不可分割的依赖, 可以合并为同一实际提交, 但仍应分别完成其语义验收.

## 7. 最终完成条件

此次扩展完成时, 应满足以下总体结果:

- Formal 和 Auxiliary 共享统一的单源知识工作流.
- Establishment 能建立缺失或不充分的持久知识基线.
- Consolidation 能处理跨来源知识比较、整合与恢复.
- Knowledge、Archive 和 Git ancestry 的保留各自有独立判断依据.
- 不要求每个来源都有 Auxiliary.
- 不要求每次知识整合都关联 source parent.
- 清洁重建有明确适用边界, 不是日常强制流程.
- 现有 CLI、Git 历史协议和已有项目工作流保持兼容.
- 新旧 skill 规则自洽, 并能够通过典型场景验收.

最终 skill 应保持简洁, 将跨来源工作流的复杂性限制在真正需要它的任务中, 不增加普通 GAW 使用的日常负担.
