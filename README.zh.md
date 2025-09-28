# Auto Task - 自动化任务执行器

## 项目简介

Auto Task 是一个基于文件的任务自动化系统，通过扫描 Markdown 文件并调用 AI CLI 工具（如 Claude）来自动执行任务。

## 核心功能

- **文件驱动**: 将任务定义为 Markdown 文件，文件内容即为任务描述
- **智能状态管理**: 自动跟踪任务状态（待处理 → 执行中 → 已完成/阻塞）
- **多 AI 支持**: 支持 Claude、Codex、Gemini、Qwen 等多种 AI CLI
- **完整日志记录**: 记录每个任务的完整执行过程和结果

## 目录结构

```text
auto_task/
├── auto_task.sh           # 主执行脚本
├── .env                   # 环境配置文件
├── tasks/                 # 任务目录
│   ├── 自媒体/            # 按类别组织任务
│   └── ++任务名.md        # 任务文件（以 ++ 开头）
└── __run_results/         # 执行结果（自动生成）
    ├── outputs/           # AI 输出文件
    └── logs/              # 执行日志
```

## 任务文件命名规则

- **待处理**: `++任务名.md`
- **执行中**: `++任务名.doing.md`
- **已完成**: `++任务名.done.md`
- **被阻塞**: `++任务名.blocked.md`

## 使用方法

### 1. 配置环境

```bash
# 复制并编辑配置文件
cp .env.example .env

# Make the script executable
chmod +x auto_task.sh
```

在 `.env` 中设置:

```bash
AI_CLI=claude                    # 指定 AI CLI 工具
AI_BACKENDS="claude codex gemini qwen"  # 可用的 AI 工具列表
```

### 2. 创建任务

在 `tasks/` 目录下创建以 `++` 开头的 Markdown 文件:

```markdown
<!-- ++新功能开发.md -->

请帮我实现一个用户登录功能，包括:

1. 用户注册
2. 登录验证
3. 密码重置
4. 会话管理

技术栈: React + Node.js + MongoDB
```

### 3. 执行任务

```bash
./auto_task.sh
```

脚本会:

1. 扫描所有 `++*.md` 文件
2. 将文件内容作为提示词传给 AI CLI
3. 自动更新文件状态和保存结果

## 配置选项

| 变量                    | 默认值          | 说明                   |
| ----------------------- | --------------- | ---------------------- |
| `AI_CLI`                | -               | 指定使用的 AI CLI 工具 |
| `TASK_INCLUDE_PREFIX`   | `++`            | 任务文件前缀           |
| `RESULTS_DIR`           | `__run_results` | 结果输出目录           |
| `STATUS_SUFFIX_DOING`   | `.doing.md`     | 执行中后缀             |
| `STATUS_SUFFIX_DONE`    | `.done.md`      | 已完成后缀             |
| `STATUS_SUFFIX_BLOCKED` | `.blocked.md`   | 阻塞后缀               |

## 执行流程

1. **扫描**: 递归扫描 `tasks/` 目录下的所有 `++*.md` 文件
2. **状态管理**: 将 `++任务.md` 重命名为 `++任务.doing.md`（避免重复执行）
3. **AI 执行**: 调用 AI CLI 处理任务内容
4. **结果保存**:
   - 成功: 重命名为 `.done.md`，保存输出到 `__run_results/outputs/`
   - 失败: 重命名为 `.blocked.md`
5. **日志记录**: 完整的执行日志保存到 `__run_results/logs/`

## 特性

- ✅ **零配置**: 自动发现可用的 AI CLI 工具
- ✅ **并发安全**: 通过文件重命名防止重复执行
- ✅ **容错处理**: 失败任务自动标记为阻塞状态
- ✅ **完整日志**: 记录 AI 执行的完整过程
- ✅ **目录组织**: 支持多级目录组织任务
- ✅ **跨平台**: 兼容 macOS、Linux 和 Windows

## 注意事项

- 任务文件必须以 `++` 开头才会被处理
- `.done.md` 和 `.blocked.md` 文件会被跳过
- `archive/`、`-*`、`!*`、`__*` 目录会被忽略
- 建议将敏感信息放在 `.env` 文件中，不要提交到版本控制

## 示例

```bash
# 创建一个简单任务
echo "帮我写一个 Python 的 Hello World 程序" > tasks/++hello-world.md

# 执行任务
./auto_task.sh

# 查看结果
cat __run_results/outputs/__hello-world.out.md
cat __run_results/logs/20231201-143022_hello-world.log
```

---

**提示**: 这个工具特别适合批量处理编程任务、文档生成、代码审查等需要 AI 辅助的重复性工作。
