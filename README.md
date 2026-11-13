# CCX 安装与升级入口

Windows Terminal 的 PowerShell：

```powershell
irm https://raw.githubusercontent.com/zxiaofan/ccx-bootstrap/main/install.ps1 | iex
```

Linux 终端（普通用户、支持 systemd 用户服务）：

```bash
curl -fsSL https://raw.githubusercontent.com/zxiaofan/ccx-bootstrap/main/install.sh | bash
```

公开入口只负责识别首次安装或已安装设备。首次安装会引导 GitHub 私有仓库授权、依赖、AI 登录和飞书应用配对；已安装设备从登记的源码分支升级，并等待本机维护记录完成。源代码和密钥不在此仓库。公开 `install.ps1` 与私有 CCX `v2026.11.13.7` 的 `bootstrap-windows.ps1` 相同；公开 `install.sh` 与同版本 `bootstrap-linux.sh` 相同。

Windows 安装目录默认是 `%LOCALAPPDATA%\CCX`，维护命令为 `ccxExe.cmd`；Linux 默认是 `~/.local/bin`，维护命令为 `ccxExe`。真实飞书收发和原 AI 会话续聊需在目标设备另行验收。
