# glTF vertex paint is linear. Godot 4.5's GLES standard material multiplies
# display-space colors instead. Convert just the RGB channels of our staged
# models before Godot imports them. The Blender and source GLB files stay linear.
param([Parameter(Mandatory=$true)][string]$ModelDirectory)
$ErrorActionPreference = 'Stop'
foreach ($file in Get-ChildItem -LiteralPath $ModelDirectory -Filter '*.glb' -File) {
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    $jsonSize = [BitConverter]::ToInt32($bytes,12)
    $document = [Text.Encoding]::UTF8.GetString($bytes,20,$jsonSize) | ConvertFrom-Json
    $binary = 28 + $jsonSize
    $paint = @(foreach ($mesh in $document.meshes) {
        foreach ($primitive in $mesh.primitives) {
            if ($null -ne $primitive.attributes.COLOR_0) { $primitive.attributes.COLOR_0 }
        }
    })
    if (-not $paint.Count) { continue }
    foreach ($index in ($paint | Sort-Object -Unique)) {
        $a = $document.accessors[$index]
        $view = $document.bufferViews[$a.bufferView]
        # Project art exports float RGB/RGBA without sparse data or accessor bounds.
        if ($a.componentType -ne 5126 -or $a.type -notin @('VEC3','VEC4') -or
            $null -ne $a.sparse -or $null -ne $a.min -or $null -ne $a.max -or $view.buffer -ne 0) {
            throw "Unsupported vertex paint in $($file.Name), accessor $index"
        }
        $width = if ($a.type -eq 'VEC4') { 16 } else { 12 }
        $stride = if ($view.byteStride) { [int]$view.byteStride } else { $width }
        $start = $binary + [int]$view.byteOffset + [int]$a.byteOffset
        $end = $start + ($a.count - 1) * $stride + $width
        if ($stride -lt $width -or $end -gt $bytes.Length -or $end -gt $binary + [int]$view.byteOffset + $view.byteLength) {
            throw "Invalid color buffer in $($file.Name), accessor $index"
        }
        for ($v=0; $v -lt $a.count; $v++) {
            $vertex = $start + $v * $stride
            for ($c=0; $c -lt 3; $c++) {
                $offset = $vertex + 4 * $c
                $linear = [BitConverter]::ToSingle($bytes,$offset)
                $display = if ($linear -le 0.0031308) { 12.92 * $linear } else { 1.055 * [Math]::Pow($linear,1.0/2.4) - 0.055 }
                [BitConverter]::GetBytes([single]$display).CopyTo($bytes,$offset)
            }
        }
    }
    [IO.File]::WriteAllBytes($file.FullName,$bytes)
}
