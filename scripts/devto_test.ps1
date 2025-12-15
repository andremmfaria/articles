param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [Parameter(Mandatory=$false)][string]$ApiKey,
    [Parameter(Mandatory=$false)][switch]$Publish,
    [Parameter(Mandatory=$false)][switch]$Minimal,
    [Parameter(Mandatory=$false)][ValidateSet("Cover","Tags","Description","CanonicalUrl","Series")][string[]]$RemoveHeaders,
    [Parameter(Mandatory=$false)][switch]$DryRun
)

function Get-PythonPath {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) { return $py.Path }
    $py3 = Get-Command python3 -ErrorAction SilentlyContinue
    if ($py3) { return $py3.Path }
    return $null
}

$python = Get-PythonPath
if (-not $python) {
    Write-Error "Python is not installed or not in PATH. Please install Python 3."
    exit 1
}

if (-not (Test-Path -Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$argsList = @("--file", $FilePath)
if ($ApiKey) { $argsList += @("--api-key", $ApiKey) } elseif ($env:DEVTO_API_KEY) { $argsList += @("--api-key", $env:DEVTO_API_KEY) }
if ($Publish.IsPresent) { $argsList += @("--publish") }
if ($Minimal.IsPresent) { $argsList += @("--minimal") }
if ($RemoveHeaders -and $RemoveHeaders.Length -gt 0) { $argsList += @("--remove-headers", ($RemoveHeaders -join ",")) }
if ($DryRun.IsPresent) { $argsList += @("--dry-run") }

# Pre-check API key when not dry-run for clearer error
if (-not $DryRun.IsPresent -and -not $ApiKey -and -not $env:DEVTO_API_KEY) {
    Write-Error "DEVTO_API_KEY not provided. Set -ApiKey or DEVTO_API_KEY env var, or use -DryRun."
    exit 1
}

& $python (Join-Path $PSScriptRoot "devto_publish.py") @argsList
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
