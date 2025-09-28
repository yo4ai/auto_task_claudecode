#!/bin/sh
# 扫描 ./tasks/**.md（多级），按前缀/后缀规则执行"任务＝文件"
# 执行 = 把该 MD 内容作为 -p 传给 AI_CLI；成功→.done，失败→.blocked
set -eu
( set -o | grep -q pipefail ) 2>/dev/null && set -o pipefail

# —— 目录定位 ——
SCRIPT="$0"
ROOT_DIR="$(cd "$(dirname "$SCRIPT")" && pwd -P)"
TASKS_DIR="$ROOT_DIR/tasks"
ENV_FILE="$ROOT_DIR/.env"

# —— 载入 .env（可选）——
if [ -f "$ENV_FILE" ]; then
  # 导出 .env 中的 KEY=VALUE
  set -a
  . "$ENV_FILE"
  set +a
fi

# —— 默认值 ——
AI_CLI="${AI_CLI:-}"
AI_BACKENDS="${AI_BACKENDS:-claude codex gemini qwen}"

TASK_INCLUDE_PREFIX="${TASK_INCLUDE_PREFIX:-++}"
ARCHIVE_DIR="${ARCHIVE_DIR:-archive}"

STATUS_SUFFIX_DOING="${STATUS_SUFFIX_DOING:-.doing.md}"
STATUS_SUFFIX_DONE="${STATUS_SUFFIX_DONE:-.done.md}"
STATUS_SUFFIX_BLOCKED="${STATUS_SUFFIX_BLOCKED:-.blocked.md}"

# 统一的运行结果目录（从 tasks 目录外面）
RESULTS_DIR="${RESULTS_DIR:-__run_results}"
OUTPUTS_SUBDIR="${OUTPUTS_SUBDIR:-outputs}"
LOGS_SUBDIR="${LOGS_SUBDIR:-logs}"

# 输出和日志目录都放在统一的结果目录下
RESULTS_ROOT="$ROOT_DIR/$RESULTS_DIR"
OUT_DIR="$RESULTS_ROOT/$OUTPUTS_SUBDIR"
LOG_DIR="$RESULTS_ROOT/$LOGS_SUBDIR"

# —— Claude 参数配置 ——
CLAUDE_ARGS=(
    -p
    --permission-mode bypassPermissions
    --dangerously-skip-permissions
    # --verbose
)

# —— PATH 常见位（含 Homebrew）——
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.bun/bin:$HOME/.asdf/shims:$PATH"
export PATH

# —— 准备目录 ——
mkdir -p "$TASKS_DIR" "$RESULTS_ROOT" "$OUT_DIR" "$LOG_DIR"

# —— 自动探测 CLI（若未在 .env 指定）——
find_cli() {
  if [ -n "$AI_CLI" ] && command -v "$AI_CLI" >/dev/null 2>&1; then
    command -v "$AI_CLI"; return 0
  fi
  # 常见路径 & PATH 上
  for name in $AI_BACKENDS; do
    if command -v "$name" >/dev/null 2>&1; then echo "$(command -v "$name")"; return 0; fi
    for cand in "/opt/homebrew/bin/$name" "/usr/local/bin/$name"; do
      [ -x "$cand" ] && { echo "$cand"; return 0; }
    done
  done
  return 1
}

CLI="$(find_cli || true)"
if [ -z "$CLI" ]; then
  printf '%s\n' "$(date -u '+%F %T UTC') ERROR: 未找到可用的 AI CLI。请在 .env 设置 AI_CLI 或安装（claude/codex/gemini/qwen）。" >> "$LOG_DIR/run.log"
  exit 1
fi

# —— 辅助：去除状态后缀（得到"根路径"）——
strip_status_path() {
  f="$1"
  case "$f" in
    *"$STATUS_SUFFIX_DOING") printf '%s' "${f%$STATUS_SUFFIX_DOING}" ;;
    *"$STATUS_SUFFIX_DONE")  printf '%s' "${f%$STATUS_SUFFIX_DONE}"  ;;
    *"$STATUS_SUFFIX_BLOCKED") printf '%s' "${f%$STATUS_SUFFIX_BLOCKED}" ;;
    *.md) printf '%s' "${f%.md}" ;;
    *) printf '%s' "$f" ;;
  esac
}

