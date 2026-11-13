#!/usr/bin/env bash
# Public CCX bootstrap. Keep this file identical to ccx-bootstrap/install.sh.
set -euo pipefail

fail() { printf 'CCX: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Linux ]] || fail '此入口仅用于 Linux。'
[[ "$(id -u)" != 0 ]] || fail '请用普通用户安装，不要使用 sudo bash。'
[[ -r /dev/tty && -w /dev/tty ]] || fail '需要交互终端；请在 Terminal 中执行安装命令。'

install_dir="${CCX_INSTALL_DIR:-$HOME/.local/bin}"
command_file="$install_dir/ccxExe"
exe="$install_dir/ccx"
if [[ -e "$command_file" ]]; then
  [[ -x "$exe" && -f "$command_file" ]] || fail '安装目录中的程序或维护命令不完整，请先核对。'
  header="$(head -n 2 "$command_file")"
  [[ "$header" == $'#!/usr/bin/env bash\n# CCX managed maintenance command' ]] || fail '维护命令身份不符，拒绝执行升级。'
  command -v python3 >/dev/null || fail '缺少 python3；安装后重试同一条命令。'
  result="$("$command_file" update)" || fail '更新未受理，请执行 ccxExe status 核对。'
  state="$(printf '%s' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("state", ""))')" || fail '无法解析更新结果。'
  if [[ "$state" == current ]]; then printf 'CCX 已是最新版本。\n'; exit 0; fi
  [[ "$state" == accepted ]] || fail "更新状态未识别：$state"
  upgrade_id="$(printf '%s' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id", ""))')"
  [[ -n "$upgrade_id" ]] || fail '更新缺少维护编号。'
  config="${CCX_CONFIG:-}"
  if [[ -z "$config" && -f "$install_dir/config-path" ]]; then IFS= read -r config < "$install_dir/config-path"; fi
  [[ -f "$config" ]] || fail '缺少已登记配置，请核对 config-path。'
  record="$(python3 - "$config" <<'PY'
import json, os, sys
p = os.path.realpath(sys.argv[1])
d = json.load(open(p, encoding='utf-8'))['state_dir']
if not os.path.isabs(d): d = os.path.join(os.path.dirname(p), d)
print(os.path.join(d, 'upgrade', 'latest.json'))
PY
)" || fail '配置缺少 state_dir。'
  printf '更新已受理，维护编号：%s\n' "$upgrade_id"
  last_phase=''
  for ((attempt=0; attempt<180; attempt++)); do
    if [[ -f "$record" ]]; then
      phase="$(python3 - "$record" "$upgrade_id" <<'PY'
import json, sys
r=json.load(open(sys.argv[1], encoding='utf-8'))
print(r.get('phase', '') if r.get('id') == sys.argv[2] else '')
PY
)" || fail '维护记录无法解析。'
      if [[ -n "$phase" && "$phase" != "$last_phase" ]]; then printf '维护阶段：%s\n' "$phase"; last_phase="$phase"; fi
      case "$phase" in
        updated-outbound-verified)
          "$command_file" update_check >/dev/null || fail '程序已切换，但版本检查未通过。'
          "$command_file" status >/dev/null || fail '程序已切换，但网关状态未通过。'
          printf 'CCX 本机升级完成。请在飞书核对真实入站与原会话续聊。\n'
          exit 0 ;;
        needs-check|failed-before-stop|rolled-back-local) fail "维护 $upgrade_id 处于 $phase；请核对 $record，不会自动重试。" ;;
      esac
    fi
    sleep 5
  done
  fail "维护 $upgrade_id 尚未完成；请核对 $record，不会重复发起升级。"
fi
[[ ! -e "$exe" ]] || fail '发现无维护命令的旧安装。请在原机器人私聊发送“升级”，完成后重试同一 URL。'

command -v gh >/dev/null || fail '缺少 GitHub CLI。请按 https://github.com/cli/cli/blob/trunk/docs/install_linux.md 安装 gh 后重试同一 URL。'
if ! gh auth status >/dev/null 2>&1; then
  printf '请登录有 CCX 私有仓库权限的 GitHub 账号。\n'
  gh auth login --hostname github.com --git-protocol https --web < /dev/tty || fail 'GitHub 登录未完成；重试同一 URL。'
fi
setup="$(mktemp "${TMPDIR:-/tmp}/ccx-setup-linux.XXXXXXXX")"
trap 'rm -f -- "$setup"' EXIT
gh api --method GET 'repos/zxiaofan/ccx/contents/setup-linux.sh?ref=v2026.11.13.7' -H 'Accept: application/vnd.github.raw+json' > "$setup" || fail '无 CCX 私有仓库权限或网络不可用。'
[[ -s "$setup" ]] || fail '安装向导为空，停止安装。'
bash "$setup" < /dev/tty || fail '首次安装未完成；按提示处理后重试同一 URL。'
