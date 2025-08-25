# WhisperLiveKit PowerShell 启动脚本
# 用法: .\Start-WhisperLiveKit.ps1 [-Model tiny] [-Port 8815] [-Language auto]

param(
    [string]$Model = "tiny",
    [int]$Port = 8815,
    [string]$Language = "zh",
    [string]$BindHost = "0.0.0.0",
    [switch]$GPU = $false,
    [switch]$Diarization = $false,
    [switch]$Help = $false
)

# 设置控制台编码
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Show-Help {
    Write-Host @"

WhisperLiveKit PowerShell 启动脚本
=====================================

用法:
    .\Start-WhisperLiveKit.ps1 [参数]

参数:
    -Model <string>     Whisper模型大小 (tiny, base, small, medium, large)
    -Port <int>         服务端口号 (默认: 8815)
    -Language <string>  语言代码 (auto, zh, en 等，默认: zh)
    -BindHost <string>  绑定主机地址 (默认: 0.0.0.0)
    -GPU                启用GPU加速 (需要CUDA)
    -Diarization        启用说话人分离
    -Help               显示此帮助信息

示例:
    .\Start-WhisperLiveKit.ps1
    .\Start-WhisperLiveKit.ps1 -Model medium -Port 8888
    .\Start-WhisperLiveKit.ps1 -Language zh -GPU -Diarization

"@
}

if ($Help) {
    Show-Help
    exit 0
}

# 显示标题
Write-Host @"

========================================
      WhisperLiveKit 启动脚本
========================================

"@ -ForegroundColor Cyan

# 检查是否在项目目录中
if (-not (Test-Path "pyproject.toml")) {
    Write-Host "[错误] 请在 WhisperLiveKit 项目根目录下运行此脚本！" -ForegroundColor Red
    Write-Host "当前目录: $PWD" -ForegroundColor Yellow
    Read-Host "按回车键退出"
    exit 1
}

# 检查Python环境
Write-Host "[检查] 验证Python环境..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "[信息] $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "[错误] 未找到Python！请确保Python已安装并添加到PATH中。" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}

# 检查WhisperLiveKit是否已安装
Write-Host "[检查] 验证WhisperLiveKit安装..." -ForegroundColor Yellow
try {
    python -c "import whisperlivekit" 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "[信息] WhisperLiveKit 已安装" -ForegroundColor Green
} catch {
    Write-Host "[警告] WhisperLiveKit未安装，正在安装..." -ForegroundColor Yellow
    
    Write-Host "[安装] 配置pip镜像源..." -ForegroundColor Yellow
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    
    Write-Host "[安装] 安装WhisperLiveKit..." -ForegroundColor Yellow
    pip install -e . -i https://pypi.tuna.tsinghua.edu.cn/simple
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 安装失败！" -ForegroundColor Red
        Read-Host "按回车键退出"
        exit 1
    }
    Write-Host "[成功] WhisperLiveKit安装完成！" -ForegroundColor Green
}

# GPU自动检测和启用
if (-not $GPU) {
    try {
        $cudaCheck = python -c "import torch; print(torch.cuda.is_available())" 2>$null
        if ($LASTEXITCODE -eq 0 -and $cudaCheck -eq "True") {
            $GPU = $true
            Write-Host "[信息] 检测到CUDA支持，自动启用GPU模式" -ForegroundColor Green
        } else {
            Write-Host "[信息] 未检测到CUDA支持，使用CPU模式" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[信息] GPU检查失败，使用CPU模式" -ForegroundColor Yellow
        $GPU = $false
    }
} else {
    Write-Host "[信息] 手动启用GPU模式" -ForegroundColor Green
}

# 构建启动参数
$args = @(
    "--host", $BindHost,
    "--port", $Port,
    "--model", $Model,
    "--language", $Language
)

if ($Diarization) {
    $args += "--diarization"
    Write-Host "[信息] 说话人分离已启用" -ForegroundColor Green
}

# 显示配置信息
Write-Host @"

[配置] 启动参数:
  - 主机地址: $BindHost
  - 端口: $Port
  - 模型: $Model
  - 语言: $Language
  - GPU模式: $(if ($GPU) { '启用' } else { '禁用' })
  - 说话人分离: $(if ($Diarization) { '启用' } else { '禁用' })

"@ -ForegroundColor Cyan

# 显示访问信息
Write-Host @"
[信息] 服务启动后可通过以下地址访问:
  - 本地访问: http://localhost:$Port
  - 局域网访问: http://$env:COMPUTERNAME:$Port
  - API文档: http://localhost:$Port/docs

"@ -ForegroundColor Green

Write-Host "[启动] 正在启动 WhisperLiveKit 服务器..." -ForegroundColor Yellow
Write-Host "[提示] 按 Ctrl+C 停止服务" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 启动服务
try {
    & whisperlivekit-server @args
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "[错误] 服务启动失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
} finally {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[信息] WhisperLiveKit 服务已停止" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Read-Host "按回车键退出"
}
