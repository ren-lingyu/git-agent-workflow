# GAW Archive 语义规范化

**类型：开发指导**

**状态：设计决策已确定，待实施**

**范围：GAW bundled skill、项目级 archive skill 及相关说明**

## 1. 设计决策

正式采用现有的 `MANIFEST.md + files/` 结构，作为 GAW archive 保存历史材料的默认约定。

不再将其视为过渡方案，也不将替换为 Data Package、RO-Crate 或 BagIt 作为既定开发目标。

本次决策依据：

- GAW archive 主要保存少量、经过选择的历史材料。
- 归档的主要使用方式是创建一次、长期保存、按需读取。
- Agent 和人类 reviewer 负责判断归档内容及说明是否充分。
- Git / GAW 已负责归档的持久化、版本记录和项目历史关联。
- 当前 Markdown manifest 已能有效承载历史背景、逐文件说明和必要的来源信息。
- 现有标准工具尚未证明能够以足够小的成本明显改善该工作流。

采用现有格式，不意味着声明它是独立发布的通用归档标准。

它是一个由 GAW skill 定义、通过 Git 保存的轻量归档约定。

### 1.1 不引入新的实现

本轮不开发：

- GAW archive CLI。
- 专用 Markdown manifest 解析器。
- Manifest schema 或验证器。
- Data Package / RO-Crate 兼容层。
- 新的文件索引或数据库。
- 自动打包、压缩或发布系统。
- 自动归档选择器。

优先复用普通文件操作、字节比较、Git 和已有 GAW 命令。

## 2. Archive 的职责

### 2.1 基本定义

GAW archive 负责保存**已经选定的历史材料及理解这些材料所需的描述**。

典型材料包括：

- 尚未进入普通项目 Git 历史的实验输入与输出。
- 临时程序、诊断日志和验证结果。
- 退役但仍具有历史价值的文档。
- 支撑重要设计决策或迁移过程的原始材料。

Archive 不是普通项目的构建产物仓库，也不是当前 memory 的替代品。

已归档内容不会自动成为当前权威知识或生效的 agent instructions。

### 2.2 责任划分

| 事项 | 责任方 |
|---|---|
| 选择归档材料 | Agent / reviewer |
| 判断材料是否充分 | Agent / reviewer |
| 确定文件角色及历史解释 | Agent / reviewer |
| 正确复制选定文件 | 归档操作 |
| 描述保存内容 | `MANIFEST.md` |
| 验证复制保真性 | 文件比较操作 |
| 持久保存及版本记录 | Git / GAW |
| 记录相关项目快照 | GAW commit graph |

GAW archive 不负责证明文件来源声明的真实性，也不负责判断是否遗漏了应归档的源文件。

归档工作流应准确记录已知信息及不确定性，而不是制造无法支持的 provenance 断言。

## 3. 归档快照模型

### 3.1 每次归档创建独立快照

每次归档操作创建一个新的 snapshot，即使只归档一个文件。

默认结构：

```text
archive/
├── README.md
├── <snapshot-A>/
│   ├── MANIFEST.md
│   └── files/
│       └── <source-relative-path>
└── <snapshot-B>/
    ├── MANIFEST.md
    └── files/
        ├── ...
        └── ...
```

其中：

- `archive/` 是声明的 GAW archive workspace，而不是强制的全局目录名称。
- `README.md` 是可选的 workspace 说明文件。
- 每个 snapshot 都具有独立的 `MANIFEST.md`。
- `files/` 保存该 snapshot 已选择的原始材料。
- 不将新增材料直接附加到旧 snapshot。
- 单文件与多文件归档使用相同模型。

独立 snapshot 是工作流语义，不意味着每个 snapshot 必须对应不同的 project commit。

### 3.2 Snapshot 命名

默认建议沿用已经实际使用的约定：

```text
YYYY-MM-DDTHH-MM-SSZ--CCCCCCC
```

其中：

