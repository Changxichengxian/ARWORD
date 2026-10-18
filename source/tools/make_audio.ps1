param([string]$FfmpegPath = 'ffmpeg', [string[]]$Ids = @(), [string]$IdPrefix = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$projectRoot = Split-Path -Parent $PSScriptRoot
$audioItems = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'audio-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
$speaker.SelectVoice('Microsoft Zira Desktop')
$speaker.Rate = -1
$speaker.Volume = 100
$audioTemp = Join-Path $PSScriptRoot 'speech-temp.wav'
try {
  foreach ($entry in $audioItems) {
    if ($Ids.Count -gt 0 -and $entry.id -notin $Ids) { continue }
    if ($IdPrefix -and -not $entry.id.StartsWith($IdPrefix)) { continue }
    $destinationPath = Join-Path (Join-Path $projectRoot 'app/src/main/assets') $entry.path
    $speaker.SetOutputToWaveFile($audioTemp)
    $speaker.Speak($entry.text)
    $speaker.SetOutputToNull()
    & $ffmpegPath -hide_banner -loglevel error -y -i $audioTemp -ac 1 -ar 22050 -codec:a libmp3lame -b:a 64k $destinationPath
    if ($LASTEXITCODE -ne 0) { throw "Audio encoding failed: $($entry.id)" }
    Write-Output "Rendered $($entry.id)"
  }
} finally {
  $speaker.Dispose()
  if (Test-Path -LiteralPath $audioTemp) { Remove-Item -LiteralPath $audioTemp }
}
