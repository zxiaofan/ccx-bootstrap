function Invoke-CcxGitHub([string[]]$Arguments, [switch]$Capture) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = (Get-Command gh -ErrorAction Stop).Source
    # Arguments below are fixed API paths, validated names/tags and Windows
    # file paths (which cannot contain quotes); paths never end in backslash.
    $info.Arguments = (($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $started = [DateTime]::UtcNow
        $nextNotice = $started.AddSeconds(15)
        while (-not $process.WaitForExit(1000)) {
            $now = [DateTime]::UtcNow
            if (($now - $started).TotalSeconds -ge 300) { $process.Kill(); $process.WaitForExit(); throw 'GitHub request timed out after 300 seconds; original installation retained.' }
            if ($now -ge $nextNotice) { Write-Host ('GitHub download/check still running: ' + [int]($now-$started).TotalSeconds + ' seconds'); $nextNotice = $now.AddSeconds(15) }
        }
        $result = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw 'GitHub request failed; check login, permission and network. No source-build fallback.' }
        if ($Capture) { return $result }
    } finally { $process.Dispose() }
}

function Invoke-CcxBootstrap {
    if ($env:OS -ne 'Windows_NT') { throw 'This bootstrap requires Windows.' }
    $gh = (Get-Command gh.exe -ErrorAction SilentlyContinue).Source
    if (-not $gh) {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'Install GitHub CLI (gh) and retry this URL.' }
        & winget.exe install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI installation failed.' }
        $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
        $gh = (Get-Command gh.exe -ErrorAction SilentlyContinue).Source
        if (-not $gh) { throw 'Reopen Terminal to use GitHub CLI and retry.' }
    }
    & $gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        & $gh auth login --hostname github.com --git-protocol https --web
        if ($LASTEXITCODE -ne 0) { throw 'GitHub login did not complete.' }
    }
    $raw = Invoke-CcxGitHub -Arguments @('api','--method','GET','repos/zxiaofan/ccx/releases/latest') -Capture
    $release = ($raw -join "`n") | ConvertFrom-Json
    if ($release.draft -or $release.prerelease -or $release.tag_name -notmatch '^v\d{4}\.\d{2}\.\d{2}\.[1-9]\d*$' -or $release.html_url -ne ('https://github.com/zxiaofan/ccx/releases/tag/' + $release.tag_name)) { throw 'Invalid official release identity.' }
    $asset = @($release.assets | Where-Object { $_.name -ceq 'release-download.ps1' })
    if ($asset.Count -ne 1 -or $asset[0].state -ne 'uploaded' -or $asset[0].size -le 0 -or $asset[0].size -gt 1048576 -or $asset[0].digest -notmatch '^sha256:[a-f0-9]{64}$') { throw 'Release download helper is missing or invalid.' }
    $root = Join-Path (Join-Path $env:LOCALAPPDATA 'CCXData\cache\releases') $release.tag_name
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $helper = Join-Path $root 'release-download.ps1'
    if (-not (Test-Path -LiteralPath $helper)) {
        Invoke-CcxGitHub -Arguments @('release','download',$release.tag_name,'--repo','zxiaofan/ccx','--pattern','release-download.ps1','--dir',$root)
    }
    $stream = [IO.File]::OpenRead($helper)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actualHash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose(); $stream.Dispose() }
    if ((Get-Item -LiteralPath $helper).Length -ne $asset[0].size -or ('sha256:' + $actualHash) -cne $asset[0].digest) { throw 'Download helper hash mismatch; not executed.' }
    . $helper
    foreach ($name in @('manifest.json','install.ps1','install.bat','setup-windows.ps1')) { $null = Get-CcxAsset $release $name }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'setup-windows.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'CCX installation/maintenance did not complete. Follow the displayed record or error; do not retry an active maintenance.' }
}
Invoke-CcxBootstrap
