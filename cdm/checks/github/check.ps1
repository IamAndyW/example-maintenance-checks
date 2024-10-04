<#
    This is the CDM check
    The validation could be directly in this file or via a testing framwework such as Pester - https://pester.dev/
#>

Push-Location -Path $PSScriptRoot

# installing dependencies
. ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("Pester")

# setting variables
$script:pesterFilename = 'pester.ps1'

# configuration available in the discovery and run phases of Pester
$pipelineConfiguration.Add('githubToken', $env:GITHUB_TOKEN)

$script:pesterContainer = New-PesterContainer -Path $pesterFilename -Data @{
    pipelineConfiguration = $pipelineConfiguration
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
        OutputPath   = ("{0}/{1}" -f $PSScriptRoot, $env:CDM_CHECK_RESULT_FILENAME)
    }
}

Invoke-Pester -Configuration $pesterConfiguration

Pop-Location
