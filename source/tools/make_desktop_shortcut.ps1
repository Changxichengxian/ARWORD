param([Parameter(Mandatory=$true)][string]$Target,[Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference='Stop'
$resolvedTarget=(Resolve-Path -LiteralPath $Target).Path
$resolvedFolder=(Resolve-Path -LiteralPath (Split-Path -Parent $Destination)).Path
if([IO.Path]::GetExtension($Destination) -ne '.lnk'){throw 'Expected a shortcut destination'}
$linkPath=Join-Path $resolvedFolder (Split-Path -Leaf $Destination)
$shellObject=New-Object -ComObject WScript.Shell
$shortcut=$shellObject.CreateShortcut($linkPath)
$shortcut.TargetPath=$resolvedTarget
$shortcut.Arguments='-- --art-preview'
$shortcut.WorkingDirectory=Split-Path -Parent $resolvedTarget
$shortcut.IconLocation=$resolvedTarget+',0'
$shortcut.Description='Little Tide art preview - no progress is saved'
$shortcut.Save()
