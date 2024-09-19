<#
    This is the entrypoint into the maintenance check
    The validation could be directly in this file or via a testing framwework such as Pester - https://pester.dev/

    Configuration => check_configuration.json
    Test code => pester.ps1
#>

$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

# setting variables
$script:pesterFilename = 'pester.ps1'

if([string]::IsNullOrEmpty($env:MAINTENANCE_CHECK_RESULT_FILENAME)) {
    $script:pesterOutputPath = ("{0}/{1}" -f $PSScriptRoot, "check_results.xml")
} else {
    $script:pesterOutputPath = ("{0}/{1}" -f $PSScriptRoot, $env:MAINTENANCE_CHECK_RESULT_FILENAME) 
}

# runtime configuration available in the discovery and run phases of Pester
$script:pesterContainer = New-PesterContainer -Path $pesterFilename -Data @{
    runtimeConfiguration = @{
        checkConfigurationFilename = ("{0}_configuration.json" -f $(Split-Path $PSCommandpath -LeafBase))
        stageName = $env:SYSTEM_STAGENAME
        checkName = $(Split-Path -Path $PSScriptRoot -Leaf)
        digicertAPIkey = $env:DIGICERT_API_KEY
        digicertOrganisationId = $env:DIGICERT_ORGANISATION_ID
    }
}

# Pester configuration - https://pester.dev/docs/usage/configuration
$script:pesterConfiguration = [PesterConfiguration] @{
    Run = @{
        Container = $pesterContainer
    }
    Filter = @{
        Tag = $env:SYSTEM_STAGENAME
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    TestResult = @{
        Enabled      = $true
        OutputFormat = "NUnitXml"
        OutputPath   = $pesterOutputPath
    }
}

Invoke-Pester -Configuration $pesterConfiguration

Pop-Location
