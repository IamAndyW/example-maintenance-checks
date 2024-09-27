param (
    [Parameter(Mandatory = $true)]
    [hashtable] $externalConfiguration
)

BeforeDiscovery {
    $internalConfigurationFilename = $externalConfiguration.checkConfigurationFilename
    $stageName = $externalConfiguration.stageName

    # loading check configuration
    if (-not (Test-Path -Path $internalConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $internalConfigurationFilename)
    }

    $internalConfiguration = (Get-Content -Path $internalConfigurationFilename |
        ConvertFrom-Json -Depth 99).stages |
            Where-Object {$_.name-eq $stageName}
    
    if ($null -eq $internalConfiguration) {
        throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $stageName, $internalConfigurationFilename)
    }

    # building the discovery object
    $discovery = $internalConfiguration
    $renewalStartDate = ($externalConfiguration.checkDateTime.AddDays(($internalConfiguration.$($externalConfiguration.checkName)).certificateRenewalBeforeInDays))
}

BeforeAll {
    # Azure authentication
    . ../../powershell/Connect-Azure.ps1 `
        -tenantId $externalConfiguration.armTenantId `
        -subscriptionId $externalConfiguration.armSubscriptionId `
        -clientId $externalConfiguration.armClientId `
        -clientSecret $externalConfiguration.armClientSecret

    # installing dependencies
    . ../../powershell/Install-PowerShellModules.ps1 -moduleNames ("Az.Network")
}

Describe $externalConfiguration.checkDisplayName -ForEach $discovery.$($externalConfiguration.checkName) {

    BeforeAll {
        $renewalStartDate = $externalConfiguration.checkDateTime.AddDays($_.certificateRenewalBeforeInDays)    
    }

    Context "Gateway: <_.resourceGroupName>/<_.resourceName>" -ForEach $_.gateways {
        BeforeAll {
            $resourceGroupName = $_.resourceGroupName
            $resourceName = $_.resourceName
    
            try {
                $resource = Get-AzApplicationGateway -ResourceGroupName $resourceGroupName -Name $resourceName
            }
            catch {
                throw ("Cannot find resource: '{0}' in resource group: '{1}'" -f $resourceName, $resourceGroupName)
            }
    
            $keyVaultSecretId = $resource.SslCertificates.KeyVaultSecretId
            
            if ([string]::IsNullOrEmpty($keyVaultSecretId)) {
                $certificateBytes = [Convert]::FromBase64String($resource.SslCertificates.PublicCertData)
                $p7b = New-Object System.Security.Cryptography.Pkcs.SignedCms
                $p7b.Decode($certificateBytes)
                $certificateExpiryDate = $p7b.Certificates[0].NotAfter
    
            } else {
                # installing dependencies
                . ../../powershell/Install-PowerShellModules.ps1 -moduleNames ("Az.KeyVault")
                
                $elements = $keyVaultSecretId.Split('/')
                $certificateExpiryDate = (Get-AzKeyVaultCertificate -VaultName $elements[2].Split('.')[0] -Name $elements[4]).Expires
            } 

        }

        It "Should have Provisioning State of 'Succeeded'" {
            $resource.ProvisioningState | Should -Be "Succeeded"
        }

        It "The certificate expiry date should not be after $($renewalStartDate.ToString($externalConfiguration.checkDateFormat))" {    
            $certificateExpiryDate | Should -BeGreaterThan $renewalStartDate
        }

        AfterAll {
            Write-Host ("`nApplication Gateway certificate expiry date: {0}`n" -f $certificateExpiryDate.ToString($externalConfiguration.checkDateFormat))

            Clear-Variable -Name "resourceGroupName"
            Clear-Variable -Name "resourceName"
            Clear-Variable -Name "resource"
            Clear-Variable -Name "keyVaultSecretId"
            Clear-Variable -Name "certificateBytes" -ErrorAction Continue
            Clear-Variable -Name "p7b" -ErrorAction Continue
            Clear-Variable -Name "certificateExpiryDate"
        }
    }

    AfterAll {
        Clear-Variable -Name "renewalStartDate"
    }
}

AfterAll {
    Clear-AzContext -Scope CurrentUser -Force
}
