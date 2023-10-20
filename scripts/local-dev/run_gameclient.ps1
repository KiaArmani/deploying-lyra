param (
    [string]$context = "Context_1"
)

$PROJECT_ROOT = $ENV:PROJECT_ROOT
$OUTPUT_ROOT = "$PROJECT_ROOT\Binaries\GameClient\"

& $OUTPUT_ROOT/Windows/LyraGame.exe -AUTH_LOGIN="localhost:6300" -AUTH_PASSWORD="$context" -AUTH_TYPE="Developer"