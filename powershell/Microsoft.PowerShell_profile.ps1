
# Oh-my-posh prompt (atomic theme)
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\atomic.omp.json" | Invoke-Expression
}

# PSReadLine - predictive IntelliSense + syntax highlighting
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -Colors @{
    Command            = '#61AFEF'  # blue
    Parameter          = '#C678DD'  # purple
    String             = '#98C379'  # green
    Operator           = '#56B6C2'  # cyan
    Variable           = '#E06C75'  # red
    Comment            = '#5C6370'  # grey
    InlinePrediction   = '#5C6370'  # grey (ghost text)
    Selection          = '#3E4452'  # dark highlight
}

# GitHub CLI completions
if (Get-Command gh -ErrorAction SilentlyContinue) {
    (& gh completion -s powershell) | Out-String | Invoke-Expression
}

# kubectl completions
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    (& kubectl completion powershell) | Out-String | Invoke-Expression
}

# Docker completions
if (Get-Command docker -ErrorAction SilentlyContinue) {
    (& docker completion powershell) | Out-String | Invoke-Expression
}

# dotnet CLI completions (requires: dotnet tool install -g dotnet-suggest)
if (Get-Command dotnet-suggest -ErrorAction SilentlyContinue) {
    $availableToComplete = (dotnet-suggest list) | Out-String
    $availableToCompleteArray = $availableToComplete.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
    Register-ArgumentCompleter -Native -CommandName $availableToCompleteArray -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $fullpath = (Get-Command $commandAst.CommandElements[0]).Source
        $arguments = $commandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() }
        dotnet-suggest get -e $fullpath --position $cursorPosition -- "$arguments" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

