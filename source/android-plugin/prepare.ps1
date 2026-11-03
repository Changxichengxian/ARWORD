param(
    [Parameter(Mandatory=$true)][string]$Stage,
    [Parameter(Mandatory=$true)][string]$Templates,
    [Parameter(Mandatory=$true)][string]$AndroidSdk,
    [Parameter(Mandatory=$true)][string]$UpdateRepository
)
$ErrorActionPreference='Stop'
$Stage=(Resolve-Path -LiteralPath $Stage).Path
$template=Join-Path $Templates 'android_source.zip'
if(-not (Test-Path -LiteralPath $template)){throw '缺少 Godot 4.5.1 官方 android_source.zip，请放在 Templates 目录。'}
$template=(Resolve-Path -LiteralPath $template).Path
$hash=(Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash.ToLowerInvariant()
if($hash -ne '1ca4af13143abc7ee9cf56e2790e51213ed8a3905d1cffcb7babe1a2537c338f'){
    throw 'Android 源模板与已核验的 Godot 4.5.1 官方版本不一致。'
}
$android=Join-Path $Stage 'android'
$build=Join-Path $android 'build'
if(Test-Path -LiteralPath $build){throw 'Android staging 已存在；请使用新的独立构建目录。'}
New-Item -ItemType Directory -Path $android -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($template,$build)
$javaPkg = Join-Path $build 'src/io/github/changxichengxian/arword'
New-Item -ItemType Directory -Force -Path $javaPkg | Out-Null
foreach($name in @('PlanetUpdates.java','ApkDelta.java','UpdateFiles.java','SafeViewport.java')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('src/io/github/changxichengxian/arword/' + $name)) -Destination $javaPkg
}
if($UpdateRepository -notmatch '^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$'){throw '更新仓库必须写成 owner/repo。'}
$channel='package io.github.changxichengxian.arword; final class UpdateChannel { static final String REPO="'+$UpdateRepository+'"; }'
[IO.File]::WriteAllText((Join-Path $javaPkg 'UpdateChannel.java'),$channel,[Text.UTF8Encoding]::new($false))
$resourceDir = Join-Path $build 'res/xml'
New-Item -ItemType Directory -Force -Path $resourceDir | Out-Null
[IO.File]::WriteAllText((Join-Path $resourceDir 'update_paths.xml'),'<paths><cache-path name="verified" path="planet-update/"/></paths>',[Text.UTF8Encoding]::new($false))
$manifest=Join-Path $build 'AndroidManifest.xml'
$text=Get-Content -LiteralPath $manifest -Raw
$entry='<meta-data android:name="org.godotengine.plugin.v2.PlanetUpdates" android:value="io.github.changxichengxian.arword.PlanetUpdates" /><provider android:name="io.github.changxichengxian.arword.UpdateFiles" android:authorities="${applicationId}.updates" android:exported="false" android:grantUriPermissions="true"><meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/update_paths"/></provider>'
if(-not $text.Contains('</application>')){throw 'Android 模板缺少 application。'}
$text=$text.Replace('</application>',"        $entry`n    </application>")
$text=$text.Replace('</manifest>','<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/></manifest>')
[IO.File]::WriteAllText($manifest,$text,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $android '.build_version'),'4.5.1.stable',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $android '.gdignore'),'', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $build 'local.properties'),('sdk.dir='+$AndroidSdk.Replace('\','/')+"`n"),[Text.UTF8Encoding]::new($false))
# Keep the official engine and library versions. Compile against installed SDK 36
# when 35 is absent; target/min SDK remain the official 35/24 values.
$config=Join-Path $build 'config.gradle';$settings=Get-Content -LiteralPath $config -Raw
if(-not (Test-Path -LiteralPath (Join-Path $AndroidSdk 'platforms/android-35/android.jar'))){
    if(-not (Test-Path -LiteralPath (Join-Path $AndroidSdk 'platforms/android-36/android.jar'))){throw '需要 Android SDK 平台 35 或 36。'}
    $settings=$settings.Replace('compileSdk         : 35','compileSdk         : 36')
}
if(-not (Test-Path -LiteralPath (Join-Path $AndroidSdk 'build-tools/35.0.0/aapt2.exe'))){
    if(-not (Test-Path -LiteralPath (Join-Path $AndroidSdk 'build-tools/36.1.0/aapt2.exe'))){throw '需要 Android build-tools 35.0.0 或 36.1.0。'}
    $settings=$settings.Replace("buildTools         : '35.0.0'","buildTools         : '36.1.0'")
}
[IO.File]::WriteAllText($config,$settings,[Text.UTF8Encoding]::new($false))
# This module contains Java only and uses the already-built official native
# libraries. No NDK compilation/stripping is needed for a document picker.
$gradle=Join-Path $build 'build.gradle';$gradleText=Get-Content -LiteralPath $gradle -Raw
$gradleText=$gradleText.Replace('    ndkVersion versions.ndkVersion','')
[IO.File]::WriteAllText($gradle,$gradleText,[Text.UTF8Encoding]::new($false))
Add-Content -LiteralPath (Join-Path $build 'gradle.properties') -Value "`ndoNotStrip=true`norg.gradle.workers.max=4`norg.gradle.daemon=false" -Encoding utf8
[pscustomobject]@{godot='4.5.1.stable';android_source_sha256=$hash;registration='org.godotengine.plugin.v2.PlanetUpdates';update_repository=$UpdateRepository;source='Godot official 4.5.1 export templates'} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path (Split-Path $Stage) 'android-build-dependencies.json') -Encoding utf8
Write-Host 'Android 版本检查与差异更新已加入独立构建目录。'
