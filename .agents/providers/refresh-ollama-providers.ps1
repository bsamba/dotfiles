# refresh-ollama-providers.ps1
# Regenerates providers.json from the local Ollama proxy's live model list.
# Safe to call from a shell profile: short timeout, silent on any failure,
# and only rewrites the file when the payload actually changed.
#
# Env override: $env:OLLAMA_PROXY_URL (default http://127.0.0.1:11435/v1)

$ErrorActionPreference = 'Stop'
try {
    $endpoint = if ($env:OLLAMA_PROXY_URL) { $env:OLLAMA_PROXY_URL } else { 'http://127.0.0.1:11435/v1' }
    # Guard proxy (11435) preferred; fall back to direct Ollama (11434)
    $candidates = @($endpoint)
    if ($endpoint -notmatch '127.0.0.1:11434$') { $candidates += 'http://127.0.0.1:11434' }
    $base = $null
    foreach ($c in $candidates) {
        try {
            $probe = Invoke-RestMethod -Uri ($c.TrimEnd('/') + '/models') -TimeoutSec 1.5 -ErrorAction Stop
            if ($probe.data) { $base = $c.TrimEnd('/'); break }
        } catch { }
    }
    if (-not $base) { throw 'no reachable Ollama endpoint' }

    $resp = Invoke-RestMethod -Uri ($base + '/models') -TimeoutSec 3 -ErrorAction Stop
    $hostPort    = ($base -replace '^https?://', '')
    $hostPort    = $hostPort -replace '/v1$', ''
    $models = @($resp.data | Sort-Object id | ForEach-Object {
        $modelId = $_.id
        [ordered]@{
            id           = $modelId
            name         = if ($_.name) { $_.name } else { $modelId }
            # Copilot CLI-style model id (e.g. ollama-http-127.0.0.1-11435/qwen3.8-copilot:latest)
            copilotCliId = 'ollama-http-' + $hostPort + '/' + $modelId
        }
    })

    $doc = [ordered]@{
        name       = 'ollama-local'
        type       = 'openai-compatible'
        endpoint   = $base
        updated    = (Get-Date).ToUniversalTime().ToString('o')
        modelCount = $models.Count
        models     = $models
    }
    $json = ($doc | ConvertTo-Json -Depth 5)

    $outFile = Join-Path $PSScriptRoot 'providers.json'
    $current = if (Test-Path $outFile) { Get-Content $outFile -Raw } else { '' }
    if ($json.Replace("`r", '') -ne $current.Replace("`r", '')) {
        Set-Content -Path $outFile -Value $json -Encoding utf8
        Write-Verbose ('ollama-providers: updated {0} ({1} models from {2})' -f $outFile, $doc.modelCount, $base)
    }
}
catch {
    # Profile hook context: never break shell startup; a missing proxy is normal
    Write-Verbose ('ollama-providers: skipped ({0})' -f $_.Exception.Message)
}
