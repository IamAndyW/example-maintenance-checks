<#
    This is the maintenance check
    The validation could be directly in this file or via a testing framwework such as Pester - https://pester.dev/

    Pester test code: 'pester.ps1'
#>

Push-Location -Path $PSScriptRoot

# installing dependencies
. ../../powershell/Install-PowerShellModules.ps1 -modules ("Pester")

# setting variables
$script:pesterFilename = 'pester.ps1'

# configuration available in the discovery and run phases of Pester
$externalConfiguration.Add('digicertAPIkey', $env:DIGICERT_API_KEY)
$externalConfiguration.Add('digicertOrganisationId', $env:DIGICERT_ORGANISATION_ID)

$script:pesterContainer = New-PesterContainer -Path $pesterFilename -Data @{
    externalConfiguration = $externalConfiguration
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
