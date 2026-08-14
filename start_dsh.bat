@ECHO OFF
CHCP 65001 >NUL
TITLE DeepSeek Harness - Web UI (source mode)
CD /D "%~dp0"

REM Runs dsh from the source tree via pnpm (tsx). The CLI boots from
REM source, but the web profile additionally requires built artifacts
REM (package lib bundles + apps\web\dist frontend) - the checks below
REM verify them; run setup_dsh.bat to build if they are missing.
REM Environment variables are set here instead of CALLing env\ENV.bat
REM to stay compatible with every cmd version.

REM Default port; override with:  start_dsh.bat <port>
SET "DSH_PORT=3080"
IF NOT "%1"=="" SET "DSH_PORT=%1"

SET "DSH_ENV=%~dp0env"
SET "DSH_HOME=%DSH_ENV%\dsh-home"
SET "DSH_SOURCE=%DSH_ENV%\source"
SET "PATH=%DSH_ENV%\node;%DSH_ENV%;%DSH_ENV%\node_modules\.bin;%PATH%"

ECHO.
ECHO ================================================
ECHO   DeepSeek Harness - Web UI (virtual env)
ECHO ================================================
ECHO.

IF NOT EXIST "%DSH_SOURCE%\package.json" GOTO :err_source
IF NOT EXIST "%DSH_SOURCE%\apps\web\dist\index.html" GOTO :err_web_dist
IF NOT EXIST "%DSH_SOURCE%\apps\cli\lib\bin.js" GOTO :err_cli_lib

SET "PNPM_BIN=%DSH_ENV%\pnpm.cmd"
IF NOT EXIST "%PNPM_BIN%" SET "PNPM_BIN=%DSH_ENV%\node_modules\.bin\pnpm.cmd"
IF NOT EXIST "%PNPM_BIN%" GOTO :err_pnpm

SET "HAS_KEY=0"
IF EXIST "%DSH_SOURCE%\.env" FINDSTR /C:"DEEPSEEK_API_KEY=" "%DSH_SOURCE%\.env" >NUL 2>NUL && SET "HAS_KEY=1"
IF NOT "%HAS_KEY%"=="0" GOTO :key_ok
IF NOT "%DEEPSEEK_API_KEY%"=="" GOTO :key_ok
ECHO.
ECHO [WARN] No DEEPSEEK_API_KEY found in env\source\.env or the environment.
ECHO         The agent will not be able to call models.
ECHO         Run setup_dsh.bat to configure a key.
CHOICE /C YN /T 10 /D N /M "Start anyway"
IF ERRORLEVEL 2 EXIT /B 1
:key_ok

ECHO.
ECHO [OK] dsh source ready - starting in source mode.
ECHO Starting dsh web at http://127.0.0.1:%DSH_PORT% ...
ECHO Harness data: %DSH_HOME%
ECHO Keep this window open. Press Ctrl+C to stop the server.
ECHO.

REM Best-effort: wait until the page AND its WebSocket endpoint are both
REM ready, then open the browser (probes for up to 60 seconds). The web UI
REM shows "Failed to load plugins" if it boots before the endpoint exists.
START "" /B POWERSHELL -NoProfile -ExecutionPolicy Bypass -Command "$u='http://127.0.0.1:%DSH_PORT%/'; $w=[uri]'ws://127.0.0.1:%DSH_PORT%/api/events.mux'; for($i=0;$i -lt 60;$i++){ try { $r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){ $c=New-Object System.Net.WebSockets.ClientWebSocket; try { $c.ConnectAsync($w,[System.Threading.CancellationToken]::None).GetAwaiter().GetResult(); if($c.State -eq [System.Net.WebSockets.WebSocketState]::Open){ Start-Process $u; break } } catch { } finally { if($c){ $c.Dispose() } } } } catch { }; Start-Sleep -Seconds 1 }"

REM Run the server from the source tree (Ctrl+C to stop).
CD /D "%DSH_SOURCE%"
IF NOT "%DSH_PORT%"=="3080" GOTO :start_custom_port
cmd /c ""%PNPM_BIN%" dsh web"
GOTO :start_done

:start_custom_port
cmd /c ""%PNPM_BIN%" dsh web --port %DSH_PORT%"

:start_done
ECHO.
ECHO dsh exited with code %ERRORLEVEL%.
PAUSE
GOTO :eof

:err_source
ECHO [ERROR] dsh source not found at %DSH_SOURCE%
ECHO   Run setup_dsh.bat first.
PAUSE
EXIT /B 1

:err_web_dist
ECHO [ERROR] The web UI is not built yet.
ECHO   apps\web\dist\index.html is missing. The web profile needs built
ECHO   artifacts: the package lib bundles plus the frontend dist.
ECHO   Run setup_dsh.bat again to finish the build (it skips finished steps).
PAUSE
EXIT /B 1

:err_cli_lib
ECHO [ERROR] The CLI bundle is not built yet.
ECHO   apps\cli\lib\bin.js is missing. Run setup_dsh.bat again to finish
ECHO   the build (it skips finished steps).
PAUSE
EXIT /B 1

:err_pnpm
ECHO [ERROR] pnpm.cmd not found in the virtual environment.
ECHO   Run setup_dsh.bat first.
PAUSE
EXIT /B 1
