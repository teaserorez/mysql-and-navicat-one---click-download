@echo off
chcp 65001 > nul
>nul 2>&1 "%SystemRoot%\system32\fltmc.exe" || (
    powershell -Command "Start-Process -FilePath '%~0' -Verb RunAs"
    exit /b
)
set "rootPath=C:\ca\navicat"
if not exist "%rootPath%" mkdir "%rootPath%"
echo 请选择版本
echo [1] Navicat Premium 16
echo [2] Navicat Premium 17
set /p choose=请输入编号:
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
if %choose%==1 (
set "version=Navicat Premium 16"
set "exeName=navicat163_premium_cs_x64.exe"
set "source=http://120.26.85.32:9000/code-assistant/software/navicat/5EEA922A09154A428BF896AF50F91E7D_Navicat Premium 16.zip";
) else if %choose%==2 (
set "version=Navicat Premium 17"
set "exeName=navicat170_premium_cs_x64.exe"
set "source=http://120.26.85.32:9000/code-assistant/software/navicat/93E6B168C38841B1B985AA81540B4471_Navicat Premium 17.zip";
) else (
set "version=Navicat Premium 16"
set "exeName=navicat163_premium_cs_x64.exe"
set "source=http://120.26.85.32:9000/code-assistant/software/navicat/5EEA922A09154A428BF896AF50F91E7D_Navicat Premium 16.zip";
)
)else (
echo 暂不支持32位版本
    pause & exit /b 1
)
echo 您选择的版本是: %version%
set "target=%rootPath%\%version%.zip"
set "installDir=%rootPath%\navicat"
if exist "%target%" (goto :sourceIsExist)
echo 正在下载资源文件，请稍候...
rem download tomcat source file
call :download "%source%" "%target%"
:sourceIsExist
call :unzip "%target%" "%rootPath%"
:unzip_ok
echo 解压完成
rem call free use bat file
echo 无限试用脚本中....
call "%rootPath%\%version%\Crack\无限试用Navicat.bat"
echo 无限试用脚本调用完成
rem clear navicat old dir
echo 清理残留目录...
if exist "%installDir%" rmdir /s /q "%installDir%"
echo 安装%version%中....
"%rootPath%\%version%\%exeName%" /VERYSILENT /DIR="%installDir%"
echo %version%安装完成
echo 复制winmm.dll中....
copy /Y "%rootPath%\%version%\Crack\winmm.dll" "%installDir%"
echo %version%安装完成
pause

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

:unzip
rem unzip by PowerShell5
powershell -command "exit ([int]($PSVersionTable.PSVersion.Major -ge 5))" 2>nul
if %errorlevel% equ 1 (
    echo 使用 PowerShell 5 解压
    powershell -command "Expand-Archive -Path '%~1' -DestinationPath '%~2' -Force"
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
    "%~dp07za.exe" x -y -o"%~1"
    goto :unzip_ok
)
echo [ERROR] 找不到可用的解压工具
echo           1) 把 7za.exe 放在本目录
echo           2) 或安装 PowerShell 5.1
pause
exit /b 1
goto :eof