@ECHO OFF
CHCP 65001 >NUL
TITLE DeepSeek Harness - Setup (source build, virtual env)
CD /D "%~dp0"

REM ===============================================================
REM  DeepSeek Harness (dsh) - One-time Setup from SOURCE
REM
REM  Creates a self-contained virtual environment in env\ :
REM    env\node\                  portable Node.js runtime
REM    env\node_modules\.bin\     pnpm (locally installed)
REM    env\source\                dsh source code (git or zip)
REM    env\.pnpm-store\           pnpm package cache
REM    env\dsh-home\              all harness data (DSH_HOME)
REM    env\ENV.bat                generated environment loader
REM
REM  Nothing is installed system-wide and nothing outside this
REM  folder is touched. Delete env\ to fully uninstall.
REM ===============================================================

SET "DSH_ENV=%~dp0env"
SET "DSH_SOURCE=%DSH_ENV%\source"
SET "NODE_VERSION=22.19.0"
SET "PNPM_VERSION=11.7.0"
SET "NODE_URL=https://nodejs.org/dist/v%NODE_VERSION%/node-v%NODE_VERSION%-win-x64.zip"
SET "NODE_MIRROR=https://npmmirror.com/mirrors/node/v%NODE_VERSION%/node-v%NODE_VERSION%-win-x64.zip"
REM Upstream default branch; the GitHub zip snapshot folder is named
REM deepseek-harness-<branch> (the repo currently uses master, NOT main).
SET "SOURCE_BRANCH=master"
SET "ZIP_DIR_NAME=deepseek-harness-%SOURCE_BRANCH%"

ECHO.
ECHO ================================================
ECHO   DeepSeek Harness - Setup (source build) v5
ECHO ================================================
ECHO.

IF NOT EXIST "%DSH_ENV%" MKDIR "%DSH_ENV%"
IF NOT EXIST "%DSH_ENV%\dsh-home" MKDIR "%DSH_ENV%\dsh-home"

REM ---------------------------------------------------------------
REM  [1/5] Portable Node.js runtime
REM ---------------------------------------------------------------
IF NOT EXIST "%DSH_ENV%\node\node.exe" GOTO :node_download
ECHO [1/5] Portable Node.js already present in env\node :
"%DSH_ENV%\node\node.exe" -v
GOTO :node_ready

:node_download
ECHO [1/5] Downloading portable Node.js v%NODE_VERSION% (win-x64) ...
CALL :download_file "%NODE_URL%" "%DSH_ENV%\node.zip" "nodejs.org"
IF ERRORLEVEL 1 CALL :download_file "%NODE_MIRROR%" "%DSH_ENV%\node.zip" "npmmirror.com"
IF ERRORLEVEL 1 GOTO :node_download_fail
ECHO [OK] Downloaded node.zip.

ECHO   Extracting ...
tar -xf "%DSH_ENV%\node.zip" -C "%DSH_ENV%"
IF ERRORLEVEL 1 powershell -NoProfile -Command "Expand-Archive -Path '%DSH_ENV%\node.zip' -DestinationPath '%DSH_ENV%' -Force"
IF NOT EXIST "%DSH_ENV%\node-v%NODE_VERSION%-win-x64\node.exe" GOTO :node_extract_fail

IF EXIST "%DSH_ENV%\node" RD /S /Q "%DSH_ENV%\node"
REN "%DSH_ENV%\node-v%NODE_VERSION%-win-x64" "node"
IF ERRORLEVEL 1 GOTO :node_rename_fail
DEL /Q "%DSH_ENV%\node.zip" >NUL 2>NUL
ECHO [OK] Portable Node.js installed:
"%DSH_ENV%\node\node.exe" -v

:node_ready
REM ---------------------------------------------------------------
REM  [2/5] pnpm (installed into the virtual environment)
REM ---------------------------------------------------------------
SET "PNPM_BIN="
IF EXIST "%DSH_ENV%\pnpm.cmd" SET "PNPM_BIN=%DSH_ENV%\pnpm.cmd"
IF EXIST "%DSH_ENV%\node_modules\.bin\pnpm.cmd" SET "PNPM_BIN=%DSH_ENV%\node_modules\.bin\pnpm.cmd"
IF NOT "%PNPM_BIN%"=="" GOTO :pnpm_present

