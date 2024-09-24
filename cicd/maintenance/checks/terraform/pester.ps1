param (
    [Parameter(Mandatory = $true)]
    [hashtable] $runtimeConfiguration
)

BeforeDiscovery {
    Push-Location -Path $PSScriptRoot
    
    $checkConfigurationFilename = $runtimeConfiguration.checkConfigurationFilename
    $checkName = $runtimeConfiguration.checkName

    # loading check configuration
    if (-not (Test-Path -Path $checkConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $checkConfigurationFilename)
    }

    $checkConfiguration = (Get-Content -Path $checkConfigurationFilename |
        ConvertFrom-Json -Depth 99).$checkName
    
    if ($null -eq $checkConfiguration) {
        throw ("Cannot find configuration in file: '{0}'" -f $checkConfigurationFilename)
    }

    $discovery = [System.Collections.ArrayList]@()

    foreach ($requiredVersionConstraint in $checkConfiguration.requiredVersionConstraints) {
    
        $discoveryObject = [ordered] @{
            requiredVersionConstraint  = $requiredVersionConstraint
        }
        $context = New-Object PSObject -property $discoveryObject
        $discovery.Add($context)
    }
} 

Describe $runtimeConfiguration.checkDisplayName {

    BeforeAll {
        $testFilePath = "./version.tf"
    }

    Context "Required Version: <_>" -ForEach $discovery.requiredVersionConstraint {

        BeforeEach {
            @"
            terraform {
                # https://developer.hashicorp.com/terraform/language/expressions/version-constraints
                required_version = "$_"
            }
"@ | Set-Content -Path $testFilePath -Force
        }

        It "'terraform init' should return an Exit Code of 0" {            
            terraform init
            $LASTEXITCODE | Should -Be 0 
        }

        AfterEach {
            Remove-Item -Path $testFilePath -Force
        }

        AfterAll {
            Clear-Variable -Name testFilePath
        }
    }
}

AfterAll {
    Write-Host ("`nInstalled Terraform version: {0}`n" -f $(terraform --version))
    
}
