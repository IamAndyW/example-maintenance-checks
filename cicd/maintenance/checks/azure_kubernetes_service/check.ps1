<#
    This is the entrypoint into the maintenance check
    The validation could be directly in this file or via a testing framwework such as Pester - https://pester.dev/

    Configuration => check_configuration.json
    Test code => pester.ps1
#>

$ErrorActionPreference = "Stop"

$script:checkDateTime = [datetime]::ParseExact($(Get-Date -Format $env:MAINTENANCE_CHECK_DATE_FORMAT), $env:MAINTENANCE_CHECK_DATE_FORMAT, $null).ToUniversalTime()
Write-Host ("Check date: {0} ({1})" -f $checkDateTime.ToString($env:MAINTENANCE_CHECK_DATE_FORMAT), $checkDateTime.Kind)

# should check be skipped
$script:skipUntilDateTime = [datetime]::ParseExact($env:MAINTENANCE_CHECK_SKIP_UNTIL, $env:MAINTENANCE_CHECK_DATE_FORMAT, $null).ToUniversalTime()

if ($skipUntilDateTime -gt $checkDateTime) {
    
    Write-Warning ("Skipping check until: {0} ({1})`n" -f $skipUntilDateTime.ToString($env:MAINTENANCE_CHECK_DATE_FORMAT), $skipUntilDateTime.Kind)

} else {
    
    Push-Location -Path $PSScriptRoot

    # installing dependencies
    . ../../powershell/Install-PowerShellModules.ps1 -modules ("Pester")

    # setting variables
    $script:pesterFilename = 'pester.ps1'

    # runtime configuration available in the discovery and run phases of Pester
    $script:pesterContainer = New-PesterContainer -Path $pesterFilename -Data @{
        runtimeConfiguration = @{
            checkConfigurationFilename = ("{0}_configuration.json" -f $(Split-Path $PSCommandpath -LeafBase))
            checkName = $(Split-Path -Path $PSScriptRoot -Leaf)
            checkDateFormat = $env:MAINTENANCE_CHECK_DATE_FORMAT
            checkDateTime = $checkDateTime
            stageName = $env:SYSTEM_STAGENAME
        }
    }

    # Pester configuration - https://pester.dev/docs/usage/configuration
    $script:pesterConfiguration = [PesterConfiguration] @{
        Run = @{
            Container = $pesterContainer
        }
        Output = @{
            Verbosity = 'Detailed'
        }
        TestResult = @{
            Enabled      = $true
            OutputFormat = "NUnitXml"
            OutputPath   = ("{0}/{1}" -f $PSScriptRoot, $env:MAINTENANCE_CHECK_RESULT_FILENAME)
        }
    }

    Invoke-Pester -Configuration $pesterConfiguration

    Pop-Location
}
