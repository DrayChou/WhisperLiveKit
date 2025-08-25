# WhisperLiveKit 管理脚本
# 提供启动、停止、状态检查等功能

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "install", "update", "help")]
    [string]$Action = "start",
    
    [string]$Model = "tiny",
    [int]$Port = 8815,
    [string]$Language = "auto",
    [string]$ConfigFile = "config.txt"
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 全局变量
$ProcessName = "whisperlivekit-server"
$ProjectName = "WhisperLiveKit"

function Write-ColorText {
    param($Text, $Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Show-Header {
    Write-ColorText @"

╔══════════════════════════════════════════╗
║         WhisperLiveKit 管理器            ║
║    实时语音转录服务管理工具              ║
╚══════════════════════════════════════════╝

"@ -Color Cyan
}

function Show-Help {
    Write-ColorText @"
用法: .\WhisperLiveKit-Manager.ps1 <操作> [参数]

操作:
    start     - 启动服务 (默认)
    stop      - 停止服务
    restart   - 重启服务
    status    - 检查服务状态
    install   - 安装依赖
    update    - 更新到最新版本
    help      - 显示帮助

参数:
    -Model <string>      模型大小 (tiny, base, small, medium, large)
    -Port <int>          端口号 (默认: 8815)
    -Language <string>   语言代码 (默认: auto)
    -ConfigFile <string> 配置文件路径 (默认: config.txt)

示例:
    .\WhisperLiveKit-Manager.ps1 start -Model medium
    .\WhisperLiveKit-Manager.ps1 stop
    .\WhisperLiveKit-Manager.ps1 status

"@ -Color Green
}

function Test-ProjectDirectory {
    if (-not (Test-Path "pyproject.toml")) {
        Write-ColorText "[错误] 不在项目根目录！请在 WhisperLiveKit 项目目录下运行。" -Color Red
        Write-ColorText "当前目录: $PWD" -Color Yellow
        exit 1
    }
}

function Test-Python {
    try {
        $version = python --version 2>&1
        Write-ColorText "[✓] Python: $version" -Color Green
        return $true
    } catch {
        Write-ColorText "[✗] Python 未找到！请安装Python并添加到PATH。" -Color Red
        return $false
    }
}

function Test-WhisperLiveKit {
    try {
        python -c "import whisperlivekit; print('版本:', whisperlivekit.__version__)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "[✓] WhisperLiveKit 已安装" -Color Green
            return $true
        }
    } catch {}
    
    Write-ColorText "[!] WhisperLiveKit 未安装" -Color Yellow
    return $false
}

function Install-WhisperLiveKit {
    Write-ColorText "[安装] 正在安装 WhisperLiveKit..." -Color Yellow
    
    # 配置pip镜像源
    Write-ColorText "  配置pip镜像源..." -Color Gray
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    
    # 安装依赖
    Write-ColorText "  安装项目依赖..." -Color Gray
    pip install -e . -i https://pypi.tuna.tsinghua.edu.cn/simple
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorText "[✓] 安装成功！" -Color Green
        return $true
    } else {
        Write-ColorText "[✗] 安装失败！" -Color Red
        return $false
    }
}

