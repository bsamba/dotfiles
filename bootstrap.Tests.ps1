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
    $bootstrap.Substring($helperStart, $helperEnd + 2 - $helperStart)
)
. $ensureEnvironmentVariable

function Read-Host {
    param(
        [string]$Prompt,
        [switch]$MaskInput
    )
    $script:readHostCalls++
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
        $userEnvironmentKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
        $script:hadOriginalTypeSafeUserValue = $null -ne $userEnvironmentKey -and
            $userEnvironmentKey.GetValueNames() -contains 'TYPESAFE_API_KEY'
        if ($script:hadOriginalTypeSafeUserValue) {
            $script:originalTypeSafeUserValue = $userEnvironmentKey.GetValue(
                'TYPESAFE_API_KEY',
                $null,
                [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
            )
            $script:originalTypeSafeUserValueKind = $userEnvironmentKey.GetValueKind(
                'TYPESAFE_API_KEY'
            )
        }
        if ($null -ne $userEnvironmentKey) {
            $userEnvironmentKey.Close()
        }
        $script:originalTypeSafeProcessValue = [System.Environment]::GetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            [System.EnvironmentVariableTarget]::Process
        )
        [System.Environment]::SetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            $null,
            [System.EnvironmentVariableTarget]::User
        )
        $script:readHostCalls = 0
        $script:readHostValue = $null
    }

    AfterEach {
        if ($script:hadOriginalTypeSafeUserValue) {
            $userEnvironmentKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
            $userEnvironmentKey.SetValue(
                'TYPESAFE_API_KEY',
                $script:originalTypeSafeUserValue,
                $script:originalTypeSafeUserValueKind
            )
            $userEnvironmentKey.Close()
        } else {
            $userEnvironmentKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
                'Environment',
                $true
            )
            if ($null -ne $userEnvironmentKey) {
                $userEnvironmentKey.DeleteValue('TYPESAFE_API_KEY', $false)
                $userEnvironmentKey.Close()
            }
        }
        [System.Environment]::SetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            $script:originalTypeSafeProcessValue,
            [System.EnvironmentVariableTarget]::Process
        )
    }

    It 'registers TYPESAFE_API_KEY with the optional environment-variable helper' {
        if ($bootstrap -notmatch 'Ensure-EnvironmentVariable -Name "TYPESAFE_API_KEY"') {
            throw 'bootstrap.ps1 does not register TYPESAFE_API_KEY'
        }
    }

    It 'stores a supplied key in user and process scopes' {
        $script:readHostValue = 'test-api-key'

        Ensure-EnvironmentVariable -Name 'TYPESAFE_API_KEY' -Description 'TypeSafe API key'

        [System.Environment]::GetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            [System.EnvironmentVariableTarget]::User
        ) | Should Be 'test-api-key'
        [System.Environment]::GetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            [System.EnvironmentVariableTarget]::Process
        ) | Should Be 'test-api-key'
        $script:readHostCalls | Should Be 1
    }

    It 'does not persist skipped input and preserves the process-scope value' {
        $script:readHostValue = ''

        Ensure-EnvironmentVariable -Name 'TYPESAFE_API_KEY' -Description 'TypeSafe API key'

        $userValue = [System.Environment]::GetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            [System.EnvironmentVariableTarget]::User
        )
        $processValue = [System.Environment]::GetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            [System.EnvironmentVariableTarget]::Process
        )
        if (-not [string]::IsNullOrWhiteSpace($userValue)) {
            throw 'Skipped input should not persist a user-scope value'
        }
        if (-not [System.String]::Equals(
            $processValue,
            $script:originalTypeSafeProcessValue,
            [System.StringComparison]::Ordinal
        )) {
            throw 'Skipped input should leave the process-scope value unchanged'
        }
        $script:readHostCalls | Should Be 1
    }

    It 'preserves an existing user value without prompting' {
        [System.Environment]::SetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            'existing-test-key',
            [System.EnvironmentVariableTarget]::User
        )
        [System.Environment]::SetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            'process-test-key',
            [System.EnvironmentVariableTarget]::Process
        )

        Ensure-EnvironmentVariable -Name 'TYPESAFE_API_KEY' -Description 'TypeSafe API key'

        [System.Environment]::GetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            [System.EnvironmentVariableTarget]::User
        ) | Should Be 'existing-test-key'
        [System.Environment]::GetEnvironmentVariable(
            'TYPESAFE_API_KEY',
            [System.EnvironmentVariableTarget]::Process
        ) | Should Be 'process-test-key'
        $script:readHostCalls | Should Be 0
    }
}
