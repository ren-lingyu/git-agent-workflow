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
















# GAW Skill 知识工作流扩展修订指导

**类型**: 开发指导与实施验收规范

**目标项目**: `ren-lingyu/git-agent-workflow`

**基线**: v0.7.0 及其后续已提交的 Archive 重新获取判断规则和英文工作语言规则

**修订对象**: 2026-10-19 提出的 Establishment / Consolidation / Auxiliary 工作流扩展 diff

**状态**: 待实施

## 0. 任务概述

本次工作不是从头设计 GAW Skill, 而是修订已有工作流扩展方案, 使其符合 GAW 的原始动机和已经确认的通用语义.

原有扩展方案已经引入:

- `references/establishment.md`, 用于建立知识基线.
- `references/consolidation.md`, 用于跨来源知识整合.
- Auxiliary 对普通单源知识工作流的复用.
- 知识整合、证据归档、来源 Git 历史保留的独立判断.
- 相关 `SKILL.md` routing、`memory.md` 和 Cabal 文件清单修改.

这些工作原则上保留, 不应全面重写.

但现有 diff 仍存在以下问题:

1. 对 Auxiliary 的描述过于接近临时来源资料库, 没有充分强调多条发现线的交错演化与 Formal 的阶段性整合.
2. 对 source parent 的保留价值要求过窄, 过度强调独立的长期 recovery value.
3. 引入了缺少充分通用语义支持的 Clean Reconstruction 工作流.
4. 对此前 NixOS 历史清理实验中的 GC 和历史替换问题给予过多关注.
5. 对 GAW 从首次持久化开始执行材料筛选与脱敏的要求不够明确.
6. Archive 的默认选择范围仍然较宽, 未充分体现 Knowledge-first.
7. Establishment 的适用条件与已有 Memory retrospective reconstruction 有一定重叠.
8. Consolidation 中存在偏向特定项目的验证措辞.

本次修改应解决这些问题, 同时保留现有 CLI 和 Git 历史协议.

## 1. 最终设计原则

### 1.1 GAW 的主要持久化对象是知识

GAW 的主要目的不是备份 agent 会话, 而是持续保存能够支持后续工作的知识状态.

Memory 应优先记录:

- 当前目标及其动机.
- 已经形成的结论和设计决定.
- 重要的论证、实验发现及其解释.
- 有意义的替代方案和被放弃的判断.
- 验证结果、验证范围和不确定性.
- 尚未解决的问题和下一步工作.

原始会话、工具日志及其他输入材料只作为形成知识的证据, 不默认构成需要持久保存的内容.

### 1.2 Formal 与 Auxiliary 共享知识工作流

Formal GAW 和 Auxiliary GAW 应使用相同的:

- Establishment.
- Memory maintenance.
- Retrospective reconstruction.
- Selective Archive.
- Checkpoint selection.
- Exact-snapshot provenance.

Auxiliary 不应另外定义知识内容、历史恢复或 checkpoint 选择标准.

其专有职责主要是:

- 独立的 Git history.
- 限定的来源范围.
- Git tree 和 worktree 结构.
- Formal 当前知识权威性的边界.
- Formal 与来源 checkpoints 的历史关联.
- Auxiliary 生命周期和来源恢复.

### 1.3 Auxiliary 支持独立发展的多条发现线

Auxiliary 最初的主要动机是支持不同 sessions 和 agents 中并行、交替或持续发展的知识发现过程.

一条发现线可以在多个 sessions 中继续发展. 一个 session 也可以涉及多条发现线.

Auxiliary 数量不与 session、agent、文件或输入来源数量强制一一对应.

Formal 可以选择性地将多条发现线中的不同 checkpoints 整合进自身 first-parent 历史.

整合不要求等待 Auxiliary 工作完成, 也不要求每条 Auxiliary 最终只以最新 tip 进入 Formal.

### 1.4 Formal 历史与来源历史承担不同职责

Formal 的 first-parent 历史记录项目当前知识如何演化.

各 Auxiliary 的 first-parent 历史记录相应发现线内部如何演化.

Formal 的 additional-parent 关联可以记录某个 Formal checkpoint 采用了哪些准确的来源状态.

这些关联不合并 Git trees, 不自动采纳来源中的全部主张, 也不能代替项目事实的实际验证.

### 1.5 三种独立判断

必须区分:

1. **Knowledge integration**: 哪些知识值得纳入 Formal.
2. **Evidence archival**: 哪些原始材料具有独立归档价值.
3. **Git source-history retention**: 哪些来源 checkpoints 值得形成 Formal 历史关联, 以及由此产生的历史保留后果是否可以接受.

三者不应自动互相推出.

但也不能把第三项简化为"是否具有独立的长期恢复价值", 从而忽略 additional parent 对 Formal 知识演化的来源关联作用.