function Read-Config {
    $config = @{}
    
    if (Test-Path $ConfigFile) {
        Write-ColorText "[配置] 读取配置文件: $ConfigFile" -Color Gray
        Get-Content $ConfigFile | ForEach-Object {
            if ($_ -match '^([^#=]+)=(.+)$') {
                $config[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }
    
    return $config
}

function Get-ServiceStatus {
    $processes = Get-Process -Name "python" -ErrorAction SilentlyContinue | 
                Where-Object { $_.CommandLine -like "*whisperlivekit-server*" }
    
    if ($processes) {
        return @{
            Running = $true
            ProcessId = $processes[0].Id
            StartTime = $processes[0].StartTime
            Port = $Port
        }
    } else {
        return @{ Running = $false }
    }
}

function Start-Service {
    $status = Get-ServiceStatus
    if ($status.Running) {
        Write-ColorText "[!] 服务已在运行 (PID: $($status.ProcessId))" -Color Yellow
        return
    }
    
    # 读取配置
    $config = Read-Config
    $finalModel = if ($config.MODEL) { $config.MODEL } else { $Model }
    $finalPort = if ($config.PORT) { [int]$config.PORT } else { $Port }
    $finalLanguage = if ($config.LANGUAGE) { $config.LANGUAGE } else { $Language }
    $finalHost = if ($config.HOST) { $config.HOST } else { "0.0.0.0" }
    
    # 构建启动参数
    $args = @(
        "--host", $finalHost,
        "--port", $finalPort,
        "--model", $finalModel,
        "--language", $finalLanguage
    )
    
    # 添加可选参数
    if ($config.DIARIZATION -eq "true") {
        $args += "--diarization"
        Write-ColorText "[配置] 说话人分离: 启用" -Color Green
    }
    
    if ($config.CONFIDENCE_VALIDATION -eq "true") {
        $args += "--confidence-validation"
        Write-ColorText "[配置] 置信度验证: 启用" -Color Green
    }
    
    if ($config.LOG_LEVEL) {
        $args += @("--log-level", $config.LOG_LEVEL)
    }
    
    Write-ColorText @"

[启动] 配置信息:
  主机: $finalHost
  端口: $finalPort  
  模型: $finalModel
  语言: $finalLanguage

"@ -Color Cyan
    
    Write-ColorText "[启动] 启动 WhisperLiveKit 服务..." -Color Yellow
    Write-ColorText "[信息] 访问地址: http://localhost:$finalPort" -Color Green
    Write-ColorText "[信息] API文档: http://localhost:$finalPort/docs" -Color Green
    Write-ColorText "[提示] 按 Ctrl+C 停止服务" -Color Gray
    Write-ColorText "".PadRight(50, "=") -Color Cyan
    
    try {
        & whisperlivekit-server @args
    } catch {
        Write-ColorText "[✗] 服务启动失败: $($_.Exception.Message)" -Color Red
    }
}

function Stop-Service {
    $status = Get-ServiceStatus
    if (-not $status.Running) {
        Write-ColorText "[!] 服务未运行" -Color Yellow
        return
    }
    
    try {
        Stop-Process -Id $status.ProcessId -Force
        Write-ColorText "[✓] 服务已停止 (PID: $($status.ProcessId))" -Color Green
    } catch {
        Write-ColorText "[✗] 停止服务失败: $($_.Exception.Message)" -Color Red
    }
}

function Show-Status {
    $status = Get-ServiceStatus
    
    Write-ColorText "服务状态:" -Color Cyan
    if ($status.Running) {
        Write-ColorText "  状态: 运行中 ✓" -Color Green
        Write-ColorText "  进程ID: $($status.ProcessId)" -Color Gray
        Write-ColorText "  启动时间: $($status.StartTime)" -Color Gray
        Write-ColorText "  访问地址: http://localhost:$($status.Port)" -Color Gray
    } else {
        Write-ColorText "  状态: 未运行 ✗" -Color Red
    }
}

# 主程序流程
Show-Header

switch ($Action.ToLower()) {
    "help" {
        Show-Help
        exit 0
    }
    
    "install" {
        Test-ProjectDirectory
        if (-not (Test-Python)) { exit 1 }
        if (-not (Install-WhisperLiveKit)) { exit 1 }
        Write-ColorText "[✓] 安装完成！可以使用 'start' 命令启动服务。" -Color Green
    }
    
    "status" {
        Show-Status
    }
    
    "stop" {
        Stop-Service
    }
    
    "restart" {
        Write-ColorText "[重启] 重启服务..." -Color Yellow
        Stop-Service
        Start-Sleep -Seconds 2
        Test-ProjectDirectory
        if (-not (Test-Python)) { exit 1 }
        if (-not (Test-WhisperLiveKit)) {
            if (-not (Install-WhisperLiveKit)) { exit 1 }
        }
        Start-Service
    }
    
    "start" {
        Test-ProjectDirectory
        if (-not (Test-Python)) { exit 1 }
        if (-not (Test-WhisperLiveKit)) {
            if (-not (Install-WhisperLiveKit)) { exit 1 }
        }
        Start-Service
    }
    
    "update" {
        Test-ProjectDirectory
        Write-ColorText "[更新] 更新 WhisperLiveKit..." -Color Yellow
        pip install -U -e . -i https://pypi.tuna.tsinghua.edu.cn/simple
        Write-ColorText "[✓] 更新完成！" -Color Green
    }
    
    default {
        Write-ColorText "[错误] 未知操作: $Action" -Color Red
        Write-ColorText "使用 'help' 查看可用操作。" -Color Yellow
    }
}