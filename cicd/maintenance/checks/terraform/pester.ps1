param (
    [Parameter(Mandatory = $true)]
    [hashtable] $externalConfiguration
)

BeforeDiscovery {
    Push-Location -Path $PSScriptRoot
    
    $internalConfigurationFilename = $externalConfiguration.checkConfigurationFilename
    $checkName = $externalConfiguration.checkName

    # loading check configuration
    if (-not (Test-Path -Path $internalConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $internalConfigurationFilename)
    }

    $internalConfiguration = (Get-Content -Path $internalConfigurationFilename |
        ConvertFrom-Json -Depth 99).$checkName
    
    if ($null -eq $internalConfiguration) {
        throw ("Cannot find configuration in file: '{0}'" -f $internalConfigurationFilename)
    }

    $discovery = [System.Collections.ArrayList]@()

    foreach ($requiredVersionConstraint in $internalConfiguration.requiredVersionConstraints) {
    
        $discoveryObject = [ordered] @{
            requiredVersionConstraint  = $requiredVersionConstraint
        }
        $context = New-Object PSObject -property $discoveryObject
        $discovery.Add($context)
    }
} 

Describe $externalConfiguration.checkDisplayName {

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