# —— 递归遍历（排除忽略目录）——
# 忽略：archive/**、以及以 -, !, __ 开头的整个目录
# 只处理：文件名以 TASK_INCLUDE_PREFIX 开头，且不是 .done/.blocked
find "$TASKS_DIR" \
  -type d \( -name "$ARCHIVE_DIR" -o -name "-*" -o -name "!*" -o -name "__*" \) -prune -o \
  -type f -name "*.md" -print | while IFS= read -r FILE; do
    BASE="$(basename "$FILE")"

    # 只处理纳入前缀
    case "$BASE" in
      "$TASK_INCLUDE_PREFIX"*) : ;;  # OK
      *) continue ;;
    esac

    # 跳过已完成/阻塞
    case "$BASE" in
      *"$STATUS_SUFFIX_DONE"|*"$STATUS_SUFFIX_BLOCKED") continue ;;
    esac

    # 识别状态
    STATUS="todo"
    case "$BASE" in
      *"$STATUS_SUFFIX_DOING") STATUS="doing" ;;
    esac

    # 如果是 todo，先改名为 doing（加锁）
    if [ "$STATUS" = "todo" ]; then
      ROOT_NO_STATUS="$(strip_status_path "$FILE")"
      NEW="$ROOT_NO_STATUS$STATUS_SUFFIX_DOING"
      mv "$FILE" "$NEW"
      FILE="$NEW"
      BASE="$(basename "$FILE")"
      STATUS="doing"
    fi

    # 生成输出/日志文件名
    TITLE="$BASE"
    # 去前缀 ++
    case "$TITLE" in
      "$TASK_INCLUDE_PREFIX"*) TITLE="${TITLE#"$TASK_INCLUDE_PREFIX"}" ;;
    esac
    # 去后缀
    TITLE="$(printf '%s' "$TITLE" | sed -e "s/$(printf '%s' "$STATUS_SUFFIX_DOING" | sed 's/[.[\*^$]/\\&/g')\$//" \
                                        -e "s/$(printf '%s' "$STATUS_SUFFIX_DONE" | sed 's/[.[\*^$]/\\&/g')\$//" \
                                        -e "s/$(printf '%s' "$STATUS_SUFFIX_BLOCKED" | sed 's/[.[\*^$]/\\&/g')\$//" \
                                        -e 's/\.md$//')"
    SAFE_TITLE="$(printf '%s' "$TITLE" | tr ' /:\\t' '----' )"
    OUT_FILE="$OUT_DIR/__${SAFE_TITLE}.out.md"
    LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S)_${SAFE_TITLE}.log"

    # 执行：把 MD 内容作为 -p 传给 CLI（使用 CLAUDE_ARGS）
    # 在 MD 文件所在目录执行，这样创建的文件会在正确的位置
    # 成功→ .done；失败→ .blocked
    FILE_DIR="$(dirname "$FILE")"

    # 记录开始时间和任务信息到日志
    printf '%s\n' "$(date -u '+%F %T UTC') START processing $BASE with $CLI" >> "$LOG_FILE"
    printf '%s\n' "============================================" >> "$LOG_FILE"

    # 执行命令，同时记录到输出文件和日志文件
    if (cd "$FILE_DIR" && "$CLI" "${CLAUDE_ARGS[@]}" "$(cat "$FILE")") 2>&1 | tee "$OUT_FILE" >> "$LOG_FILE"; then
      ROOT_NO_STATUS="$(strip_status_path "$FILE")"
      DONE_PATH="${ROOT_NO_STATUS}${STATUS_SUFFIX_DONE}"
      mv "$FILE" "$DONE_PATH"
      printf '%s\n' "============================================" >> "$LOG_FILE"
      printf '%s\n' "$(date -u '+%F %T UTC') OK $BASE → $(basename "$DONE_PATH") | out=$(basename "$OUT_FILE") | cli=$CLI" >> "$LOG_FILE"
    else
      ROOT_NO_STATUS="$(strip_status_path "$FILE")"
      BLOCK_PATH="${ROOT_NO_STATUS}${STATUS_SUFFIX_BLOCKED}"
      mv "$FILE" "$BLOCK_PATH"
      printf '%s\n' "============================================" >> "$LOG_FILE"
      printf '%s\n' "$(date -u '+%F %T UTC') FAIL $BASE → $(basename "$BLOCK_PATH") | cli=$CLI" >> "$LOG_FILE"
    fi
done