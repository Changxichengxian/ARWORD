param([switch]$Release, [switch]$Offline)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
if ($Release -and -not (Test-Path -LiteralPath 'signing.properties')) {
    throw 'Release signing is missing. Restore the private signing backup, or create your own signing.properties.'
}
if (-not $env:JAVA_HOME) { throw 'Set JAVA_HOME to JDK 17 or 21 before building.' }
if (-not (Test-Path -LiteralPath 'local.properties')) {
    $sdkDirectory = $env:ANDROID_SDK_ROOT
    if (-not $sdkDirectory) { $sdkDirectory = $env:ANDROID_HOME }
    if (-not $sdkDirectory -and $env:LOCALAPPDATA) {
        $sdkDirectory = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
    }
    if (-not $sdkDirectory -or -not (Test-Path -LiteralPath $sdkDirectory)) {
        throw 'Set ANDROID_SDK_ROOT to an installed Android SDK.'
    }
    $sdkProperty = 'sdk.dir=' + $sdkDirectory.Replace('\','/')
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'local.properties'), $sdkProperty, [Text.UTF8Encoding]::new($false))
}
$buildArguments = @($(if ($Release) { 'assembleRelease' } else { 'assembleDebug' }))
if ($Offline) { $buildArguments += '--offline' }
& .\gradlew.bat @buildArguments
exit $LASTEXITCODE
