@echo off
setlocal EnableDelayedExpansion
title Remote Control - Build Standalone EXE
color 0B

echo ============================================================
echo   Windows Remote Control - Build Standalone .EXE
echo ============================================================
echo.

:: Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed or not in PATH.
    echo.
    echo Please install Python from https://www.python.org/downloads/
    echo IMPORTANT: Check the box "Add Python to PATH" during installation.
    echo.
    pause
    exit /b 1
)

echo [OK] Python found
python --version
echo.

:: Create project folder
set "PROJECT_DIR=%~dp0RemoteControl"
if not exist "%PROJECT_DIR%" mkdir "%PROJECT_DIR%"
cd /d "%PROJECT_DIR%"

echo [OK] Working directory: %PROJECT_DIR%
echo.

:: Create requirements.txt
echo Creating requirements.txt...
(
echo flask
echo flask-socketio
echo mss
echo pillow
echo pyautogui
echo eventlet
echo pyinstaller
) > requirements.txt

:: Create app.py
echo Creating app.py...
(
echo import io
echo import base64
echo import time
echo import threading
echo from flask import Flask, render_template_string, request
echo from flask_socketio import SocketIO, emit
echo import mss
echo import pyautogui
echo from PIL import Image
echo.
echo # ================== CONFIG ==================
echo PASSWORD = "changeme"          # ^<-- Change this password!
echo PORT = 5000
echo QUALITY = 50                   # JPEG quality ^(30-70 is good^)
echo FPS = 8                        # Frames per second
echo # ============================================
echo.
echo app = Flask^(__name__^)
echo app.config['SECRET_KEY'] = 'remote-control-secret'
echo socketio = SocketIO^(app, cors_allowed_origins="*", async_mode='eventlet'^)
echo.
echo authenticated_clients = set^(^)
echo.
echo HTML = """
echo ^<!DOCTYPE html^>
echo ^<html^>
echo ^<head^>
echo     ^<title^>Remote Control^</title^>
echo     ^<style^>
echo         body { margin: 0; background: #111; color: white; font-family: Arial; overflow: hidden; }
echo         #screen { width: 100vw; height: 100vh; object-fit: contain; cursor: none; }
echo         #login { position: absolute; top: 50%%; left: 50%%; transform: translate^(-50%%, -50%%^);
echo                  background: #222; padding: 30px; border-radius: 10px; text-align: center; }
echo         input, button { padding: 10px; margin: 5px; font-size: 16px; }
echo         #status { position: absolute; top: 10px; left: 10px; background: rgba^(0,0,0,0.7^); padding: 5px 10px; border-radius: 5px; }
echo     ^</style^>
echo ^</head^>
echo ^<body^>
echo     ^<div id="login"^>
echo         ^<h2^>Remote Control^</h2^>
echo         ^<input type="password" id="password" placeholder="Password" autofocus^>
echo         ^<br^>
echo         ^<button onclick="login()"^>Connect^</button^>
echo         ^<p id="error" style="color: #f55;"^>^</p^>
echo     ^</div^>
echo.
echo     ^<div id="status" style="display:none;"^>Connected^</div^>
echo     ^<img id="screen" style="display:none;"^>
echo.
echo     ^<script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.5.4/socket.io.min.js"^>^</script^>
echo     ^<script^>
echo         const socket = io^(^);
echo         let authenticated = false;
echo         const screen = document.getElementById^('screen'^);
echo         const loginDiv = document.getElementById^('login'^);
echo         const status = document.getElementById^('status'^);
echo.
echo         function login^(^) {
echo             const pwd = document.getElementById^('password'^).value;
echo             socket.emit^('auth', { password: pwd }^);
echo         }
echo.
echo         document.getElementById^('password'^).addEventListener^('keypress', e =^> {
echo             if ^(e.key === 'Enter'^) login^(^);
echo         }^);
echo.
echo         socket.on^('auth_result', data =^> {
echo             if ^(data.success^) {
echo                 authenticated = true;
echo                 loginDiv.style.display = 'none';
echo                 screen.style.display = 'block';
echo                 status.style.display = 'block';
echo                 socket.emit^('start_stream'^);
echo             } else {
echo                 document.getElementById^('error'^).innerText = 'Wrong password';
echo             }
echo         }^);
echo.
echo         socket.on^('frame', data =^> {
echo             screen.src = 'data:image/jpeg;base64,' + data;
echo         }^);
echo.
echo         screen.addEventListener^('mousemove', e =^> {
echo             if ^(!authenticated^) return;
echo             const rect = screen.getBoundingClientRect^(^);
echo             const x = ^(e.clientX - rect.left^) / rect.width;
echo             const y = ^(e.clientY - rect.top^) / rect.height;
echo             socket.emit^('mouse_move', { x, y }^);
echo         }^);
echo.
echo         screen.addEventListener^('mousedown', e =^> {
echo             if ^(!authenticated^) return;
echo             socket.emit^('mouse_click', { button: e.button === 2 ? 'right' : 'left' }^);
echo         }^);
echo.
echo         screen.addEventListener^('contextmenu', e =^> e.preventDefault^(^)^);
echo.
echo         screen.addEventListener^('wheel', e =^> {
echo             if ^(!authenticated^) return;
echo             socket.emit^('mouse_scroll', { delta: e.deltaY ^> 0 ? -1 : 1 }^);
echo         }^);
echo.
echo         document.addEventListener^('keydown', e =^> {
echo             if ^(!authenticated^) return;
echo             e.preventDefault^(^);
echo             socket.emit^('key', { key: e.key, type: 'down' }^);
echo         }^);
echo.
echo         document.addEventListener^('keyup', e =^> {
echo             if ^(!authenticated^) return;
echo             socket.emit^('key', { key: e.key, type: 'up' }^);
echo         }^);
echo     ^</script^>
echo ^</body^>
echo ^</html^>
echo """
echo.
echo @app.route^('/'^)
echo def index^(^):
echo     return render_template_string^(HTML^)
echo.
echo @socketio.on^('auth'^)
echo def handle_auth^(data^):
echo     if data.get^('password'^) == PASSWORD:
echo         authenticated_clients.add^(request.sid^)
echo         emit^('auth_result', {'success': True}^)
echo         print^(f"[+] Client authenticated: {request.sid}"^)
echo     else:
echo         emit^('auth_result', {'success': False}^)
echo.
echo @socketio.on^('start_stream'^)
echo def start_stream^(^):
echo     if request.sid not in authenticated_clients:
echo         return
echo     def stream^(^):
echo         with mss.mss^(^) as sct:
echo             monitor = sct.monitors[1]
echo             while request.sid in authenticated_clients:
echo                 try:
echo                     img = sct.grab^(monitor^)
echo                     im = Image.frombytes^("RGB", img.size, img.bgra, "raw", "BGRX"^)
echo                     buffer = io.BytesIO^(^)
echo                     im.save^(buffer, format="JPEG", quality=QUALITY^)
echo                     frame = base64.b64encode^(buffer.getvalue^(^)^).decode^('utf-8'^)
echo                     socketio.emit^('frame', frame, room=request.sid^)
echo                     time.sleep^(1 / FPS^)
echo                 except Exception as e:
echo                     print^("Stream error:", e^)
echo                     break
echo     threading.Thread^(target=stream, daemon=True^).start^(^)
echo.
echo @socketio.on^('mouse_move'^)
echo def mouse_move^(data^):
echo     if request.sid not in authenticated_clients:
echo         return
echo     w, h = pyautogui.size^(^)
echo     x = int^(data['x'] * w^)
echo     y = int^(data['y'] * h^)
echo     pyautogui.moveTo^(x, y^)
echo.
echo @socketio.on^('mouse_click'^)
echo def mouse_click^(data^):
echo     if request.sid not in authenticated_clients:
echo         return
echo     if data['button'] == 'right':
echo         pyautogui.rightClick^(^)
echo     else:
echo         pyautogui.click^(^)
echo.
echo @socketio.on^('mouse_scroll'^)
echo def mouse_scroll^(data^):
echo     if request.sid not in authenticated_clients:
echo         return
echo     pyautogui.scroll^(data['delta'] * 3^)
echo.
echo @socketio.on^('key'^)
echo def handle_key^(data^):
echo     if request.sid not in authenticated_clients:
echo         return
echo     key = data['key']
echo     key_map = {
echo         'Enter': 'enter', 'Backspace': 'backspace', 'Tab': 'tab',
echo         'Escape': 'esc', 'ArrowUp': 'up', 'ArrowDown': 'down',
echo         'ArrowLeft': 'left', 'ArrowRight': 'right', 'Control': 'ctrl',
echo         'Alt': 'alt', 'Shift': 'shift', 'Meta': 'win', 'Delete': 'delete'
echo     }
echo     key = key_map.get^(key, key.lower^(^) if len^(key^) == 1 else key.lower^(^)^)
echo.
echo     try:
echo         if data['type'] == 'down':
echo             pyautogui.keyDown^(key^)
echo         else:
echo             pyautogui.keyUp^(key^)
echo     except Exception:
echo         pass
echo.
echo @socketio.on^('disconnect'^)
echo def on_disconnect^(^):
echo     authenticated_clients.discard^(request.sid^)
echo     print^(f"[-] Client disconnected: {request.sid}"^)
echo.
echo if __name__ == '__main__':
echo     print^("=" * 50^)
echo     print^("  Remote Control Server"^)
echo     print^("=" * 50^)
echo     print^(f"Password : {PASSWORD}"^)
echo     print^(f"Local    : http://127.0.0.1:{PORT}"^)
echo     print^(f"Network  : http://YOUR-IP:{PORT}"^)
echo     print^("=" * 50^)
echo     print^("Press Ctrl+C to stop"^)
echo     print^(^)
echo     pyautogui.FAILSAFE = False
echo     socketio.run^(app, host='0.0.0.0', port=PORT, debug=False^)
) > app.py

