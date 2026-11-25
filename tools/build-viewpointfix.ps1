param(
    [string]$Pz = "E:\Games\SteamLibrary\steamapps\common\ProjectZomboid",
    [string]$Root = "C:\Users\Michael\Zomboid\Workshop\stay-with-me"
)

$ErrorActionPreference = "Stop"

$src = Join-Path $Root "src"
$stubs = Join-Path $Root "tools\stubs"
$out = Join-Path $Root "Contents\mods\StayWithMeViewpointFix\common\media\java\client\StayWithMeViewpointFix.jar"
$tmp = Join-Path $env:TEMP ("swmviewpointfix-" + [guid]::NewGuid().ToString("N"))
$stubOut = Join-Path $tmp "stubs"
$classOut = Join-Path $tmp "classes"

New-Item -ItemType Directory -Path $stubOut | Out-Null
New-Item -ItemType Directory -Path $classOut | Out-Null
try {
    $zbJar = Join-Path $Pz "ZombieBuddy.jar"
    if (-not (Test-Path -LiteralPath $zbJar)) {
        throw "Missing $zbJar"
    }

    $stubFiles = Get-ChildItem -LiteralPath $stubs -Recurse -Filter *.java | ForEach-Object { $_.FullName }
    if (-not $stubFiles) {
        throw "No stub sources found under $stubs"
    }
    & javac --release 17 -d $stubOut $stubFiles
    if ($LASTEXITCODE -ne 0) {
        throw "javac failed for stubs"
    }

    $files = Get-ChildItem -LiteralPath $src -Recurse -Filter *.java | ForEach-Object { $_.FullName }
    if (-not $files) {
        throw "No Java sources found under $src"
    }

    $cp = $stubOut + ";" + $zbJar
    & javac --release 17 -cp $cp -d $classOut $files
    if ($LASTEXITCODE -ne 0) {
        throw "javac failed for sources"
    }

    $outDir = Split-Path -Parent $out
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    if (Test-Path -LiteralPath $out) {
        Remove-Item -LiteralPath $out -Force
    }

    & jar --create --file $out -C $classOut .
    if ($LASTEXITCODE -ne 0) {
        throw "jar failed"
    }

    $entries = & jar --list --file $out
    if ($entries -notcontains "swmviewpointfix/Patch_CharacterLooks.class") {
        throw "Jar is missing swmviewpointfix/Patch_CharacterLooks.class"
    }
    if ($entries -notcontains "swmviewpointfix/SwmCompanion.class") {
        throw "Jar is missing swmviewpointfix/SwmCompanion.class"
    }
    if ($entries -notcontains "swmviewpointfix/Patch_VisceralStruck.class") {
        throw "Jar is missing swmviewpointfix/Patch_VisceralStruck.class"
    }
    if ($entries -notcontains "swmviewpointfix/Patch_VisceralKilled.class") {
        throw "Jar is missing swmviewpointfix/Patch_VisceralKilled.class"
    }
    if ($entries -notcontains "swmviewpointfix/Patch_VisceralCapture.class") {
        throw "Jar is missing swmviewpointfix/Patch_VisceralCapture.class"
    }

    Write-Output "Built $out"
    $entries | ForEach-Object { Write-Output $_ }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
