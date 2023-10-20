$PROJECT_ROOT = $ENV:PROJECT_ROOT
$OUTPUT_ROOT = "$PROJECT_ROOT\Binaries\GameServer"
cd $OUTPUT_ROOT

docker build -t registry/lyra/server:dev .
docker push registry/lyra/server:dev
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');