### 1.6 从首次持久化开始筛选和脱敏

GAW 应优先在 Memory、Archive、checkpoint message 和 Git ancestry 第一次持久化之前排除不必要的敏感内容.

不能将后续删除文件、重建 Auxiliary 或执行 GC 作为正常脱敏策略.

这条原则适用于所有 GAW 工作流, 不限于 Auxiliary.

## 2. 非目标与兼容性约束

本轮不得引入:

- 新的 GAW CLI 命令.
- 新的 refs 命名空间.
- 新的 commit-parent 类型.
- 新的持久化 source ID 或 source registry.
- 新的 Archive manifest 协议.
- 强制的 source-to-Auxiliary 映射.
- 固定的 GAW Memory 文件模板.
- 固定的 checkpoint 数量.
- 完整 conversation 或 rollout 的常规归档.
- 常规 Clean Reconstruction 或 Sanitized Auxiliary Reconstruction.
- 自动 Git GC、自动历史重写或自动分支清理.
- 对现有 GAW 历史的追溯改写要求.

不得因修订通用 skill 而将 NixOS 实验中的具体文件结构、UUID 数量、历史清理操作或验证方式变成通用规定.

保留已有 GAW 工作流中的授权边界、只读检查、显式 staging、`git gaw check` 和公共 CLI 操作要求.

新增 skill 文本优先使用英文. 现有历史资料不因语言规则而需要翻译.

---

# 3. 相继实施节点

建议按照 N0 -> N1 -> N2 -> N3 -> N4 -> N5 推进.

每个节点应在前一个节点验收后继续. 不要求一个节点严格对应一个 Git commit, 但任何中间提交都应保持文档自洽, 并明确尚未完成的部分.

## N0. 核对当前基线与修订范围

**性质**: 只读检查.

### 工作内容

检查当前实际工作树和 index, 确认此前扩展 diff 是否已经应用、部分应用或尚未应用.

读取:

- `SKILL.md`
- `references/memory.md`
- `references/archive.md`
- `references/auxiliary.md`
- `references/establishment.md`
- `references/consolidation.md`
- `references/skills.md`
- `cabal/git-agent-workflow.cabal`

其中两个新增 reference 可能来自尚未提交的工作树, 不应仅根据 GitHub `main` 缺少文件就认定它们不存在.

特别检查:

1. 已提交的英文工作语言规则是否仍然存在.
2. Archive 每次重新获取材料都重新判断归档价值的规则是否仍然存在.
3. Archive 是否已经要求完成有权限的保留决定, 而不是只提出建议.
4. 原有 snapshot、manifest、脱敏副本和不可变性规则是否保持完整.
5. 现有 Auxiliary 生命周期、`branch -d/-D` 和来源恢复规则是否未被破坏.
6. 两个新增 reference 是否已经进入 Cabal `data-files`.

### 验收要求

形成当前文件和待修改章节的简短对应关系.

不得把已有规则当作缺失功能重复实现.

---

## N1. 完善全局持久化与 Archive 规则

**主要文件**:

- `SKILL.md`
- `references/archive.md`

**性质**: 全局规范修改, 不依赖 Auxiliary.

### 3.1.1 全局预防性脱敏

在 `SKILL.md` 的共享约束中明确:

GAW 的所有持久化操作都应在提交前进行必要的内容筛选和脱敏.

适用范围包括:

- Formal Memory.
- Auxiliary Memory.
- Archive snapshots.
- GAW project skills.
- Checkpoint messages.
- 通过 additional parents 新引入或继续保留的 Git 历史.

重点检查实际准备持久化的材料及其可达历史, 而不是为此默认读取所有原始日志.

敏感材料包括但不限于凭证、令牌、个人敏感信息、未经批准的私有内容和不必要的机器环境细节.

优先保留对理解问题有用的技术事实, 而不是原始敏感内容.

如果敏感内容本身并非必要, 不得仅因其存在于原材料中就复制进 GAW.

### 3.1.2 脱敏应在首次持久化前完成

明确:

- 删除后续 checkpoint 中的敏感文件, 不会自动删除旧 Git 对象.
- 在 Formal 关联 Auxiliary 时, 只检查最新 tree 不够.
- 必须考虑相关 additional parent 的祖先闭包及其历史保留后果.
- 对拟新引入的可达历史给予重点审查, 不要求无理由地重复审计整个仓库.
- 如果不能安全保留某段来源历史, 可以只整合经筛选的知识而不关联该来源.

发现未被授权的敏感持久化风险时, 停止受影响的提交或关联, 说明限制并取得必要授权.

不自动开展历史重写或对象清理.

### 3.1.3 收缩 Archive 的默认选择范围

在 `archive.md` 的 `Select material that deserves retention` 中, 将默认方向进一步限定为**范围明确且具有独立历史证据价值的材料**.

优先考虑的典型材料:

