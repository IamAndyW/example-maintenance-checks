param (
    [Parameter(Mandatory = $true)]
    [hashtable] $externalConfiguration
)

BeforeDiscovery {
    $internalConfigurationFilename = $externalConfiguration.checkConfigurationFilename
    $checkName = $externalConfiguration.checkName

    # loading check configuration
    if (-not (Test-Path -Path $internalConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $internalConfigurationFilename)
    }

    $internalConfiguration = Get-Content -Path $internalConfigurationFilename |
        ConvertFrom-Json -Depth 99
    
    if ($null -eq $internalConfiguration) {
        throw ("Cannot find configuration: {0} in file: {1}" -f $checkName, $internalConfigurationFilename)
    }

    $discovery = $internalConfiguration
} 

Describe $externalConfiguration.checkDisplayName -ForEach $discovery.$($externalConfiguration.checkName) {

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
}

AfterAll {
    Write-Host ("`nInstalled Terraform version: {0}`n" -f $(terraform --version))
    
}
