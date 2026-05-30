-- SyncFavoritos launcher (headless)
-- Runs the local Safari exporter HTTP server in the background, without hardcoded paths.

do shell script "kill -9 $(lsof -t -i:5003) 2>/dev/null || true"

-- Resolve paths relative to this .app bundle:
-- <...>/v1/mac/SyncFavoritos.app/Contents/MacOS/applet  ->  <...>/v1/mac
set appletPath to POSIX path of (path to me)
set appletDir to do shell script "dirname " & quoted form of appletPath
set macDir to do shell script "dirname " & quoted form of appletDir

set exporterPath to macDir & "/mac_exporter.py"
set logPath to macDir & "/app_launcher.log"

do shell script "nohup python3 " & quoted form of exporterPath & " --server > " & quoted form of logPath & " 2>&1 &"