- 时间戳采用 UTC。
- `CCCCCCC` 是已确认捕获时项目 HEAD 的缩写。
- 完整 project OID 如有必要，可记入 manifest。
- 若没有相关的单一项目 HEAD，使用不暗示虚假项目来源的名称。

命名必须稳定、可辨识且无冲突。

时间戳加项目 OID 的形式是推荐命名约定，不是 GAW Git 协议要求。

不应为了满足命名格式而伪造项目来源。

### 3.3 Snapshot 不可变性

**一旦 snapshot 被正式 checkpoint，就不再修改其内容。**

包括：

- 不覆盖已有文件。
- 不向旧 snapshot 添加文件。
- 不删除旧 snapshot 中的文件。
- 不原地修改 `MANIFEST.md`。
- 不为适配未来格式而重写历史 snapshot。

需要保存新的材料版本或替代性描述时，应创建新 snapshot，必要时在 manifest 中引用旧 snapshot。

如果只是更正后续 agent 对历史材料的认识，也可以在当前 memory 中记录更正，而不修改原始归档。

这是一项 skill 层面的工作流约定，不要求 CLI 增加新的不可变性保护机制。

## 4. `files/` 的语义

### 4.1 保存内容

`files/` 保存实际选定的文件。

对于原始材料，默认要求：

- 按字节复制。
- 保留必要的源相对路径。
- 不自动重编码、格式化或规范化换行。
- 不为了组织文本而创建 tar/ZIP 等额外容器。
- 不自动执行归档中的程序或脚本。

归档中保存了 `.el`、`.scm` 或其他可执行内容，并不代表这些内容获得执行授权。

### 4.2 路径

对于普通项目内的文件，优先采用相对项目 worktree 根目录的路径：

```text
files/tmp/example/probe.el
```

Manifest 必须说明该相对路径使用的来源根。

来自不同项目、外部目录或其他归档的材料，需要分别说明来源和路径含义。

不应通过静默改名或扁平化目录结构解决路径冲突。

如果确实需要调整保存路径，应在 manifest 中明确记录原始路径与归档路径的对应关系。

### 4.3 安全与权限

捕获前检查：

- 文件类型与大小。
- 文件路径及其祖先目录。
- 符号链接。
- 读取权限和授权范围。
- 敏感信息。
- 二进制及大型文件的 Git 保存成本。

不得因为归档需要而自动扩大文件读取范围。

对必须脱敏的材料，应明确标记为经过转换的派生文件，不能声称与原始文件字节完全一致。

## 5. `MANIFEST.md` 的语义

### 5.1 Manifest 是描述，不是协议元数据

`MANIFEST.md` 是每个 snapshot 的人类与 agent 可读描述文件。

它的职责是让后续使用者能够理解：

- 这份 snapshot 保存了什么。
- 为什么保存。
- 文件来自哪里。
- 各文件具有什么作用。
- 保存时有哪些已知限制。

Manifest 不是 GAW CLI 需要解析的协议文件。

因此，不规定专用 Markdown AST、固定的表格列序或机器验证 schema。

但每份 manifest 都应覆盖下述必要语义。

### 5.2 必要内容

**归档身份与目的**

- 简明标题。
- 归档时间。
- 保存目的。
- 实际选择范围。

**材料清单**

对每个保存的文件，明确记录：

- 原始来源路径或其他适当的来源标识。
- 实际归档路径。
- 文件在本次归档中的作用。

**历史背景**

- 已知的来源状态。
- 必要的实验或工作背景。
- 与当前项目状态有关的重要区别。
- 有助于后续解释的限制或不确定性。

**历史材料地位**

说明该 snapshot 是历史材料，不自动代表当前有效的项目状态、事实结论或 agent instructions。

### 5.3 可选内容

按需要记录：

- tracked / modified / untracked 状态。
- 字节数。
- SHA-256 等内容摘要。
- 文件格式。
- 程序执行方式。
- 实验环境。
- 已知文件关系。
- 其他有意义的项目快照 OID。
- 被取代的历史 snapshot。

不要求所有归档都包含所有可选字段。

特别是，不将 SHA-256 设为通用必填字段。它可以用于复制复核或独立引用，但不替代 Git 的内容完整性机制。

