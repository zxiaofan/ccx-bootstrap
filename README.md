# CCX Windows 安装与升级入口

在 Windows Terminal 的 PowerShell 中执行同一命令，首次安装和后续升级均可使用：

~~~powershell
irm https://raw.githubusercontent.com/zxiaofan/ccx-bootstrap/main/install.ps1 | iex
~~~

可先打开 [install.ps1](install.ps1) 阅读公开引导脚本。该仓库不包含 CCX 私有源码、配置、密钥或运行状态；脚本与私有 CCX 仓库 v2026.11.13.6 的 bootstrap-windows.ps1 内容一致。

- 新电脑：按需安装 GitHub CLI，引导有私有仓库权限的 GitHub 账号登录，随后运行固定 CCX 版本的安装向导。Git、Go、psmux、原生 Codex、飞书应用与项目目录按向导提示处理。
- 已安装电脑：调用同目录的 ccxExe.cmd update，等待同一维护编号完成本机核对。飞书入站和实际 AI 会话仍需本人验证。
- 旧版安装若没有 ccxExe.cmd：按提示先通过原机器人私聊升级一次；引导脚本不会直接覆盖已有程序。

短 URL 入口只负责安装与升级路由。CCX 产品文档及完整版本记录保存在已授权的私有仓库中。
