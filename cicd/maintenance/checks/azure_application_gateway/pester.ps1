param (
    [Parameter(Mandatory = $true)]
    [hashtable] $runtimeConfiguration
)

BeforeDiscovery {
    Push-Location -Path $PSScriptRoot
    
    $checkConfigurationFilename = $runtimeConfiguration.checkConfigurationFilename
    $stageName = $runtimeConfiguration.stageName
    $checkName = $runtimeConfiguration.checkName

    # loading check configuration
    if (-not (Test-Path -Path $checkConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $checkConfigurationFilename)
    }

    $checkConfiguration = ((Get-Content -Path $checkConfigurationFilename |
        ConvertFrom-Json -Depth 99).stages |
            Where-Object {$_.name-eq $stageName}).$checkName
    
    if ($null -eq $checkConfiguration) {
        throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $stageName, $checkConfigurationFilename)
    }

    # building the discovery object
    $discovery = [System.Collections.ArrayList]@()

    foreach ($resource in $checkConfiguration.applicationGateways) {
        $discoveryObject = [ordered] @{
            certificateRenewalBeforeInDays = $checkConfiguration.certificateRenewalBeforeInDays
            resourceGroupName = $resource.resourceGroupName
            resourceName = $resource.resourceName
        }
        $context = New-Object PSObject -property $discoveryObject
        $discovery.Add($context)
    }
}

BeforeAll {
    # Azure authentication
    . ../../powershell/Connect-Azure.ps1

    # installing dependencies
    . ../../powershell/Install-PowerShellModules.ps1 -modules ("Az.Network")
}

Describe $runtimeConfiguration.checkDisplayName -ForEach $discovery {

    BeforeAll {
        $resourceGroupName = $_.resourceGroupName
        $resourceName = $_.resourceName

        try {
            $azureResource = Get-AzApplicationGateway -ResourceGroupName $resourceGroupName -Name $resourceName
        }
        catch {
            throw ("Cannot find resource: '{0}' in resource group" -f $resourceName, $resourceGroupName)
        }

        $keyVaultSecretId = $azureResource.SslCertificates.KeyVaultSecretId
        
        if ([string]::IsNullOrEmpty($keyVaultSecretId)) {
            $certificateBytes = [Convert]::FromBase64String($azureResource.SslCertificates.PublicCertData)
            $p7b = New-Object System.Security.Cryptography.Pkcs.SignedCms
            $p7b.Decode($certificateBytes)
            $certificateExpiryDate = $p7b.Certificates[0].NotAfter

        } else {
            # installing dependencies
            . ../../powershell/Install-PowerShellModules.ps1 -modules ("Az.KeyVault")
            
            $elements = $keyVaultSecretId.Split('/')
            $certificateExpiryDate = (Get-AzKeyVaultCertificate -VaultName $elements[2].Split('.')[0] -Name $elements[4]).Expires
        }       
    }

    Context "Provisioning: '<_.resourceGroupName>/<_.resourceName>'" {

        It "Should have 'ProvisioningState' of 'Succeeded'" {
            $azureResource.ProvisioningState | Should -Be "Succeeded"
        }
        
    }

    Context "Certificate: '<_.resourceGroupName>/<_.resourceName>'" {

        It "The Ssl certificate should not be in the renewal window (now + <_.certificateRenewalBeforeInDays> days)" {    
            $certificateExpiryDate -gt $runtimeConfiguration.checkDateTime.AddDays($_.certificateRenewalBeforeInDays) | Should -Be $true
        }

        AfterAll {
            Write-Host ("`nApplication Gateway certificate expiry date: {0}`n" -f $certificateExpiryDate.ToString($runtimeConfiguration.checkDateFormat))
        }
    }

    AfterAll {
        Clear-Variable -Name "resourceGroupName"
        Clear-Variable -Name "resourceName"
        Clear-Variable -Name "azureResource"
        Clear-Variable -Name "keyVaultSecretId"
        Clear-Variable -Name "certificateBytes" -ErrorAction Continue
        Clear-Variable -Name "p7b" -ErrorAction Continue
        Clear-Variable -Name "certificateExpiryDate"
    }
}