- 有重要历史意义的计划和设计文档.
- 被替代但仍有解释价值的技术方案.
- 具有独立复现价值的隔离实验材料.
- 必要的实验输入、方法、关键观察和结果.
- 无法由当前 Memory、测试或项目 Git 历史充分替代的有限证据.

默认不归档:

- 完整会话记录.
- Agent rollout.
- 常规工具调用记录.
- 普通命令日志.
- 大量构建和测试输出.
- 临时工作目录.
- 可以从已有项目历史可靠取得的重复材料.

以上不是绝对禁止列表. 具有特殊独立证据价值的材料可以在明确理由、权限和脱敏边界后例外保留.

但不能因为某份材料属于计划文档或隔离实验, 就自动认定它应当归档.

### 3.1.4 使用最小充分证据

明确 Archive 应尽量选择足以支持预期解释、审计或复现目标的最小材料范围.

例如隔离实验可能只需要:

- 实验条件和方法.
- 必要输入.
- 关键观察或有限输出.
- 验证限制.
- 结果解释所需要的其他材料.

不要求保留完整运行环境和所有原始日志.

对于经脱敏的材料:

- 必须标明其为 sanitized derivative.
- 不得声明其与原始字节完全一致.
- 记录必要的脱敏范围和证据限制.
- 若脱敏破坏关键证据价值, 应重新判断是否值得归档.

### 3.1.5 保留现有 Archive 协议

不得删除或削弱:

- 每次重新获取材料都重新判断归档价值.
- 重新获取或内容变化本身不构成归档理由.
- 有权限时及时完成相应 Memory / Archive 决定.
- Snapshot 的选择、描述、验证和不可变性.
- Source provenance 与 capture context 的区分.
- 已归档材料不自动成为当前 Memory 或 active instructions.
- Archive 仅在确有价值时创建独立快照.

尽量将新规则合并进既有章节, 不新建独立的 Archive 安全 reference.

### N1 验收

必须通过以下语义检查:

1. Formal 与 Auxiliary 适用完全相同的 Archive 选择门槛.
2. 不会因新建 Auxiliary 而默认归档原始来源.
3. 不会因重新获取同一路径的文件而自动归档.
4. 不会因实验材料属于优先类型而跳过独立价值判断.
5. 脱敏在实际持久化之前进行.
6. 不要求保存所有原始资料才能完成脱敏检查.

---

## N2. 恢复 Auxiliary 的多发现线语义

**主要文件**:

- `references/auxiliary.md`

**性质**: 本轮最重要的历史模型修订.

### 3.2.1 明确原始设计动机

在 Auxiliary 的开头明确描述:

Auxiliary histories 用于保存不同发现线的独立知识演化, 特别适合多个 sessions 和 agents 并行、交替或连续推进工作的情形.

这些历史通过普通单源 Establishment 和 Memory maintenance 建立, 不需要 Auxiliary 专用知识标准.

Formal 可以在不同阶段选择性整合各发现线的知识.

应避免将 Auxiliary 描述为仅供最终一次导入的临时资料分支.

### 3.2.2 明确中间 checkpoints 的正常关联

一个 Auxiliary 可以产生:

`A1 -> A2 -> A3`

另一个 Auxiliary 可以产生:

`B1 -> B2 -> B3`

Formal 可以依次形成:

- `F1`: 整合 `A1`.
- `F2`: 整合 `B1`.
- `F3`: 整合 `A2`.
- `F4`: 整合 `A3` 和 `B2`.

这些只是合法组合的示例, 不规定固定提交数量.

Formal first-parent 记录整合知识的推进. Additional parents 记录相关的准确来源状态.

这一流程可以在 Auxiliary 仍然继续发展时进行.

### 3.2.3 不要求只整合最新 tip

明确禁止以下机械假设:

- 每条 Auxiliary 只能整合一次.
- 每条 Auxiliary 只能以最终 tip 关联 Formal.
- 必须等待所有 Auxiliary 完成后才开始整合.
- 已关联最新 tip, 就不需要在较早的 Formal checkpoint 中记录实际使用的中间状态.
- 为了让 Auxiliary 可以删除, 应当把其最新 tip 关联到 Formal.

后一类操作尤其可能导致错误的来源关联或不必要的历史保留.

### 3.2.4 Source checkpoint 选择与 Git ancestry

修改当前 `Integrate selected knowledge into formal GAW` 中的过窄表述:

`Only when that history has independent long-term recovery value ...`

新的原则应同时考虑:

1. 来源 checkpoint 是否确实与本次知识整合有关.
2. 是否有必要在 Formal 的这一历史状态中显式记录来源关联.
3. 来源状态的确切身份及使用依据是否得到支持.
4. Additional parent 引入或继续保留的祖先范围是否可以接受.
5. 敏感内容、Archive 和授权边界是否允许该历史关联.

