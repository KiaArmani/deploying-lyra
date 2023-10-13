$PSScriptRoot/build_gameserver.ps1
docker build -t registry/lyra/server:dev .
docker push registry/lyra/server:dev
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');