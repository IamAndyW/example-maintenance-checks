param (
    [Parameter(Mandatory = $true)]
    [hashtable] $pipelineConfiguration
)

BeforeDiscovery {
    # installing dependencies
    . ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("powershell-yaml")

    $checkConfigurationFilename = $pipelineConfiguration.checkConfigurationFilename

    # loading check configuration
    if (-not (Test-Path -Path $checkConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $checkConfigurationFilename)
    }

    $checkConfiguration = Get-Content -Path $checkConfigurationFilename | ConvertFrom-Yaml

    # building the discovery objects
    $discovery = $checkConfiguration
} 

Describe $pipelineConfiguration.checkDisplayName -ForEach $discovery {

    Context "Required Version: <_>" -ForEach $_.requiredVersionConstraints {
        BeforeAll {
            $testFilePath = "./version.tf"
        }

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

    AfterAll {
        Write-Host ("`nInstalled Terraform version: {0}" -f $(terraform --version))
        Write-Host ("`nRunbook: {0}`n" -f $_.runbook)
    }
}