ECHO [2/5] Installing pnpm@%PNPM_VERSION% into the virtual environment ...
cmd /c ""%DSH_ENV%\node\npm.cmd" install --prefix "%DSH_ENV%" -g pnpm@%PNPM_VERSION% --no-fund --no-audit"
IF ERRORLEVEL 1 GOTO :pnpm_fail
SET "PNPM_BIN="
IF EXIST "%DSH_ENV%\pnpm.cmd" SET "PNPM_BIN=%DSH_ENV%\pnpm.cmd"
IF EXIST "%DSH_ENV%\node_modules\.bin\pnpm.cmd" SET "PNPM_BIN=%DSH_ENV%\node_modules\.bin\pnpm.cmd"
IF "%PNPM_BIN%"=="" GOTO :pnpm_fail
ECHO [OK] pnpm ready:
cmd /c ""%PNPM_BIN%" --version"
GOTO :step3

:pnpm_present
ECHO [2/5] pnpm already present:
cmd /c ""%PNPM_BIN%" --version"
ECHO [2/5] pnpm check done.

:step3
REM ---------------------------------------------------------------
REM  [3/5] source code
REM ---------------------------------------------------------------
IF EXIST "%DSH_SOURCE%\.git" GOTO :step3_git
IF EXIST "%DSH_SOURCE%\package.json" GOTO :step3_update

ECHO [3/5] Fetching source code ...
WHERE git >NUL 2>NUL
IF NOT ERRORLEVEL 1 GOTO :step3_clone
GOTO :fetch_source

:step3_git
ECHO [3/5] Updating source via git pull ...
CD /D "%DSH_SOURCE%"
git pull --ff-only
IF ERRORLEVEL 1 GOTO :git_fail
CD /D "%~dp0"
GOTO :deps

:git_fail
ECHO [ERROR] git pull failed. Check your network, or resolve local changes.
CD /D "%~dp0"
PAUSE
EXIT /B 1

:step3_update
ECHO [3/5] Source already present (zip snapshot).
CHOICE /C YN /T 10 /D N /M "Update to latest source"
IF NOT ERRORLEVEL 2 GOTO :zip_update
GOTO :deps

:step3_clone
ECHO   git found - cloning (shallow) ...
git clone --depth 1 https://github.com/deepseek-ai/deepseek-harness.git "%DSH_SOURCE%"
IF NOT ERRORLEVEL 1 GOTO :deps
ECHO   [WARN] git clone failed. Falling back to zip download ...
IF EXIST "%DSH_SOURCE%" RD /S /Q "%DSH_SOURCE%"

:fetch_source
IF EXIST "%DSH_ENV%\source.zip" GOTO :use_zip
CALL :download_zip "%DSH_ENV%\source.zip"
IF ERRORLEVEL 1 GOTO :source_download_fail
:use_zip
CALL :extract_zip "%DSH_ENV%\source.zip" "%DSH_ENV%"
IF ERRORLEVEL 1 GOTO :source_extract_fail
IF EXIST "%DSH_SOURCE%" RD /S /Q "%DSH_SOURCE%"
REN "%DSH_ENV%\%ZIP_DIR_NAME%" "source"
IF ERRORLEVEL 1 GOTO :source_rename_fail
DEL /Q "%DSH_ENV%\source.zip" >NUL 2>NUL
ECHO [OK] Source ready in env\source .
GOTO :deps

:zip_update
ECHO   Re-downloading latest source (keeps node_modules and .env) ...
IF NOT EXIST "%DSH_ENV%\source.zip" CALL :download_zip "%DSH_ENV%\source.zip"
IF ERRORLEVEL 1 GOTO :source_download_fail
CALL :extract_zip "%DSH_ENV%\source.zip" "%DSH_ENV%"
IF ERRORLEVEL 1 GOTO :source_extract_fail
XCOPY "%DSH_ENV%\%ZIP_DIR_NAME%\*" "%DSH_SOURCE%\" /E /Y /Q /H >NUL
IF %ERRORLEVEL% GEQ 4 GOTO :source_merge_fail
RD /S /Q "%DSH_ENV%\%ZIP_DIR_NAME%" >NUL 2>NUL
DEL /Q "%DSH_ENV%\source.zip" >NUL 2>NUL
ECHO [OK] Source updated.

:deps
REM ---------------------------------------------------------------
REM  [4/5] deps + build
REM ---------------------------------------------------------------
REM Make pnpm findable by nested npm scripts (build:web invokes "pnpm ...").
SET "PATH=%DSH_ENV%\node;%DSH_ENV%;%DSH_ENV%\node_modules\.bin;%PATH%"
CD /D "%DSH_SOURCE%"
ECHO.
ECHO [4/5] Installing dependencies with pnpm ...
ECHO   (several minutes on first run; downloads go to env\.pnpm-store)
cmd /c ""%PNPM_BIN%" install --store-dir "%DSH_ENV%\.pnpm-store""
IF ERRORLEVEL 1 GOTO :install_fail
ECHO.
ECHO [4/5] Building (first build takes 10-30 minutes, please be patient) ...
cmd /c ""%PNPM_BIN%" run build"
IF ERRORLEVEL 1 GOTO :build_fail
CD /D "%~dp0"
IF NOT EXIST "%DSH_SOURCE%\apps\cli\lib\bin.js" GOTO :bin_missing
ECHO [OK] dsh built successfully.

