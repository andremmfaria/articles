param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [Parameter(Mandatory=$false)][string]$ApiKey,
    [Parameter(Mandatory=$false)][switch]$Publish,
    [Parameter(Mandatory=$false)][switch]$NoCover,
    [Parameter(Mandatory=$false)][switch]$Minimal
)

if (-not $ApiKey) {
    $ApiKey = $env:DEVTO_API_KEY
}

if (-not $ApiKey) {
    Write-Error "DEVTO_API_KEY not provided. Set -ApiKey or DEVTO_API_KEY env var."
    exit 1
}

if (-not (Test-Path -Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

# Parse front matter (basic): title, tags, description, cover_image, published
$raw = Get-Content -Raw $FilePath
$frontMatterMatch = [regex]::Match($raw, "(?s)^---\s*(.*?)\s*---\s*")
if (-not $frontMatterMatch.Success) {
    Write-Error "YAML front matter not found at top of file."
    exit 1
}
$yaml = $frontMatterMatch.Groups[1].Value
$body = $raw.Substring($frontMatterMatch.Length)

# Minimal YAML parsing: use ConvertFrom-Yaml if available; else quick regex fallbacks
$canYaml = Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue
if ($canYaml) {
    $meta = ConvertFrom-Yaml -Yaml $yaml
} else {
    # Fallback simple parse for common keys, including multiline tags
    $meta = [ordered]@{}
    $lines = $yaml -split "\r?\n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match "^title:\s*(.*)$") { $meta.title = $Matches[1].Trim('"', "'") }
        elseif ($line -match "^published:\s*(.*)$") {
            $val = $Matches[1].Trim()
            $meta.published = ($val -match "^(?i:true)$")
        }
        elseif ($line -match "^description:\s*(.*)$") { $meta.description = $Matches[1].Trim('"', "'") }
        elseif ($line -match "^cover_image:\s*(.*)$") { $meta.cover_image = $Matches[1].Trim('"', "'") }
        elseif ($line -match "^tags:\s*\[(.*)\]$") {
            $meta.tags = ($Matches[1].Split(',') | ForEach-Object { $_.Trim() })
        }
        elseif ($line -match "^tags:\s*$") {
            $meta.tags = @()
            $j = $i + 1
            while ($j -lt $lines.Count -and ($lines[$j] -match "^\s+-\s+(.*)$")) {
                $tag = $Matches[1].Trim('"', "'")
                if ($tag) { $meta.tags += $tag }
                $j++
            }
        }
    }
}

if (-not $meta.title) { Write-Error "Missing title in front matter."; exit 1 }
if (-not $meta.tags) { $meta.tags = @() }
if ($Publish.IsPresent) { $meta.published = $true } elseif ($null -eq $meta.published) { $meta.published = $false }

if ($Minimal.IsPresent) {
    $payload = @{ article = @{ title = $meta.title; published = $meta.published; body_markdown = $body } }
} else {
    $payload = @{ article = @{ title = $meta.title; published = $meta.published; description = $meta.description; body_markdown = $body } }
    if ($meta.tags.Count -gt 0) { $payload.article.tags = $meta.tags }
    if ($meta.cover_image -and -not $NoCover.IsPresent) { $payload.article.cover_image = $meta.cover_image }
}

$json = $payload | ConvertTo-Json -Depth 6

try {
    $resp = Invoke-RestMethod -Method Post -Uri "https://dev.to/api/articles" -Headers @{ "api-key" = $ApiKey; "Content-Type" = "application/json" } -Body $json -ErrorAction Stop
    Write-Host "OK: " ($resp.id) ($resp.url)
} catch {
    $msg = $_.Exception.Message
    $errBody = $null
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errBody = $reader.ReadToEnd()
        } catch {}
    }
    Write-Error "API error: ${msg}";
    if ($errBody) { Write-Error "Response body: $errBody" }
    Write-Host "Request payload:" -ForegroundColor Yellow
    Write-Host $json
    exit 2
}
