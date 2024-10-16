<#
    This is the CDM check
    The validation could be directly in this file or via a testing framwework such as Pester - https://pester.dev/
#>

Push-Location -Path $PSScriptRoot

# installing dependencies
. ../../../powershell/functions/Install-PowerShellModules.ps1
Install-PowerShellModules -moduleNames ("Pester")

# setting variables
$script:pesterFilename = 'pester.ps1'

# configuration available in the discovery and run phases of Pester
$parentConfiguration.Add('adoAccessToken', $env:ADO_ACCESS_TOKEN)

$script:pesterContainer = New-PesterContainer -Path $pesterFilename -Data @{
    parentConfiguration = $parentConfiguration
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
        OutputPath   = ("{0}/{1}" -f $PSScriptRoot, $parentConfiguration.resultsFilename)
    }
}

Invoke-Pester -Configuration $pesterConfiguration

Pop-Location
