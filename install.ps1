function Invoke-CcxBootstrap {
    if ($env:OS -ne 'Windows_NT') { throw '此入口仅用于 Windows Terminal 的 PowerShell。' }
    $installDir = Join-Path $env:LOCALAPPDATA 'CCX'
    $exe = Join-Path $installDir 'ccx.exe'
    $command = Join-Path $installDir 'ccxExe.cmd'

    if (Test-Path -LiteralPath $command) {
        $header = @(Get-Content -LiteralPath $command -TotalCount 2)
        if (-not (Test-Path -LiteralPath $exe) -or $header.Count -ne 2 -or $header[1] -ne 'rem CCX managed maintenance command') {
            throw '安装目录中的维护命令身份不符；请先核对文件，不执行升级。'
        }
        $output = & $command update
        if ($LASTEXITCODE -ne 0) { throw 'CCX 更新未受理；请先运行 ccxExe status 核对网关和维护状态。' }
        try { $result = $output | ConvertFrom-Json -ErrorAction Stop } catch { throw '无法解析本机更新结果，请核对已安装程序。' }
        if ($result.state -eq 'current') {
            Write-Host "CCX 已是最新版本：$($result.current)"
            return
        }
        if ($result.state -ne 'accepted' -or -not $result.id) { throw "更新返回未识别的状态：$($result.state)" }
        Write-Host "更新已受理，维护编号：$($result.id)；正在等待本机验收。"
        $configFile = if ($env:CCX_CONFIG -and (Test-Path -LiteralPath $env:CCX_CONFIG)) {
            $env:CCX_CONFIG
        } else {
            $registered = Join-Path $installDir 'config-path'
            if (-not (Test-Path -LiteralPath $registered)) { throw '缺少安装配置登记，请本机核对维护编号。' }
            (Get-Content -LiteralPath $registered -TotalCount 1).Trim()
        }
        $configFile = (Resolve-Path -LiteralPath $configFile -ErrorAction Stop).Path
        $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $config.state_dir) { throw '配置缺少 state_dir，请本机核对维护编号。' }
        $stateDir = [string]$config.state_dir
        if (-not [IO.Path]::IsPathRooted($stateDir)) {
            $stateDir = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $configFile) $stateDir))
        }
        $recordFile = Join-Path $stateDir 'upgrade\latest.json'
        $lastPhase = ''
        for ($attempt = 0; $attempt -lt 180; $attempt++) {
            if (Test-Path -LiteralPath $recordFile) {
                $record = Get-Content -LiteralPath $recordFile -Raw | ConvertFrom-Json -ErrorAction Stop
                if ($record.id -eq $result.id) {
                    if ($record.phase -ne $lastPhase) {
                        Write-Host "维护阶段：$($record.phase)"
                        $lastPhase = $record.phase
                    }
                    if ($record.phase -eq 'updated-outbound-verified') {
                        $check = & $command update_check
                        if ($LASTEXITCODE -ne 0) { throw '程序已切换，但版本检查未通过；请核对维护记录。' }
                        $status = & $command status
                        if ($LASTEXITCODE -ne 0) { throw '程序已切换，但网关状态未通过；请核对维护记录。' }
                        Write-Host 'CCX 本机升级完成。请在飞书核对真实入站和原会话续聊。'
                        return
                    }
                    if ($record.phase -in @('failed-before-stop', 'needs-check', 'rolled-back-local')) {
                        throw "维护 $($result.id) 处于 $($record.phase)：$($record.detail)；不会自动重试。"
                    }
                }
            }
            Start-Sleep -Seconds 5
        }
        throw "维护 $($result.id) 尚未完成；请核对 $recordFile，不会重复发起升级。"
    }

    if (Test-Path -LiteralPath $exe) {
        throw '发现无全局维护命令的旧安装。请在原机器人私聊发送升级命令，升级完成后重试同一 URL；不会覆盖旧程序。'
    }

    $gh = (Get-Command gh.exe -ErrorAction SilentlyContinue).Source
    if (-not $gh) {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            throw '缺少 winget，请先安装 Windows App Installer，然后重试同一 URL。'
        }
        Write-Host '正在安装 GitHub CLI，以访问 CCX 私有源码。'
        & winget.exe install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI 安装未完成；处理上面的提示后重试同一 URL。' }
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
        $gh = (Get-Command gh.exe -ErrorAction SilentlyContinue).Source
        if (-not $gh) { $gh = Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe' }
        if (-not (Test-Path -LiteralPath $gh)) { throw 'GitHub CLI 尚未被当前终端识别；重新打开 Terminal 并重试同一 URL。' }
    }
    & $gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '请在浏览器登录有 CCX 私有仓库权限的 GitHub 账号。'
        & $gh auth login --hostname github.com --git-protocol https --web
        if ($LASTEXITCODE -ne 0) { throw 'GitHub 登录未完成；重试同一 URL。' }
    }
    $raw = & $gh api --method GET 'repos/zxiaofan/ccx/contents/setup-windows.ps1?ref=v2026.11.13.7' -H 'Accept: application/vnd.github.raw+json'
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        throw '当前 GitHub 账号无 CCX 仓库权限或网络不可用；获得权限后重试同一 URL。'
    }
    $setup = Join-Path $env:TEMP 'ccx-setup-windows.ps1'
    [IO.File]::WriteAllText($setup, ($raw -join [Environment]::NewLine), [Text.UTF8Encoding]::new($true))
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup
    if ($LASTEXITCODE -ne 0) { throw '首次安装未完成；按终端提示处理后重试同一 URL。' }
}

Invoke-CcxBootstrap
