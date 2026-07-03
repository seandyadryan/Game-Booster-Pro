param(
    [string]$PubspecPath = "pubspec.yaml"
)

$resolvedPath = Resolve-Path -LiteralPath $PubspecPath -ErrorAction Stop
$content = Get-Content -Raw -LiteralPath $resolvedPath

$updated = [regex]::Replace(
    $content,
    '(?m)^version:\s*([0-9]+(?:\.[0-9]+){2})\+([0-9]+)\s*$',
    {
        param($match)
        $versionName = $match.Groups[1].Value
        $nextBuild = [int]$match.Groups[2].Value + 1
        "version: $versionName+$nextBuild"
    },
    1
)

if ($updated -eq $content) {
    throw "Tidak menemukan format version: x.y.z+N di pubspec.yaml"
}

Set-Content -LiteralPath $resolvedPath -Value $updated -NoNewline
Write-Host "Build number pubspec.yaml dinaikkan otomatis."
