$bootstrapPath = Join-Path $PSScriptRoot 'bootstrap.ps1'
$bootstrap = Get-Content $bootstrapPath -Raw
# Run only the installation boundary, avoiding the machine-configuration steps.
$start = $bootstrap.IndexOf('# --- Install Matt Pocock coding-agent skills')
$end = $bootstrap.IndexOf('# Hard-link the spec-driven-dev persistent instruction')
$installSkills = [scriptblock]::Create($bootstrap.Substring($start, $end - $start))
$helperStart = $bootstrap.IndexOf('function Ensure-EnvironmentVariable {')
$helperEnd = $bootstrap.IndexOf("`n}", $helperStart)
if ($helperStart -lt 0 -or $helperEnd -lt 0) {
    throw 'Could not extract Ensure-EnvironmentVariable from bootstrap.ps1'
}
$ensureEnvironmentVariable = [scriptblock]::Create(
    # Replace only the OS boundary so tests never access real credentials.
    $bootstrap.Substring($helperStart, $helperEnd + 2 - $helperStart).Replace(
        '[System.Environment]::', '$script:environment.'
    )
)
. $ensureEnvironmentVariable

function Read-Host {
    param(
        [string]$Prompt,
        [switch]$MaskInput
    )
    $script:readHostCalls++
    $script:readHostMasked = $MaskInput.IsPresent
    $script:readHostValue
}

Describe 'Bootstrap skills installation' {
    BeforeEach {
        $originalUserProfile = $env:USERPROFILE
        $testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $env:USERPROFILE = Join-Path $testRoot 'User Home'
        $repository = Join-Path $testRoot 'repository'
        New-Item -ItemType Directory -Force -Path $env:USERPROFILE, $repository | Out-Null
        Push-Location $repository
        $script:installCalls = 0

        function npx {
            $script:installCalls++
            $root = if ($args -contains '--global' -or $args -contains '-g') {
                $env:USERPROFILE
            } else {
                (Get-Location).Path
            }
            New-Item -ItemType Directory -Force -Path (Join-Path $root '.agents\skills\to-spec') | Out-Null
        }
    }

    AfterEach {
        Pop-Location
        $env:USERPROFILE = $originalUserProfile
    }

    It 'installs into the user-wide skills directory without changing repository skills' {
        $existingSkill = Join-Path $repository '.agents\skills\existing\SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path $existingSkill) | Out-Null
        Set-Content -Path $existingSkill -Value 'Existing local skill'

        & $installSkills

        Test-Path (Join-Path $env:USERPROFILE '.agents\skills\to-spec') | Should Be $true
        Test-Path (Join-Path $repository '.agents\skills\to-spec') | Should Be $false
        Get-Content $existingSkill | Should Be 'Existing local skill'
        $script:installCalls | Should Be 1
    }

    It 'skips installation when user-wide skills already exist' {
        $marker = Join-Path $env:USERPROFILE '.agents\skills\to-spec'
        New-Item -ItemType Directory -Force -Path $marker | Out-Null

        & $installSkills

        Test-Path $marker | Should Be $true
        Test-Path (Join-Path $repository '.agents\skills\to-spec') | Should Be $false
        $script:installCalls | Should Be 0
    }
}

