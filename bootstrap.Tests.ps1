$bootstrapPath = Join-Path $PSScriptRoot 'bootstrap.ps1'
$bootstrap = Get-Content $bootstrapPath -Raw
# Run only the installation boundary, avoiding the machine-configuration steps.
$start = $bootstrap.IndexOf('# --- Install Matt Pocock coding-agent skills')
$end = $bootstrap.IndexOf('# Hard-link the spec-driven-dev persistent instruction')
$installSkills = [scriptblock]::Create($bootstrap.Substring($start, $end - $start))

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