echo [OK] Files created successfully
echo.

:: Install dependencies
echo Installing required packages (this may take a couple of minutes)...
python -m pip install --upgrade pip >nul
python -m pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to install packages.
    pause
    exit /b 1
)

echo.
echo [OK] All packages installed
echo.

:: Build the standalone EXE
echo ============================================================
echo   Building standalone .EXE (this can take 1-3 minutes)...
echo ============================================================
echo.

python -m PyInstaller --onefile --noconsole --name "RemoteControl" --clean app.py

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to build the EXE.
    pause
    exit /b 1
)

echo.
echo [OK] Build completed successfully!
echo.

:: Copy the EXE to a convenient location
if exist "dist\RemoteControl.exe" (
    copy /Y "dist\RemoteControl.exe" "%~dp0RemoteControl.exe" >nul
    echo ============================================================
    echo   SUCCESS!
    echo ============================================================
    echo.
    echo Your standalone EXE is ready:
    echo.
    echo   %~dp0RemoteControl.exe
    echo.
    echo You can now copy this single file anywhere and run it.
    echo No Python installation is required on other computers.
    echo.
    echo Default password: changeme
    echo ^(You can change it by editing app.py and rebuilding^)
    echo.
    echo ----------------------------------------------------------
    echo Would you like to start the EXE now? ^(Y/N^)
    set /p START_NOW="> "
    if /i "!START_NOW!"=="Y" (
        echo.
        echo Starting RemoteControl.exe ...
        start "" "%~dp0RemoteControl.exe"
    )
) else (
    echo [ERROR] EXE was not found in the dist folder.
)

echo.
pause