Describe 'Bootstrap optional environment variables' {
    BeforeEach {
        $script:environment = [pscustomobject]@{
            Values = @{
                Process = @{}
                User = @{}
                Machine = @{}
            }
            Writes = 0
        }
        $script:environment | Add-Member ScriptMethod GetEnvironmentVariable {
            param($Name, $Scope)
            $this.Values[[string]$Scope][$Name]
        }
        $script:environment | Add-Member ScriptMethod SetEnvironmentVariable {
            param($Name, $Value, $Scope)
            $this.Writes++
            $this.Values[[string]$Scope][$Name] = $Value
        }
        $script:variableName = 'DOTFILES_BOOTSTRAP_TEST_KEY'
        $script:readHostCalls = 0
        $script:readHostValue = $null
        $script:readHostMasked = $false
    }

    It 'registers TYPESAFE_API_KEY with the optional environment-variable helper' {
        if ($bootstrap -notmatch 'Ensure-EnvironmentVariable -Name "TYPESAFE_API_KEY"') {
            throw 'bootstrap.ps1 does not register TYPESAFE_API_KEY'
        }
    }

    It 'stores a supplied key in user and process scopes' {
        $script:readHostValue = 'test-api-key'

        Ensure-EnvironmentVariable -Name $script:variableName -Description 'Test API key'

        $script:environment.Values.User[$script:variableName] | Should Be 'test-api-key'
        $script:environment.Values.Process[$script:variableName] | Should Be 'test-api-key'
        $script:environment.Values.Machine.Count | Should Be 0
        $script:environment.Writes | Should Be 2
        $script:readHostCalls | Should Be 1
        $script:readHostMasked | Should Be $true
    }

    It 'does not persist skipped input' {
        $script:readHostValue = ''

        Ensure-EnvironmentVariable -Name $script:variableName -Description 'Test API key'

        $script:environment.Writes | Should Be 0
        $script:readHostCalls | Should Be 1
    }

    It 'preserves an existing user value without prompting' {
        $script:environment.Values.User[$script:variableName] = 'existing-test-key'

        Ensure-EnvironmentVariable -Name $script:variableName -Description 'Test API key'

        $script:environment.Values.User[$script:variableName] | Should Be 'existing-test-key'
        $script:environment.Values.Process.Count | Should Be 0
        $script:environment.Writes | Should Be 0
        $script:readHostCalls | Should Be 0
    }

    It 'recognizes a machine-only value without prompting or copying it' {
        $script:environment.Values.Machine[$script:variableName] = 'machine-test-key'

        Ensure-EnvironmentVariable -Name $script:variableName -Description 'Test API key'

        $script:readHostCalls | Should Be 0
        $script:environment.Writes | Should Be 0
        $script:environment.Values.Machine[$script:variableName] | Should Be 'machine-test-key'
        $script:environment.Values.User.Count | Should Be 0
        $script:environment.Values.Process.Count | Should Be 0
    }

    It 'recognizes a process-only value without prompting or persisting it' {
        $script:environment.Values.Process[$script:variableName] = 'process-test-key'

        Ensure-EnvironmentVariable -Name $script:variableName -Description 'Test API key'

        $script:readHostCalls | Should Be 0
        $script:environment.Writes | Should Be 0
        $script:environment.Values.Process[$script:variableName] | Should Be 'process-test-key'
        $script:environment.Values.User.Count | Should Be 0
        $script:environment.Values.Machine.Count | Should Be 0
    }

    It 'preserves conflicting values across all scopes' {
        $script:environment.Values.Process[$script:variableName] = 'process-test-key'
        $script:environment.Values.User[$script:variableName] = 'user-test-key'
        $script:environment.Values.Machine[$script:variableName] = 'machine-test-key'

        Ensure-EnvironmentVariable -Name $script:variableName -Description 'Test API key'

        $script:readHostCalls | Should Be 0
        $script:environment.Writes | Should Be 0
        $script:environment.Values.Process[$script:variableName] | Should Be 'process-test-key'
        $script:environment.Values.User[$script:variableName] | Should Be 'user-test-key'
        $script:environment.Values.Machine[$script:variableName] | Should Be 'machine-test-key'
    }

    It 'continues past blank scopes to recognize an existing machine value' {
        $script:environment.Values.Process[$script:variableName] = ' '
        $script:environment.Values.User[$script:variableName] = ''
        $script:environment.Values.Machine[$script:variableName] = 'machine-test-key'

        Ensure-EnvironmentVariable -Name $script:variableName -Description 'Test API key'

        $script:readHostCalls | Should Be 0
        $script:environment.Writes | Should Be 0
        $script:environment.Values.Process[$script:variableName] | Should Be ' '
        $script:environment.Values.User[$script:variableName] | Should Be ''
    }

    It 'prompts when all existing scopes are blank and ignores whitespace input' {
        $script:environment.Values.Process[$script:variableName] = ' '
        $script:environment.Values.User[$script:variableName] = ''
        $script:environment.Values.Machine[$script:variableName] = "`t"
        $script:readHostValue = ' '

        Ensure-EnvironmentVariable -Name $script:variableName -Description 'Test API key'

        $script:readHostCalls | Should Be 1
        $script:readHostMasked | Should Be $true
        $script:environment.Writes | Should Be 0
    }
}
