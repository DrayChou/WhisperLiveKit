@echo off
chcp 65001 >nul
title WhisperLiveKit 语音转录服务

echo.
echo ========================================
echo       WhisperLiveKit 启动脚本
echo ========================================
echo.

:: 检查是否在项目目录中
if not exist "pyproject.toml" (
    echo [错误] 请在 WhisperLiveKit 项目根目录下运行此脚本！
    echo 当前目录: %CD%
    pause
    exit /b 1
)

:: 检查Python环境
echo [检查] 验证Python环境...
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到Python！请确保Python已安装并添加到PATH中。
    pause
    exit /b 1
)

:: 显示Python版本
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo [信息] Python版本: %PYTHON_VERSION%

:: 检查WhisperLiveKit是否已安装
echo [检查] 验证WhisperLiveKit安装...
python -c "import whisperlivekit" 2>nul
if errorlevel 1 (
    echo [警告] WhisperLiveKit未安装，正在安装...
    echo [安装] 配置pip镜像源...
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    echo [安装] 安装WhisperLiveKit...
    pip install -e . -i https://pypi.tuna.tsinghua.edu.cn/simple
    if errorlevel 1 (
        echo [错误] 安装失败！
        pause
        exit /b 1
    )
    echo [成功] WhisperLiveKit安装完成！
)

:: 设置默认参数
set HOST=0.0.0.0
set PORT=8815
set MODEL=tiny
set LANGUAGE=zh

:: 读取用户配置（如果存在）
if exist "config.txt" (
    echo [配置] 读取用户配置文件...
    for /f "tokens=1,2 delims==" %%a in (config.txt) do (
        if "%%a"=="HOST" set HOST=%%b
        if "%%a"=="PORT" set PORT=%%b
        if "%%a"=="MODEL" set MODEL=%%b
        if "%%a"=="LANGUAGE" set LANGUAGE=%%b
    )
)

echo.
echo [配置] 启动参数:
echo   - 主机地址: %HOST%
echo   - 端口: %PORT%
echo   - 模型: %MODEL%
echo   - 语言: %LANGUAGE%
echo.

:: 显示访问信息
echo [信息] 服务启动后可通过以下地址访问:
echo   - 本地访问: http://localhost:%PORT%
echo   - 局域网访问: http://%COMPUTERNAME%:%PORT%
echo   - API文档: http://localhost:%PORT%/docs
echo.

echo [启动] 正在启动 WhisperLiveKit 服务器...
echo [提示] 按 Ctrl+C 停止服务
echo ========================================
echo.

:: 启动服务
whisperlivekit-server --host %HOST% --port %PORT% --model %MODEL% --language %LANGUAGE%

:: 如果服务意外退出
echo.
echo ========================================
echo [信息] WhisperLiveKit 服务已停止
echo ========================================
pause