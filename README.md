# Auto Task - Automated Task Executor

[中文版](README.zh.md)

## Overview

Auto Task is a file-based task automation system that scans Markdown files and automatically executes tasks by calling AI CLI tools (such as Claude).

## Core Features

- **File-Driven**: Define tasks as Markdown files, with file content serving as task descriptions
- **Smart State Management**: Automatically track task states (pending → processing → completed/blocked)
- **Multi-AI Support**: Support Claude, Codex, Gemini, Qwen and other AI CLI tools
- **Complete Logging**: Record the complete execution process and results of each task

## Directory Structure

```text
auto_task/
├── auto_task.sh           # Main execution script
├── .env                   # Environment configuration file
├── tasks/                 # Task directory
│   ├── projects/          # Organize tasks by category
│   └── ++task-name.md     # Task files (prefixed with ++)
└── __run_results/         # Execution results (auto-generated)
    ├── outputs/           # AI output files
    └── logs/              # Execution logs
```

## Task File Naming Rules

- **Pending**: `++task-name.md`
- **Processing**: `++task-name.doing.md`
- **Completed**: `++task-name.done.md`
- **Blocked**: `++task-name.blocked.md`

## Usage

### 1. Environment Setup

```bash
# Copy and edit configuration file
cp .env.example .env

# Make the script executable
chmod +x auto_task.sh
```

Configure in `.env`:

```bash
AI_CLI=claude                         # Specify AI CLI tool
AI_BACKENDS="claude codex gemini qwen"  # Available AI tool list
```

### 2. Create Tasks

Create Markdown files prefixed with `++` in the `tasks/` directory:

```markdown
<!-- ++feature-development.md -->
Please help me implement a user authentication system including:
1. User registration
2. Login validation
3. Password reset
4. Session management

Tech stack: React + Node.js + MongoDB
```

### 3. Execute Tasks

```bash
./auto_task.sh
```

The script will:

1. Scan all `++*.md` files
2. Pass file content as prompts to AI CLI
3. Automatically update file status and save results

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `AI_CLI` | - | Specify AI CLI tool to use |
| `TASK_INCLUDE_PREFIX` | `++` | Task file prefix |
| `RESULTS_DIR` | `__run_results` | Results output directory |
| `STATUS_SUFFIX_DOING` | `.doing.md` | Processing suffix |
| `STATUS_SUFFIX_DONE` | `.done.md` | Completed suffix |
| `STATUS_SUFFIX_BLOCKED` | `.blocked.md` | Blocked suffix |

## Execution Flow

1. **Scan**: Recursively scan all `++*.md` files in `tasks/` directory
2. **State Management**: Rename `++task.md` to `++task.doing.md` (prevent duplicate execution)
3. **AI Execution**: Call AI CLI to process task content
4. **Save Results**:
   - Success: Rename to `.done.md`, save output to `__run_results/outputs/`
   - Failure: Rename to `.blocked.md`
5. **Logging**: Complete execution logs saved to `__run_results/logs/`

## Features

- ✅ **Zero Configuration**: Automatically discover available AI CLI tools
- ✅ **Concurrency Safe**: Prevent duplicate execution through file renaming
- ✅ **Error Handling**: Failed tasks automatically marked as blocked
- ✅ **Complete Logging**: Record full AI execution process
- ✅ **Directory Organization**: Support multi-level directory organization
- ✅ **Cross-Platform**: Compatible with macOS, Linux and Windows

## Notes

- Task files must be prefixed with `++` to be processed
- `.done.md` and `.blocked.md` files will be skipped
- `archive/`, `-*`, `!*`, `__*` directories are ignored
- Recommended to put sensitive information in `.env` file, do not commit to version control

## Example

```bash
# Create a simple task
echo "Help me write a Python Hello World program" > tasks/++hello-world.md

# Execute tasks
./auto_task.sh

# View results
cat __run_results/outputs/__hello-world.out.md
cat __run_results/logs/20231201-143022_hello-world.log
```

## Use Cases

This tool is particularly suitable for:

- **Batch Programming Tasks**: Code generation, refactoring, bug fixes
- **Documentation Generation**: API docs, user guides, technical specs
- **Code Review**: Automated code analysis and suggestions
- **Content Creation**: Blog posts, tutorials, documentation
- **Data Processing**: Text analysis, format conversion, data validation

---

**Tip**: This tool is especially suitable for batch processing programming tasks, document generation, code reviews and other repetitive work that requires AI assistance.