来源关联的价值可以包括:

- 准确记录 Formal 结论依据的来源状态.
- 保留多条发现线与 Formal 知识演化的关系.
- 支持解释、审计和 provenance 检查.
- 恢复有独立价值的历史知识状态.

不应要求每个 parent 都额外证明一种狭义的长期 recovery value.

同时, 实际阅读或采纳某个来源, 仍不自动要求建立 parent.

### 3.2.5 区分整合顺序与事件时间

Formal 的 first-parent 顺序是**知识被 Formal 采纳和整合的顺序**, 不必等同于所有来源事件在现实时间上的完整排序.

每条 Auxiliary 的内部 first-parent 顺序仍保持自身知识演化关系.

不应为了统一多个来源而伪造原始事件的全序关系.

Retrospective reconstruction 继续遵守现有证据支持、相对顺序和不回填历史提交时间的规则.

### 3.2.6 Auxiliary 可以部分整合并继续工作

以下均属于正常情况:

- Auxiliary 的一部分历史已被 Formal 采用, 但其工作仍在继续.
- 同一 Auxiliary 先后被 Formal 多次关联.
- 某次整合只采用一个中间 checkpoint.
- 后续 Auxiliary 出现修正, Formal 再建立新的知识 checkpoint.
- 部分来源知识没有进入 Formal.
- 只有中间来源状态被关联, 最新 tip 尚未关联.

不需要为这些情况引入新的状态字段或 CLI.

### 3.2.7 删除 Clean Reconstruction 章节

删除新增的:

`## Reconstruct a clean source history`

同时删除相关的默认调用和路由引用.

不再将旧历史清理、脱敏历史替换或重新组织 Git ancestry 描述为一般 Auxiliary 工作流.

但**不得删除**既有 `memory.md` 的 `Reconstruct supported earlier states`.

后者是证据支持的知识历史恢复, 与本次删除的专用历史清理流程不是同一概念.

### 3.2.8 不引入常规 Sanitized Auxiliary Reconstruction

正常要求是在第一次创建 Memory、Archive 和 Auxiliary checkpoints 时就完成筛选和脱敏.

如果历史已经存在敏感内容, 应优先停止不安全的进一步持久化或 Formal 关联, 并在权限范围内决定如何处理.

允许根据已有通用机制进行另行授权的知识建立, 但不在本轮 Skill 中定义特殊的 Sanitized Auxiliary Reconstruction 工作流.

### 3.2.9 简化来源退役及 GC 指导

保留既有生命周期规则:

- `git gaw aux check`.
- `git gaw branch -d`.
- `git gaw branch -D`.
- Worktree 和 selector 约束.
- Retained source recovery.

补充或保留必要说明:

- 知识整合不自动要求退役 Auxiliary.
- 只关联中间 checkpoint, 不代表最新 tip 已被保留.
- `branch -d` 的历史可达性检查不能代替知识整合验收.
- `branch -D` 是明确的放弃行为.
- 删除分支不等于相关 Git 对象立即消失.
- GC 是单独的 Git 仓库维护操作, 不属于常规整合完成步骤.

不扩展为独立 GC 清理流程.

### N2 验收

必须能够解释和正确处理:

- A、B 两条 Auxiliary 交替推进.
- Formal 先整合 A, 再整合 B, 随后再次整合 A.
- 一个 Formal checkpoint 关联多个来源 checkpoints.
- Auxiliary 在部分整合后继续产生新提交.
- 不通过强行关联最新 tip 满足删除条件.
- 整合时对新引入的历史内容进行脱敏边界判断.

---

## N3. 完善 Consolidation 工作流

**主要文件**:

- `references/consolidation.md`

**性质**: 跨来源知识组织与 Formal 历史整合.

### 3.3.1 保留现有有效结构

保留当前新增文件中的基本章节及功能:

- 来源与知识范围盘点.
- 来源重叠、冲突和缺口识别.
- 集中式、分布式、混合式执行.
- Formal 写入协调.
- 分阶段持久化与跨 session 恢复.
- 三种独立保留判断.
- 整合验收.

不需要重新设计一套来源数据库或新的多 agent 协议.

### 3.3.2 强调交错整合

明确 Consolidation 不只是把各条 Auxiliary 的最后状态汇总到 Formal.

它还负责组织不同发现线的阶段性成果, 并在合适的 Formal checkpoints 中保留相关来源关联.

应明确:

- 同一 Auxiliary 的多个 checkpoints 可以先后用于不同 Formal checkpoints.
- 不同 Auxiliary 的 checkpoints 可以交错整合.
- 一个 Formal checkpoint 可以有多个相关 Auxiliary parents.
- 不要求每个来源只能对应一个 Formal checkpoint.
- 不要求每个 Formal checkpoint 只能对应一个来源.
- 不要求所有发现线的时间顺序能够合并成严格全序.
- 阶段性整合不意味着来源工作已经完成.