### 5.4 来源信息的精确含义

必须区分：

1. **Original provenance**：材料最初的来源。
2. **Capture context**：归档时实际检查或使用的项目状态。
3. **Archived content**：本次真正保存的文件字节。

例如，某个 ignored `tmp/` 文件在项目 HEAD `X` 下被复制，不意味着该文件是 HEAD `X` 中的 tracked blob，也不意味着它最初由 `X` 产生。

Manifest 可以记录：

> 文件在项目 HEAD X 的工作环境中被捕获，最初创建时间未确认。

不能直接写成：

> 文件来自项目 commit X。

除非这一来源关系另有可靠依据。

### 5.5 推荐模板

Manifest 不要求使用固定语法，但以下结构可以作为默认写法：

```markdown
# <Snapshot title>

Historical evidence; not authoritative current memory.

## Context

- Captured at: <UTC time>
- Project: <project identity>
- Capture context: <known project state, if relevant>
- Purpose: <why these files were retained>
- Selection: <which files were selected>

## Files

| Source | Archived path | Role |
| --- | --- | --- |
| tmp/probe.el | files/tmp/probe.el | Experiment runner |
| tmp/probe.txt | files/tmp/probe.txt | Observed output |

## Provenance and limitations

<Original source details, known uncertainty,
experimental limits, and other relevant context.>
```

该模板仅统一必要语义，不强制 Markdown 标题、列名和排列方式完全一致。

## 6. 捕获与验证流程

### 6.1 捕获前

Agent 应当：

1. 确认已经部署并可使用的 GAW worktree。
2. 通过 `.gaw/config` 确认相应 archive workspace。
3. 确定已获授权的源文件集合。
4. 检查文件类型、大小和路径边界。
5. 确认新的 snapshot 目录不存在。
6. 记录本次实际需要的捕获上下文。

不要求 GAW 自动审查选材是否充分。

### 6.2 捕获

使用普通文件操作将选定内容复制至新的 snapshot。

保留文件原始字节和必要的路径结构。

捕获期间不得静默修改源文件。

对于需要确保稳定状态的材料，应保存并复核源文件状态，必要时比较捕获前后的内容。

不依赖于仅比较文件名、大小或修改时间来断言内容完全相同。

### 6.3 验证

至少验证：

- 每个已选定文件都有预期的归档副本。
- 原始材料与副本字节一致。
- `MANIFEST.md` 的文件清单对应实际保存内容。
- 记录的文件属性没有已知错误。
- 相关捕获上下文没有在操作期间出现未解决的不一致。
- 没有误包含未授权或无关文件。

如果记录了 byte count 或 checksum，应检查其正确性。

这属于归档操作的验证，不需要新建专用 manifest validator。

### 6.4 失败处理

复制、验证或描述过程中出现失败时：

- 不将不完整结果作为成功的 snapshot 提交。
- 不覆盖已有 snapshot。
- 不静默改变文件选择范围。
- 明确报告已经生成的部分材料。
- 仅在获得必要授权后清理、重建或继续操作。

不要求本轮开发事务性文件系统发布器。

默认采取 fail-closed 的操作策略。

## 7. 与 GAW 历史的关系

### 7.1 Git 保存归档状态

Snapshot 和 `MANIFEST.md` 作为 GAW workspace 内容，由正常 Git 对象保存。

每个 checkpoint 的 first-parent history 记录归档何时进入 GAW 历史。

不增加专用 archive refs、Git notes 或新的对象类型。

### 7.2 Project parents

额外 project parents 根据实际证据独立选择。

归档发生时记录的项目 HEAD 可以作为已检查的 capture context，但它不必然是每个文件的 original provenance。

一般规则仍然是：

- 没有可靠项目关联时，可以不提供 project parent。
- 存在一个可靠项目快照时，可以提供一个。
- 有多个独立且充分支持的关联时，可以提供多个。

不为了归档而强制指定恰好一个 project parent。

不根据归档目录名自动推断 project-parent 关联。

