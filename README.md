# CCX 安装、保留数据重装与升级入口

Windows Terminal / PowerShell：

```powershell
irm https://raw.githubusercontent.com/zxiaofan/ccx-bootstrap/main/install.ps1 | iex
```

Linux 普通用户的交互终端（支持 systemd 用户服务）：

```bash
curl -fsSL https://raw.githubusercontent.com/zxiaofan/ccx-bootstrap/main/install.sh | bash
```

公开脚本通过已授权 GitHub CLI 读取私有 zxiaofan/ccx 正式 Release，校验下载助手／向导的 GitHub SHA-256 后加载；安装器再核对平台、完整提交、协议、大小与 manifest.json。首次安装、同版重装、官方旧源码安装迁移及迁移后的升级使用发布端预编译程序，本机不需要 Git/Go，不执行 CCX 全量测试或编译；下载失败不回退源码构建。

Windows 支持 x64，Linux 支持 amd64。Windows 缺 gh 时由 winget 安装并引导授权；Linux 先准备 gh、Python 3、curl 与 Bash。仍需准备 psmux/tmux、本人已登录的原生 AI 工具，以及此电脑独立的飞书应用和主人配对。权限不足先处理账号访问，再重跑同一 URL，不在命令或 URL 放令牌。

已有登记安装走独立新版程序保留数据重装／迁移，不要求旧维护命令存在。保留配置、配对、历史、项目、兼容宿主和原自启动设置；空闲、安全归属与维护状态检查不能由 --force 绕过。损坏程序、缺失登记或未知外来文件须先诊断。

默认 Windows 安装目录 %LOCALAPPDATA%\CCX（ccx.exe／ccxExe.cmd），Linux ~/.local/bin（ccx／ccxExe）。重新打开终端后从任意目录执行 ccxExe status；网关已停止也可执行 ccxExe restart。正式新版本发布后，迁移后的 ccxExe update 和主人私聊“升级”均下载二进制包。

脚本与私有 CCX v2026.11.14.7 的 bootstrap-windows.ps1／bootstrap-linux.sh 对应。源码、密钥与运行状态不在本仓库。[使用手册](https://github.com/zxiaofan/ccx/blob/main/docs/operations/CCX-新电脑安装手册.md)和[发布验证](https://github.com/zxiaofan/ccx/blob/main/docs/validation/CCX-预编译分发安装重装升级验证-20261114.md)需仓库读取权限。真实飞书收发、原 AI 续聊及登录后自启动在目标设备另验。