### 3.3.3 保留三种独立判断

保留现有的三个决策维度:

**Knowledge integration**

选择需要进入 Formal 的结论、理由、问题和证据限制.

**Evidence archival**

按全局 `archive.md` 选择具有独立证据价值的有限材料.

**Git source-history retention**

选择应与 Formal 知识演化形成准确关联的来源 checkpoints, 同时判断由此带来的 Git ancestry 保留后果.

将当前对第三项的表述从狭义的长期 recovery value 改为:

是否具有真实来源关联价值, 是否选中了实际相关的 exact checkpoint, 以及历史保留边界是否合理并得到授权.

### 3.3.4 明确来源关联与知识采纳的关系

保留:

- Git parent 不合并来源 tree.
- Git parent 不代表采纳来源全部主张.
- Git parent 不证明其原始项目 provenance.
- Git parent 不替代 Formal Memory 中的知识说明.
- 不为填补看似不完整的 provenance 而创造猜测性 parent.
- 不使用 GAW checkpoint OID 作为持久语义 ID.

另外应明确:

后续关联较晚的 Auxiliary checkpoint 不能替代较早 Formal checkpoint 中对当时实际使用来源状态的关联.

这是 Formal 知识演化可解释性的要求, 不只是 Git 对象可达性问题.

### 3.3.5 来源历史可以不被保留

如果某个来源历史没有足够的关联价值, 或者存在不合理的持久化风险, 可以只将得到支持的知识整合进 Formal.

此时应确保 Formal 包含足以恢复的:

- 结论.
- 重要推理和理由.
- 验证范围.
- 已知证据限制.
- 必要的来源背景.
- 未决问题.

不应依赖未来可能消失的来源 branch、OID 或文件路径.

删除当前 Consolidation 中对 `clean reconstruction` 章节的调用.

### 3.3.6 控制多 agent 协作边界

保留现有集中式、分布式和混合式设计.

但明确:

- Auxiliary 是一种可选的独立历史机制, 并非必须为每个 agent 创建.
- 各 agent 可以连续处理同一来源范围.
- 同一 agent 也可以处理多个知识范围.
- Formal 写入必须协调, 不能默许并发覆盖.
- 中间结果应在具有独立恢复价值时提交.
- 不要求每次 session 结束生成一个 checkpoint.
- 整合不应成为逐条记录 CLI 操作的流水账.

### 3.3.7 通用化验证表述

将:

`the limits of static versus runtime validation`

修改为:

`the methods, scope and limitations of any validation performed`

这适用于软件、数学研究、文档、实验和其他项目, 不依赖 NixOS 的特定验证模式.

### 3.3.8 整合验收

Consolidation 完成时至少检查:

- Formal 当前知识是否与整合目标一致.
- 重要来源是否已被检查或明确标注缺失.
- 冲突是否解决或作为未决问题保留.
- 验证结论是否与实际证据相符.
- 不同发现线中有价值的知识演化是否得到保留.
- Formal checkpoints 的 source-parent 关联是否准确.
- 已选 additional parents 的祖先保留后果是否经过判断.
- 不保留来源时, Formal 是否仍然自解释.
- 尚未完成的来源工作是否可以继续.
- 下一次 session 能否可靠恢复当前任务.

完成 Consolidation 不意味着所有来源均已关闭, 也不意味着全部历史资料均已归档.

### N3 验收

至少覆盖:

1. 两个来源给出相同结论.
2. 两个来源给出冲突结论.
3. 来源之一的结论被后续修正.
4. 多条 Auxiliary 交错整合.
5. 只整合知识, 不关联来源 Git 历史.
6. 来源在整合中途继续更新.
7. Formal 整合中途被另一 agent 合法更新.
8. 部分材料缺失, 仍可以形成明确受限的整合结果.

---

## N4. 调整 Establishment 与 Memory 边界

**主要文件**:

- `references/establishment.md`
- `references/memory.md`

### 3.4.1 收缩 Establishment 适用条件

Establishment 主要负责:

**在目标 GAW 历史中建立缺失或实质不充分的知识基线.**

典型情况:

- 新建立的 Formal GAW 尚无实质 Memory.
- 已存在 Formal GAW, 但尚未形成可恢复的知识基线.
- 新建 Auxiliary 需要在限定来源范围内建立初始 Memory.
- 某个独立来源工作需要建立可持续维护的知识历史.

不应仅因现有 Formal Memory 发现了早期遗漏材料, 就要求重新执行完整 Establishment.

### 3.4.2 Retrospective reconstruction 继续由 Memory 负责

`memory.md` 中的 `Reconstruct supported earlier states` 仍是以下规则的权威来源:

- 证据 horizon.
- 恢复范围.
- 有独立价值的历史状态选择.
- 相对顺序的证据支持.
- 无法恢复的间隔.
- 不回填原始提交时间.
- 不猜测 exact project parents.
- 不例行重写既有历史.

`establishment.md` 可以引用这些规则, 但不要复制或改写一套新的版本.

已有充分知识基线的 Formal 或 Auxiliary, 对后续发现的早期材料仍按照普通 Memory 工作流处理.

### 3.4.3 来源范围不等于来源数量

保留现有定义:

单源是一项边界明确、内部连贯的知识范围.

它可以跨越多个 sessions、agents、文件和工具.

不得为每个 session 强制建立新的 Auxiliary.

也不得因为资料来自同一 session, 就假定它们必然属于同一个发现线.

### 3.4.4 从首次建立开始脱敏

Establishment 应显式继承 N1 的规则:

- 优先提炼知识.
- 不默认导入完整来源材料.
- 不为了便于以后审计而保存所有原始会话.
- 必要的 Archive 单独按价值判断.
- Auxiliary 初始 checkpoints 同样需要脱敏.
- 不以未来的 Formal 整合为前提降低 Auxiliary 的持久化标准.

### 3.4.5 建立后的持续维护

Establishment 形成充分知识基线后, 应自然进入普通 Memory maintenance.

不要求为每批新材料重新建立 GAW 历史.

当有独立恢复价值的新状态形成时, 按既有 checkpoint 规则提交.

### 3.4.6 GAW 自身重要维护活动

保留此前 `memory.md` 中已增加的原则:

重要的知识建立、整合、修订或维护活动, 如果其理由、结果或下一步会影响未来恢复, 可以纳入 Memory.

但不把每次审阅、归档判断或 CLI 操作都写成维护日志.

### N4 验收

确保:

- Establishment 与普通 Memory maintenance 的适用条件清楚.
- Auxiliary 不需要专门的建立语义.
- 有证据支持的历史恢复能力不因删除 Clean Reconstruction 而削弱.
- 不默认创建 Archive.
- 不引入固定目录和文件名约束.
- 不引入强制的一一对应 checkpoint 规则.

---

## N5. 最终 Routing、打包与回归验收

**主要文件**:

- `SKILL.md`
- `cabal/git-agent-workflow.cabal`
- 所有相关 reference.

### 3.5.1 更新主 Skill 的 Routing

建议保留以下职责分配:

| 工作 | 主要 reference |
| --- | --- |
| 普通 Memory maintenance | `memory.md` |
| 已建立历史中的 retrospective reconstruction | `memory.md` |
| 初始知识基线建立 | `establishment.md` |
| 多来源知识比较及整合 | `consolidation.md` |
| 原始证据选择、归档及验证 | `archive.md` |
| Auxiliary 创建、Git 结构、历史关联和生命周期 | `auxiliary.md` |
| Project skill 的维护 | `skills.md` |

对于 Auxiliary 内部知识建立, 应组合 `establishment.md` 和 `auxiliary.md`.

对于空 Formal 下的多来源建立, 应组合 Establishment 与 Consolidation.

对于已经建立的 Formal, 普通新知识更新不应无条件进入完整 Consolidation 流程.

删除 `SKILL.md` routing 中对 Clean Reconstruction 的引用.

### 3.5.2 控制重复内容

执行跨文件审查:

- 全局脱敏原则以 `SKILL.md` 为主要约束来源.
- Archive 具体选择和验证标准以 `archive.md` 为准.
- Retrospective reconstruction 以 `memory.md` 为准.
- 单源初始知识建立以 `establishment.md` 为准.
- 跨来源整合以 `consolidation.md` 为准.
- Auxiliary 的 Git 生命周期及来源关联以 `auxiliary.md` 为准.

其他文件可以引用这些规则, 不要重新定义或以更窄的条件覆盖它们.

### 3.5.3 保留现有 Archive 协议

确认收缩 Archive 范围没有破坏:

- 现有 snapshot 布局.
- `MANIFEST.md` 和 `files/` 约定.
- Source provenance 与 capture context.
- 原始字节验证.
- Sanitized derivative 的声明.
- Snapshot 不可变性.
- Stable path 引用.
- Archive 不自动成为 instructions.

不要因本轮需求新增 archive-specific refs、对象类型或 manifest 解析器.

### 3.5.4 检查历史关联规则

确认:

- Formal first-parent 的含义未变.
- Auxiliary first-parent 的含义未变.
- 可以选择不同 Auxiliary 的中间 checkpoints.
- Additional parents 可以多于一个, 但各有实际依据.
- 不将 parent 位置赋予新的业务角色.
- 不因 Knowledge integration 自动关联 parent.
- 不因 source tip 已经可达就否定早期关联的历史解释价值.
- 不强制关联最新 tip.
- 祖先保留与敏感内容判断不被忽略.
- 项目 project-parent 的 exact-snapshot 规则继续成立.
- OID 不成为持久语义身份标识.

