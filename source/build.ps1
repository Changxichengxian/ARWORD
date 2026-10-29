param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$Templates,
    [string]$AndroidSdk=$env:ANDROID_SDK_ROOT,
    [string]$JavaHome=$env:JAVA_HOME,
    [string]$SigningProperties="",
    [string]$OutputDirectory=(Join-Path $PSScriptRoot "build")
)
$ErrorActionPreference="Stop"
$projectRoot=$PSScriptRoot
foreach($requiredPath in @($Godot,$Templates,$AndroidSdk,$JavaHome)) {
    if(-not $requiredPath -or -not (Test-Path -LiteralPath $requiredPath)){throw "找不到构建依赖：$requiredPath"}
}
$Godot=(Resolve-Path -LiteralPath $Godot).Path
$Templates=(Resolve-Path -LiteralPath $Templates).Path
$AndroidSdk=(Resolve-Path -LiteralPath $AndroidSdk).Path
$JavaHome=(Resolve-Path -LiteralPath $JavaHome).Path
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory=(Resolve-Path -LiteralPath $OutputDirectory).Path
$buildRoot=Join-Path $OutputDirectory ("build-"+[guid]::NewGuid().ToString('N'))
$stage=Join-Path $buildRoot "project"
$engine=Join-Path $buildRoot "engine"
New-Item -ItemType Directory -Force -Path $stage,$engine,(Join-Path $engine "editor_data") | Out-Null
foreach($name in @("assets","scripts","project.godot","main.tscn","export_presets.cfg")) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $stage -Recurse
}
$inputs=Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
    [pscustomobject]@{path=$_.FullName.Substring($stage.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
}
$inputs | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'source-inputs-sha256.json') -Encoding utf8
# Isolate editor settings so building does not rewrite the developer's existing Godot settings.
$binaryDir=Split-Path $Godot
Get-ChildItem -LiteralPath $binaryDir -Filter 'Godot*win64*.exe' | Copy-Item -Destination $engine
$engineExe=Join-Path $engine (Split-Path $Godot -Leaf)
if(-not (Test-Path -LiteralPath $engineExe)){Copy-Item -LiteralPath $Godot -Destination $engineExe}
New-Item -ItemType File -Path (Join-Path $engine '_sc_') | Out-Null
$javaSlash=$JavaHome.Replace('\','/')
$sdkSlash=$AndroidSdk.Replace('\','/')
@"
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/java_sdk_path = "$javaSlash"
export/android/android_sdk_path = "$sdkSlash"
export/android/shutdown_adb_on_exit = false
"@ | Set-Content -LiteralPath (Join-Path $engine 'editor_data/editor_settings-4.5.tres') -Encoding utf8
$preset=Get-Content -LiteralPath (Join-Path $stage 'export_presets.cfg') -Raw
foreach($kind in @('debug','release')) {
    $template=Join-Path $Templates ("android_"+$kind+".apk")
    if(-not (Test-Path -LiteralPath $template)){throw "缺少 Android 导出模板：$template"}
    $line='custom_template/'+$kind+'="'+$template.Replace('\','/')+'"'
    $preset=[regex]::Replace($preset,'(?m)^custom_template/'+$kind+'=.*$',$line)
}
$preset | Set-Content -LiteralPath (Join-Path $stage 'export_presets.cfg') -Encoding utf8
$log=Join-Path $OutputDirectory 'build.log'
$unsigned=Join-Path $buildRoot 'unsigned.apk'
$aligned=Join-Path $buildRoot 'aligned.apk'
$apk=Join-Path $OutputDirectory '词屿-0.7.0.apk'
Write-Host '导入三维资源……'
& $engineExe --headless --editor --path $stage --import *> $log
if($LASTEXITCODE -ne 0){throw "导入失败，请看 $log"}
Write-Host '构建 Android 应用……'
& $engineExe --headless --path $stage --export-release Android $unsigned *>> $log
if($LASTEXITCODE -ne 0){throw "构建失败，请看 $log"}
$buildTools=Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'build-tools') -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if(-not $buildTools){throw '找不到 Android build-tools'}
& (Join-Path $buildTools.FullName 'zipalign.exe') -f -P 16 4 $unsigned $aligned *>> $log
if($LASTEXITCODE -ne 0){throw "APK 对齐失败，请看 $log"}
$java=Join-Path $JavaHome 'bin/java.exe'
if(-not $SigningProperties){throw "已构建未签名文件 $aligned。请提供自己的 SigningProperties 以生成可安装 APK。个人签名文件不随源码分发。"}
$SigningProperties=(Resolve-Path -LiteralPath $SigningProperties).Path
$sign=@{}
foreach($line in (Get-Content -LiteralPath $SigningProperties)) {
    if($line -match '^\s*([^#=]+)=(.*)$'){$sign[$matches[1].Trim()]=$matches[2].Trim()}
}
foreach($key in @('storeFile','storePassword','keyAlias','keyPassword')){if(-not $sign.ContainsKey($key)){throw "签名配置缺少 $key"}}
$store=$sign.storeFile
if(-not [IO.Path]::IsPathRooted($store)){$store=Join-Path (Split-Path $SigningProperties) $store}
$env:WF_BUILD_STORE_PASS=$sign.storePassword
$env:WF_BUILD_KEY_PASS=$sign.keyPassword
try {
    & $java -jar (Join-Path $buildTools.FullName 'lib/apksigner.jar') sign --ks $store --ks-key-alias $sign.keyAlias --ks-pass env:WF_BUILD_STORE_PASS --key-pass env:WF_BUILD_KEY_PASS --out $apk $aligned *>> $log
    if($LASTEXITCODE -ne 0){throw "签名失败，请看 $log"}
    & $java -jar (Join-Path $buildTools.FullName 'lib/apksigner.jar') verify --verbose $apk *>> $log
    if($LASTEXITCODE -ne 0){throw "签名验证失败，请看 $log"}
} finally {
    Remove-Item Env:WF_BUILD_STORE_PASS,Env:WF_BUILD_KEY_PASS -ErrorAction SilentlyContinue
}
$hash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
($hash+'  '+(Split-Path $apk -Leaf)) | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding utf8
# Only remove the fresh build directory we created directly inside the selected output folder.
$resolvedBuild=(Resolve-Path -LiteralPath $buildRoot).Path
if((Split-Path $resolvedBuild) -eq $OutputDirectory -and (Split-Path $resolvedBuild -Leaf) -match '^build-[a-f0-9]{32}$') {
    Remove-Item -LiteralPath $resolvedBuild -Recurse -Force
}
Write-Host "完成：$apk"
