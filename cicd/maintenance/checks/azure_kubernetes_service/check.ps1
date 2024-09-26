<#
    This is the maintenance check
    The validation could be directly in this file or via a testing framwework such as Pester - https://pester.dev/

    Pester test code: 'pester.ps1'
#>

Push-Location -Path $PSScriptRoot

# installing dependencies
. ../../powershell/Install-PowerShellModules.ps1 -moduleNames ("Pester")

# setting variables
$script:pesterFilename = 'pester.ps1'

# configuration available in the discovery and run phases of Pester
$externalConfiguration.Add('armTenantId', $env:ARM_TENANT_ID)
$externalConfiguration.Add('armSubscriptionId', $env:ARM_SUBSCRIPTION_ID)
$externalConfiguration.Add('armClientId', $env:ARM_CLIENT_ID)
$externalConfiguration.Add('armClientSecret', $env:ARM_CLIENT_SECRET)

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