REM ---------------------------------------------------------------
REM  [5/5] env + key
REM ---------------------------------------------------------------
>  "%DSH_ENV%\ENV.bat" ECHO @ECHO OFF
>> "%DSH_ENV%\ENV.bat" ECHO REM Generated by setup_dsh.bat - do not edit.
>> "%DSH_ENV%\ENV.bat" ECHO SET "DSH_ENV=%%~dp0"
>> "%DSH_ENV%\ENV.bat" ECHO SET "DSH_HOME=%%~dp0dsh-home"
>> "%DSH_ENV%\ENV.bat" ECHO SET "DSH_SOURCE=%%~dp0source"
>> "%DSH_ENV%\ENV.bat" ECHO SET "PATH=%%~dp0node;%%~dp0;%%~dp0node_modules\.bin;%%PATH%%"
ECHO [5/5] env\ENV.bat generated.

SET "KEY_FILE=%DSH_SOURCE%\.env"
IF NOT "%DEEPSEEK_API_KEY%"=="" GOTO :key_env
SET "HAS_KEY=0"
IF EXIST "%KEY_FILE%" FINDSTR /C:"DEEPSEEK_API_KEY=" "%KEY_FILE%" >NUL 2>NUL && SET "HAS_KEY=1"
IF NOT "%HAS_KEY%"=="0" GOTO :key_file
GOTO :ask_key

:key_env
ECHO.
ECHO [5/5] DEEPSEEK_API_KEY is already set in your environment.
CHOICE /C YN /T 10 /D N /M "Write it to the source .env as well"
IF ERRORLEVEL 2 GOTO :done_key
GOTO :ask_key

:key_file
ECHO.
ECHO [5/5] DEEPSEEK_API_KEY found in env\source\.env
CHOICE /C YN /T 10 /D N /M "Replace it"
IF ERRORLEVEL 2 GOTO :done_key

:ask_key
ECHO.
ECHO DeepSeek API key is required for the agent to work.
ECHO Get one at https://platform.deepseek.com
SET "DSHAK="
SET /P "DSHAK=API key: "
IF "%DSHAK%"=="" GOTO :ask_key
SET "DSHAK=%DSHAK: =%"
IF "%DSHAK%"=="" GOTO :ask_key
IF EXIST "%KEY_FILE%" (TYPE "%KEY_FILE%" | FINDSTR /V /C:"DEEPSEEK_API_KEY=" > "%KEY_FILE%.tmp")
IF EXIST "%KEY_FILE%.tmp" MOVE /Y "%KEY_FILE%.tmp" "%KEY_FILE%" >NUL
>> "%KEY_FILE%" ECHO DEEPSEEK_API_KEY=%DSHAK%
ECHO [OK] API key saved to env\source\.env.

:done_key
ECHO.
ECHO ================================================
ECHO   Setup complete!
ECHO     - Virtual env:  env\  (Node %NODE_VERSION% + pnpm %PNPM_VERSION%)
ECHO     - dsh source:    env\source  (%SOURCE_BRANCH% branch, built)
ECHO     - API key:       env\source\.env
ECHO     - Harness data:  env\dsh-home   (DSH_HOME, fully isolated)
ECHO     - Web UI:        http://127.0.0.1:3080
ECHO   Next: double-click start_dsh.bat to launch.
ECHO   (To update later, run this script again.)
ECHO ================================================
ECHO.
PAUSE
EXIT /B 0

REM ---------------------------------------------------------------
REM  Failure handlers
REM ---------------------------------------------------------------
:node_download_fail
ECHO [ERROR] Could not download Node.js from either source.
IF EXIST "%DSH_ENV%\download.err" TYPE "%DSH_ENV%\download.err"
ECHO   Check your network / firewall / proxy, then run this script again.
PAUSE
EXIT /B 1

:node_extract_fail
ECHO [ERROR] Extraction failed. The downloaded file may be corrupt.
ECHO   Delete env\ and run this script again.
PAUSE
EXIT /B 1

:node_rename_fail
ECHO [ERROR] Could not finalize the Node runtime. Close any open server
ECHO   window, e.g. start_dsh.bat, and run this script again.
PAUSE
EXIT /B 1