### 3.5.5 检查语言和文档完整性

新增及修改的 Skill 正文优先使用英文.

保持原有 Markdown reference 组织方式.

检查:

- 链接目标存在.
- 标题锚点正确.
- 新 reference 已纳入 Cabal `data-files`.
- 安装后的 Skill 内部引用仍然可用.
- 不出现失效的 Clean Reconstruction 链接.
- 不包含 NixOS 专用路径或实验参数.
- 不引入强制的额外配置和依赖.

### 3.5.6 执行工程检查

在现有授权和环境范围内执行项目正常使用的检查.

至少包含:

- 检查完整 Git diff.
- 检查新增文件及文件清单.
- 检查 Markdown 引用.
- 检查 Skill 安装产物包含两个新增 reference.
- 执行相关构建、测试和格式化检查.
- 对典型工作流进行语义回归验收.

若构建或测试无法执行, 应明确报告未验证的部分, 不得声称通过.

---

# 4. 专项验收矩阵

本次最终验收至少包含以下场景.

| 场景 | 正确行为 |
| --- | --- |
| 普通单 session 开发 | 直接维护现有 Memory |
| 空 Formal + 单一知识范围 | 使用 Establishment |
| 空 Formal + 多个知识范围 | Establishment + Consolidation |
| 新建 Auxiliary | 采用普通单源建立工作流 |
| 同一发现线跨多个 sessions | 可继续沿用同一 Auxiliary |
| 多个 agents 交替处理发现线 | 保留各自有意义的知识演化 |
| Formal 整合 A1, B1, A2 | 合法的交错整合 |
| Formal 同时采用 A3, B2 | 可使用多个准确 source parents |
| Auxiliary 尚未结束 | 不阻碍阶段性 Formal 整合 |
| 后续发现线修订早期结论 | 保留有意义的知识修订历史 |
| 来源没有值得关联的 Git 状态 | 可以仅整合知识 |
| 来源 tip 含有不宜长期保留的历史 | 不为了便利而关联 tip |
| 只关联 Auxiliary 中间状态 | 不自动认定最新 tip 可安全退役 |
| 来源材料含有敏感信息 | 在首次持久化前筛选及必要脱敏 |
| 已有历史含有敏感内容 | 不认为删除最新 tree 中的内容足以脱敏 |
| 获得计划文档 | 仍需独立归档价值判断 |
| 获得隔离实验结果 | 优先选择最小充分证据 |
| 获得完整 agent rollout | 默认不归档 |
| 再次从相同路径取得材料 | 重新判断保留价值, 不自动归档 |
| 归档材料经脱敏 | 明确标记 derivative 和保真限制 |
| 多来源存在未解决冲突 | 保留为未决问题, 不伪造共识 |
| 验证只覆盖部分情况 | 如实说明方法、范围和限制 |
| Formal 被另一个 agent 更新 | 协调写入, 不静默覆盖 |
| 来源工作完成 | 不自动退役或 GC |

验收应以实际工作流决策是否正确为标准, 不能仅通过检查某句规范是否存在来代替.

---

# 5. 需要删除、保留和新增的内容

## 5.1 应明确删除

1. `auxiliary.md` 新增的 `Reconstruct a clean source history` 整节.
2. `SKILL.md` 中的 Clean Reconstruction routing.
3. `consolidation.md` 中的 Clean Reconstruction 调用.
4. 将 source parent 的价值局限为 `independent long-term recovery value` 的过窄表述.
5. `static versus runtime validation` 这一特定项目倾向的表述.
6. 将历史清理、GC 或脱敏重建描述为常规知识建立步骤的任何措辞.

## 5.2 应保留

1. 两个新增 reference.
2. Formal / Auxiliary 共用普通单源知识规则.
3. 三种独立保留判断.
4. Evidence horizon 和 retrospective reconstruction.
5. 选择性 checkpoint.
6. Exact-snapshot provenance.
7. Formal 当前知识权威性.
8. Source association 不合并 tree、也不自动采纳全部主张.
9. Auxiliary 的现有生命周期和来源恢复机制.
10. Archive 的现有快照及不可变性协议.
11. 每次重新获取材料的独立归档判断.
12. GAW 英文工作语言偏好.

## 5.3 应新增或强化

1. 全局首次持久化前的筛选和脱敏.
2. 全局 Archive 默认范围收缩.
3. 较小的独立证据选择原则.
4. Auxiliary 的多发现线核心动机.
5. Formal 对来源中间 checkpoints 的交错整合.
6. 多次整合同一 Auxiliary 的正常性.
7. Source association 的知识演化及 provenance 价值.
8. Additional-parent 完整祖先闭包的保留判断.
9. Consolidation 的阶段性整合和多 agent 写入协调.
10. 更清楚的 Establishment / Memory 边界.
11. 通用的验证方法、范围与限制.
12. 针对交错整合及脱敏归档的验收场景.