### 7.3 Checkpoint 组织

默认建议将新 snapshot 独立 checkpoint，以便清楚追踪引入时间、文件范围及相关项目状态。

项目级 skill 可以进一步要求 archive-only checkpoint。

通用 GAW skill 不需要禁止一次语义自洽的 checkpoint 同时包含 archive 和其他声明 workspace 中的变更。

无论如何，都必须：

- 审查完整 GAW index。
- 显式 stage 预期文件。
- 运行 `git gaw check`。
- 使用 `git gaw commit`。
- 根据需要检查最终 GAW checkpoint。

必须遵守现有 `.gaw/` 协议路径与普通 workspace 路径的提交分离规则。

### 7.4 稳定引用

Memory 或其他文档引用 archive 时，应优先使用：

```text
archive/<snapshot>/MANIFEST.md
```

或者 snapshot 中某个明确的文件路径。

不把 GAW checkpoint OID 当成持久的归档语义标识。

需要确定引入归档的 checkpoint 时，通过对应路径的 first-parent history 查找。

Manifest 不能预先记录包含自己的 GAW checkpoint OID；也不应在提交后通过修改 snapshot 回填。

## 8. 现有历史兼容性

本次规范化仅约束后续归档操作。

已经提交的快照保持不变。

不要求：

- 修改历史 `MANIFEST.md`。
- 补充新字段。
- 移动目录。
- 重新计算 checksum。
- 重写 GAW checkpoint。
- 将旧归档转换成其他格式。

旧的归档内容按其所在历史快照当时的语义解释。

如果今后重新引入外部标准，也必须保持这一历史兼容原则。

## 9. 通用 Skill 修改

主要修改：

```text
cabal/share/skills/git-agent-workflow/references/archive.md
```

### 9.1 修改方向

保留已有的：

- 材料选择与授权边界。
- 原始字节保真。
- 来源与捕获上下文的区别。
- Git checkpoint 和 project-parent 规则。
- 稳定路径引用。
- 归档内容不自动恢复为当前指令的原则。

将原来的可选格式描述提升为正式默认：

```text
<snapshot>/
├── MANIFEST.md
└── files/
```

并增加：

- 单文件与多文件统一使用独立快照。
- 已提交快照不可原地修改。
- Manifest 的必要语义。
- 捕获和验证的最低要求。
- 不需要外部元信息工具。
- 不新增 CLI 或格式解析义务。

### 9.2 通用性边界

这仍然是 bundled skill 的默认工作流，而不是 GAW CLI 协议的一部分。

允许已经有充分理由的项目级归档流程作出明确约定，但不应默默违反通用工作流的保真性、权限和历史解释要求。

不把 `archive/`、UTC 命名、固定 project-parent 个数或单独 checkpoint 类型变成 `.gaw/config` 的新语义。

如通用 `SKILL.md` 的现有路由已足够，无需修改其主体。

## 10. GAW 项目级 Skill 修改

修改 `_agents` 分支中的：

```text
skills/git-agent-workflow-gaw-archive/SKILL.md
archive/README.md
```

### 10.1 去掉过渡性表述

删除或重写：

- `interim`
- `until formal metadata tooling is adopted`
- 把 Data Package / RO-Crate 描述为等待采用的新默认格式的措辞。

明确该项目已正式采用 `MANIFEST.md + files/`。

### 10.2 保留有效的项目级约定

当前项目级 skill 的以下约定可以继续保留：

- `archive/YYYY-MM-DDTHH-MM-SSZ--CCCCCCC/` 命名。
- 捕获时记录完整项目 HEAD。
- Manifest 保存 tracked 状态、字节数、SHA-256。
- 对源文件和归档副本进行字节验证。
- 每个新归档单独形成 archive-only checkpoint。
- 不覆盖、追加或修改既有 snapshot。
- 通过 manifest 路径和 first-parent history 追踪归档。

其中，强制 SHA-256、特定命名和 archive-only checkpoint 应保留为该项目的本地约定，而不是自动成为所有 GAW 项目的协议规则。

