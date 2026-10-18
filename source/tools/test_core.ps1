param([string]$JavaRoot = $env:JAVA_HOME, [string]$JsonLibrary)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if (-not $JavaRoot) {
    $javacCommand = Get-Command javac -ErrorAction SilentlyContinue
    if ($javacCommand) { $JavaRoot = Split-Path -Parent (Split-Path -Parent $javacCommand.Source) }
}
if (-not $JavaRoot -or -not (Test-Path (Join-Path $JavaRoot 'bin/javac.exe'))) {
    throw 'Set JAVA_HOME to JDK 17 or 21, or pass -JavaRoot.'
}
if (-not $JsonLibrary) {
    $cachedJson = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.gradle/caches/modules-2/files-2.1/org.json/json') -Filter 'json-*.jar' -Recurse -ErrorAction SilentlyContinue |
        Where-Object Name -NotMatch 'sources|javadoc' | Select-Object -First 1
    if ($cachedJson) { $JsonLibrary = $cachedJson.FullName }
}
if (-not $JsonLibrary -or -not (Test-Path -LiteralPath $JsonLibrary)) {
    throw 'Pass -JsonLibrary PATH to org.json:json (tested with 20180813). This tool does not download dependencies.'
}
$classes=Join-Path $projectRoot 'tests/classes'
New-Item -ItemType Directory -Force -Path $classes | Out-Null
& (Join-Path $javaRoot 'bin/javac.exe') -encoding UTF-8 -cp $jsonLibrary -d $classes (Join-Path $projectRoot 'app/src/main/java/com/wordfrontier/app/Game.java') (Join-Path $projectRoot 'app/src/main/java/com/wordfrontier/app/Adaptive.java') (Join-Path $projectRoot 'tests/CoreTest.java') (Join-Path $projectRoot 'tests/V2CoreTest.java')
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
& (Join-Path $javaRoot 'bin/java.exe') -cp "$classes;$jsonLibrary" CoreTest
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
& (Join-Path $javaRoot 'bin/java.exe') -cp "$classes;$jsonLibrary" V2CoreTest
exit $LASTEXITCODE