---

# 6. 需要特别避免的实现偏差

### 6.1 不要把 Archive 理解为完整证据备份

Archive 是经过选择的辅助证据载体, 而不是会话、工具输出或全部原始文件的长期副本.

即使具有很高的证据覆盖要求, 也不能直接推导出应保存全部原始材料.

### 6.2 不要把 Auxiliary 理解为一次性导入容器

Auxiliary 的核心价值是独立知识演化及其与 Formal 的阶段性关联.

不能将其生命周期简单概括为创建、记录、最终 tip 整合、删除.

### 6.3 不要把历史可达性等同于历史解释性

关联较晚的 source checkpoint 可能使较早状态可达, 但不能替代 Formal 在较早阶段对真实来源状态的明确关联.

历史可达性和 Formal 知识演化的可解释性是两个不同要求.

### 6.4 不要将 NixOS 经验变成通用操作前提

此前 NixOS 的来源历史清理、脱敏重建、对象清理和具体 Memory 文件布局, 是特定条件下的实践.

这些实践可以说明为什么应当预防性脱敏和审查 ancestry, 但不自动构成新的通用工作流.

### 6.5 不要用删除旧历史代替脱敏

新的 Memory 或 Archive 应在保存前经过适当处理.

如果原始历史已经包含敏感内容, 不能仅删除后续 tree 中的文件, 就声称旧历史安全.

也不能在未授权情况下自动重写或清理旧 Git 历史.

### 6.6 不要因为增加安全检查而禁止有价值的历史关联

Source-parent 关联是 GAW 的重要设计能力.

安全检查应帮助选择正确的 checkpoint 和可接受的历史保留范围, 而不是使所有来源整合退化为没有 parent 的文本摘要.

---

# 7. Agent 执行与交付要求

### 7.1 分阶段实施

按 N0-N5 顺序推进.

每个阶段开始时检查前一阶段实际结果.

如果已有实现与本指导不一致, 先明确冲突, 然后采取局部修订, 不默认全部推倒重写.

### 7.2 保持独立中间状态

允许在具有独立恢复价值的阶段进行提交.

如果某次中间提交尚未完成整套工作流集成, 应在提交说明和必要的项目记忆中清楚标明其范围.

不应把未完成的后续阶段说成已经验收通过.

### 7.3 遵守现有工作流

修改 Skill 内容时, 遵循已有项目维护及 Git 工作流.

涉及 GAW 工作区时, 使用公共 GAW 命令进行验证和 checkpoint.

不通过手工修改 refs、绕过 hooks 或直接重写历史来实现文档调整.

### 7.4 最终交付报告

修改完成后提供:

1. 修改文件及新增文件清单.
2. 删除的专用或过强规则.
3. 新增的全局脱敏与 Archive 选择规则.
4. Auxiliary 多发现线交错整合的具体语义.
5. Source-parent 选择规则的变化.
6. Establishment / Consolidation / Memory 的最终职责边界.
7. 已执行的检查及结果.
8. 未执行的检查和剩余限制.
9. 是否发现需要额外设计决策的问题.

如果实现中发现必须修改 CLI 或 Git 协议才能满足某项要求, 不要自动扩展范围, 应单独说明必要性与替代方案.

---

# 8. 最终完成标准

本轮 Skill 更新应最终满足:

- GAW 以知识持久化为核心, 不以原始会话备份为中心.
- Formal 和 Auxiliary 采用统一的单源知识工作流.
- Establishment 负责缺失知识基线的建立.
- Memory 负责普通维护和已有规则支持的历史恢复.
- Consolidation 支持不同发现线的持续、交错和阶段性整合.
- Formal 可以选择性关联不同 Auxiliary 的中间 checkpoints.
- 不默认等待 Auxiliary 完成或只关联最后 tip.
- Knowledge integration、Archive 和 Git source-history retention 独立判断.
- Source parents 同时满足真实关联意义和可接受的祖先保留边界.
- 脱敏优先发生在首次持久化之前.
- Archive 全局优先保留范围有限且具有独立证据价值的材料.
- 不默认归档完整会话、rollout 和普通日志.
- 不引入 Clean Reconstruction 或 Sanitized Auxiliary Reconstruction 常规工作流.
- 不引入不必要的 GC、历史重写或来源管理机制.
- 不修改现有 Git 协议及 CLI.
- 新增和既有 references 在职责、链接、打包和语义上保持一致.
- 典型回归场景通过, 验证限制得到如实报告.

**本轮工作的核心目标是使 Auxiliary 的多发现线历史模型真正服务于 Formal 的知识演化, 同时确保所有 GAW 持久化行为从一开始就遵守知识优先、选择性归档和必要脱敏的原则.**