:pnpm_fail
ECHO [ERROR] pnpm is not usable. Delete env\ and run this script again.
PAUSE
EXIT /B 1

:source_download_fail
ECHO [ERROR] Source download failed. Check your network, then run this script again.
ECHO   Tip: manually download the source zip from
ECHO   https://github.com/deepseek-ai/deepseek-harness
ECHO   Use "Code - Download ZIP" for the %SOURCE_BRANCH% branch; save it as
ECHO   env\source.zip , then run this script again.
PAUSE
EXIT /B 1

:source_extract_fail
ECHO [ERROR] Source extraction failed. Delete env\ and run this script again.
PAUSE
EXIT /B 1

:source_rename_fail
ECHO [ERROR] Could not finalize the source folder.
PAUSE
EXIT /B 1

:source_merge_fail
ECHO [ERROR] Could not merge the new source files.
PAUSE
EXIT /B 1

:bin_missing
ECHO [ERROR] Build finished but the CLI output is missing. Run this script again.
PAUSE
EXIT /B 1

:install_fail
ECHO [ERROR] pnpm install failed. Check your network connection.
ECHO   Tip: switch to a mirror registry with:
ECHO   pnpm config set registry https://registry.npmmirror.com
CD /D "%~dp0"
PAUSE
EXIT /B 1

:build_fail
ECHO [ERROR] Build failed. If the machine ran out of memory, retry with:
ECHO   SET NODE_OPTIONS=--max-old-space-size=4096
ECHO   then run this script again (existing steps are skipped).
CD /D "%~dp0"
PAUSE
EXIT /B 1

REM ---------------------------------------------------------------
REM  Subroutines
REM ---------------------------------------------------------------
:download_file
REM %~1 = URL, %~2 = destination path, %~3 = source label.
SET "DL_OK=0"
SET "ZIP_SIZE=0"
IF EXIST "%~2" DEL /Q "%~2" >NUL 2>NUL
ECHO   Downloading from %~3 ...
WHERE curl >NUL 2>NUL
IF NOT ERRORLEVEL 1 GOTO :dl_curl
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%~1' -OutFile '%~2' -UseBasicParsing -TimeoutSec 900 } catch { exit 1 }" >"%DSH_ENV%\download.err" 2>&1
IF NOT ERRORLEVEL 1 SET "DL_OK=1"
GOTO :dl_check
:dl_curl
curl -L --fail --connect-timeout 15 --max-time 900 -o "%~2" "%~1" 2>"%DSH_ENV%\download.err"
IF NOT ERRORLEVEL 1 SET "DL_OK=1"
:dl_check
IF "%DL_OK%"=="1" FOR %%F IN ("%~2") DO SET "ZIP_SIZE=%%~zF"
IF "%ZIP_SIZE%" GTR "1000000" EXIT /B 0
EXIT /B 1

:download_zip
REM %~1 = destination zip path.
SET "DL_OK=0"
SET "ZIP_SIZE=0"
IF EXIST "%~1" DEL /Q "%~1" >NUL 2>NUL
ECHO   Downloading source archive from GitHub ...
WHERE curl >NUL 2>NUL
IF NOT ERRORLEVEL 1 GOTO :dz_curl
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri 'https://codeload.github.com/deepseek-ai/deepseek-harness/zip/refs/heads/%SOURCE_BRANCH%' -OutFile '%~1' -UseBasicParsing -TimeoutSec 900 } catch { exit 1 }" >"%DSH_ENV%\download.err" 2>&1
IF NOT ERRORLEVEL 1 SET "DL_OK=1"
GOTO :dz_check
:dz_curl
curl -L --fail --connect-timeout 15 --max-time 900 -o "%~1" "https://codeload.github.com/deepseek-ai/deepseek-harness/zip/refs/heads/%SOURCE_BRANCH%" 2>"%DSH_ENV%\download.err"
IF NOT ERRORLEVEL 1 SET "DL_OK=1"
:dz_check
IF "%DL_OK%"=="1" FOR %%F IN ("%~1") DO SET "ZIP_SIZE=%%~zF"
IF "%ZIP_SIZE%" GTR "1000000" EXIT /B 0
EXIT /B 1

:extract_zip
REM %~1 = zip path, %~2 = destination directory.
tar -xf "%~1" -C "%~2"
IF ERRORLEVEL 1 powershell -NoProfile -Command "Expand-Archive -Path '%~1' -DestinationPath '%~2' -Force"
IF NOT EXIST "%~2\%ZIP_DIR_NAME%\package.json" EXIT /B 1
EXIT /B 0
