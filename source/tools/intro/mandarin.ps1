param([Parameter(Mandatory)][string]$Story, [Parameter(Mandatory)][string]$Destination)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $voice = $speaker.GetInstalledVoices() | Where-Object {
        $_.Enabled -and $_.VoiceInfo.Culture.Name -eq 'zh-CN'
    } | Select-Object -First 1
    if (-not $voice) { throw 'Install the Windows Mandarin (zh-CN) speech voice.' }
    $speaker.SelectVoice($voice.VoiceInfo.Name)
    foreach ($scene in (Get-Content -LiteralPath $Story -Encoding UTF8 -Raw | ConvertFrom-Json)) {
        if (-not $scene.line) { continue }
        $speaker.SetOutputToWaveFile((Join-Path $Destination ($scene.shot + '.wav')))
        $speaker.Speak([string]$scene.line)
        $speaker.SetOutputToNull()
    }
} finally { $speaker.Dispose() }