### 10.3 同步技术选型结论

在 `memory/current.md` 中简洁记录：

- 当前正式采用 `MANIFEST.md + files/`。
- 不再将 Data Package 或 RO-Crate 集成视为当前任务。
- 原有比较实验已经保存在历史 archive。
- 只有出现明确的新需求时，才重新评估标准工具。

避免将完整测试报告复制进 current memory。

现有实验报告和原始输出继续保留在：

```text
archive/2026-10-10T07-07-01Z--d6c675a/
```

不修改历史记录，也不将过去的有条件推荐改写为当时就已经选择了 Markdown。

## 11. 提交与实施顺序

建议分成两个独立层次。

### 第一阶段：通用 Skill

在普通 `main` 开发流程中修改：

```text
cabal/share/skills/git-agent-workflow/references/archive.md
```

建议提交主题：

```text
docs(skill): standardize archive snapshot workflow
```

检查：

- 归档语义与根 `SKILL.md` 一致。
- 不引入新的 Git 协议约束。
- 与现有 memory / skills 指导没有冲突。
- 没有错误地提升项目级限制。
- 资源分发仍然有效。

该文件已经属于现有 bundled resources，若没有新增文件，一般不需要修改 Cabal `data-files`。

### 第二阶段：GAW 自身 `_agents` 实践

在已部署的 GAW worktree 中，更新项目级 archive skill、overview 和 current memory。

遵循现有 GAW 维护权限及 checkpoint 工作流。

建议把实质性 skill/overview 约定更新与随后需要的 current-memory 整理分开审查；是否分别 checkpoint，以完整候选状态的语义自洽性为准。

不修改普通项目代码、lockfile 或 GAW 协议。

### 后续：其他项目的 Workflows Transplantation

通用 skill 修改真正发布并在相应 agent 环境中可用后，再评估 org-texmacs 等项目的 archive skill 是否需要同步。

移植应保留项目实际使用的完整操作指导，不进行机械去重。

本次不直接修改其他项目。

## 12. 验收标准

本轮完成后，应当满足：

1. 通用 GAW archive skill 明确采用独立 snapshot、`MANIFEST.md` 和 `files/` 作为默认工作流。
2. 单文件与多文件归档具有一致的组织模型。
3. Manifest 的必要信息清楚，但没有发展为专用数据格式或解析协议。
4. 原始文件的字节保真、来源区分和安全要求保留。
5. 归档 checkpoint 与项目来源的关系不会被误解。
6. 已提交的 snapshot 不再作为普通可变文档维护。
7. GAW 项目级 skill 和 README 不再使用过渡格式定位。
8. 历史实验报告继续可引用、可恢复。
9. 不增加 GAW CLI、第三方归档工具依赖或自定义 validator。
10. 现有 GAW 历史、配置及 Git 协议保持不变。

## 13. 后续重新评估条件

只有出现明确的操作需求时，才重新评估外部标准，例如：

- 需要非 Agent 程序批量读取文件角色和来源信息。
- 大量 archive 需要统一查询和索引。
- 需要跨工具交换结构化归档元数据。
- 文件间关系已经复杂到 Markdown 难以可靠维护。
- 有新的成熟工具能直接、明显地改善归档创建和读取流程。

重新评估不是既定 TODO，不要求持续追踪某个标准或工具的版本。

若未来确实决定引入外部格式，应将其作为一次独立的工作流变更，而不是认定今天保存的 Markdown 归档需要追溯修复。

---

## 最终原则

**GAW archive 负责可靠保存已选定的历史材料，使其在未来仍然可以被理解和引用。**

- Agent / reviewer 负责内容选择与解释。
- `MANIFEST.md` 负责归档的自我描述。
- `files/` 负责保存选定材料。
- 普通文件工具负责捕获与保真检查。
- Git / GAW 负责历史持久化与项目快照关联。

只要这一组合能满足实际需求，就不额外引入格式系统或归档管理层。

**优先维持简单、明确、可恢复的工作流，而不是为了标准化而增加实现复杂度。**
