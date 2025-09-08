@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion
>nul 2>&1 "%SystemRoot%\system32\fltmc.exe" || (
    powershell -Command "Start-Process -FilePath '%~0' -Verb RunAs"
    exit /b
)
set "rootPath=C:\ca\mysql"
if not exist "%rootPath%" mkdir "%rootPath%"
echo 本地安装目录为: %rootPath%
echo 请选择您想要安装的mysql版本
echo [1] mysql-8.0.13
echo [2] mysql-5.7.31
set /p choose=请输入版本编号:
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
if %choose%==1 (set "version=mysql-8.0.13-winx64") else (set "version=mysql-5.7.31-winx64")
)else (
if %choose%==1 (set "version=mysql-8.0.13-winx64") else (set "version=mysql-5.7.31-winx32")
)
echo 您选择的版本是: %version%
set "source=https://downloads.mysql.com/archives/get/p/23/file/%version%.zip";
set "target=%rootPath%\%version%.zip"
echo 来源: %source%
echo 目标: %target%
if exist "%target%" (goto :sourceIsExist)
echo 正在下载资源文件，请稍候...
rem download mysql source file
call :download "%source%" "%target%"
:sourceIsExist
rem install mysql
echo 开始安装%version%
set "destPath=%rootPath%\%version%"
set "password=123456"
if %choose%==1 (set "serverName=MYSQL80") else (set "serverName=MYSQL57")
rem clear old mysql version
set "serverNameList=MySQL MySQL80 MySQL57 MySQL56 MySQLa MySQLb"
rem stop and delete process
for %%s in (%serverNameList%) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        echo 检测到旧服务 %%s,正在停止并删除 ...
        net stop "%%s" /y 2>nul
        sc delete "%%s" 2>nul
        timeout /t 2 >nul
    )
)
rem clear dir
for /d %%d in ("%rootPath%\mysql-*-winx64") do (
    echo 删除旧目录 %%d ...
    rmdir /s /q "%%d" 2>nul
)
rem cheek envir
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" >nul
set "redistSource=https://aka.ms/vs/16/release"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" (set "redistVersion=vc_redist.x64.exe") else (set "redistVersion=vc_redist.x32.exe")
echo 正在下载 %redistVersion% ...
set "redistUrl=%redistSource%/%redistVersion%"
set "redistDst=%rootPath%\%redistVersion%"
if %errorlevel% equ 0 (goto :redistIsExist)
rem download redist.x64.exe
call :download "%redistUrl%" "%redistDst%"
echo 正在静默安装 VC++ 2015-2019 运行库 ...
"%redistDst%" /install /quiet /norestart
timeout /t 8 >nul
:redistIsExist
rem unzip by PowerShell5
powershell -command "exit ([int]($PSVersionTable.PSVersion.Major -ge 5))" 2>nul
if %errorlevel% equ 1 (
    echo 使用 PowerShell 5 解压
    powershell -command "Expand-Archive -Path '%target%' -DestinationPath '%rootPath%' -Force"
    goto :unzip_ok
)
rem unzip by PowerShell2
powershell -command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%ZIP%', 'C:\MySQL')" 2>nul
if %errorlevel% equ 0 (
    echo 使用 PowerShell 2 解压
    goto :unzip_ok
)

rem unzip by 7za.exe
if exist "%~dp07za.exe" (
    echo 使用 7za 解压
    "%~dp07za.exe" x -y -o"%target%"
    goto :unzip_ok
)
echo [ERROR] 找不到可用的解压工具
echo           1) 把 7za.exe 放在本目录
echo           2) 或安装 PowerShell 5.1
pause
exit /b 1
:unzip_ok
echo 解压完成
rem create my.ini config file
set config="%rootPath%\my.ini"
echo [mysqld] > "%config%"
echo basedir=%destPath% >> "%config%"
echo datadir=%destPath%\data >> "%config%"
echo port=3306 >> "%config%"
echo character-set-server=utf8mb4 >> "%config%"
echo default_authentication_plugin=mysql_native_password >> "%config%"
echo [client] >> "%config%"
echo port=3306 >> "%config%"
echo default-character-set=utf8mb4 >> "%config%"
rem init mysql
echo 初始化数据库 ...
"%destPath%\bin\mysqld" --initialize-insecure --basedir="%destPath%" --datadir="%destPath%\data"
if %errorlevel% neq 0 (
    echo 初始化失败
    pause
    exit /b 1
)

rem install and start mysql
echo 安装 Windows 服务 ...
"%destPath%\bin\mysqld" install %serverName% --defaults-file="%config%"
net start %serverName%
if %errorlevel% neq 0 (
    echo [ERROR] 启动服务失败
    pause
    exit /b 1
)
rem set account
echo 设置 root 密码 ...
"%destPath%\bin\mysql" -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '%password%'; FLUSH PRIVILEGES;"

echo 安装完成！
echo         服务名: %serverName%
echo         端口  : 3306
echo         root  : %password%
pause
exit /b 0

:download
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
"$url = '%~1'; $dst = '%~2'; ^
$job = Start-BitsTransfer -Source $url -Destination $dst -Asynchronous; ^
Set-BitsTransfer -BitsJob $job -Priority Foreground; ^
$t0 = [DateTime]::Now; $b0 = 0; ^
while ($job.JobState -in 'Connecting','Transferring') { ^
    $pct = [math]::Round($job.BytesTransferred / $job.BytesTotal * 100, 1); ^
    $speed = ($job.BytesTransferred - $b0) / 1KB / ([DateTime]::Now - $t0).TotalSeconds; ^
    $line = ('进度 {0,5:F1} %%  {1,6:0} KB/s' -f $pct, [int]$speed); ^
    Write-Host (\"`r$line\") -NoNewline; ^
    Start-Sleep 3; ^
}; ^
if ($job.JobState -eq 'Transferred') { ^
    Complete-BitsTransfer $job; Write-Host \"`下载完成！\"; ^
} else { ^
    Write-Host (\"`r下载失败：{0}\" -f $job.JobState); ^
}"
goto :eof