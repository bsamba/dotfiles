$profilePath = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'

function Get-RequestedPredictionSource([string]$Exe) {
    # Isolated USERPROFILE keeps the profile's Ollama refresh from touching real files.
    $script = @"
`$env:USERPROFILE = `$env:TEMP
`$script:src = `$null
function Set-PSReadLineOption { param(`$PredictionSource, `$PredictionViewStyle, `$Colors) if (`$PredictionSource) { `$script:src = `$PredictionSource } }
. '$profilePath' *> `$null
`$script:src
"@
    (& $Exe -NoProfile -NonInteractive -Command $script) | Select-Object -Last 1
}

Describe 'PSReadLine prediction source' {
    It 'uses History on Windows PowerShell 5.1' {
        Get-RequestedPredictionSource 'powershell.exe' | Should Be 'History'
    }

    It 'uses HistoryAndPlugin on PowerShell 7.2+' -Skip:(-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Get-RequestedPredictionSource 'pwsh.exe' | Should Be 'HistoryAndPlugin'
    }
}
