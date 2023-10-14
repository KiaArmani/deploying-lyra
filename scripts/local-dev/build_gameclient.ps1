param (
    [string]$platform = "Win64"
)

$UNREAL_ROOT = $ENV:UNREAL_ROOT # Feel free to replace with environment variables using $ENV:UNREAL_ROOT
$PROJECT_ROOT = $ENV:PROJECT_ROOT
$PROJECT_NAME = "Lyra"
$OUTPUT_ROOT = "$PROJECT_ROOT\Binaries\GameClient\"

taskkill /IM "LyraGame.exe" /F
cmd.exe /c ""$UNREAL_ROOT/Engine/Build/BatchFiles/RunUAT.bat"  -ScriptsForProject="$PROJECT_ROOT\$PROJECT_NAME.uproject" Turnkey -command=VerifySdk -platform=$platform -UpdateIfNeeded -EditorIO -EditorIOPort=58157  -project="$PROJECT_ROOT/$PROJECT_NAME.uproject" BuildCookRun -nop4 -utf8output -nocompileeditor -skipbuildeditor -cook  -project="$PROJECT_ROOT/$PROJECT_NAME.uproject" -target=LyraGame  -unrealexe="$UNREAL_ROOT\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" -platform=Win64 -stage -archive -package -build -pak -iostore -compressed -prereqs -archivedirectory="$OUTPUT_ROOT" -manifests -clientconfig=Development" -nocompile -nocompileuat