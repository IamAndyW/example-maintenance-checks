param (
    [Parameter(Mandatory = $true)]
    [hashtable] $pipelineConfiguration
)

BeforeDiscovery {
    # installing dependencies
    . ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("Az.Network", "powershell-yaml")

    $checkConfigurationFilename = $pipelineConfiguration.configurationFilename
    $stageName = $pipelineConfiguration.stageName

    # loading check configuration
    if (-not (Test-Path -Path $checkConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $checkConfigurationFilename)
    }

    $checkConfiguration = Get-Content -Path $checkConfigurationFilename | ConvertFrom-Yaml
    
    # building the discovery objects
    $discovery = $checkConfiguration
    $gateways = $discovery.stages | Where-Object { $_.name -eq $stageName } | Select-Object -ExpandProperty gateways
    
    $renewalStartDate = $pipelineConfiguration.dateTime.AddDays($checkConfiguration.certificateRenewalBeforeInDays)
}

BeforeAll {
    # Azure authentication
    . ../../../powershell/Connect-Azure.ps1 `
        -tenantId $pipelineConfiguration.armTenantId `
        -subscriptionId $pipelineConfiguration.armSubscriptionId `
        -clientId $pipelineConfiguration.armClientId `
        -clientSecret $pipelineConfiguration.armClientSecret
}

Describe $pipelineConfiguration.displayName -ForEach $discovery {

    BeforeAll {
        $renewalStartDate = $pipelineConfiguration.dateTime.AddDays($_.certificateRenewalBeforeInDays)    
    }

    Context "Gateway: <_.resourceGroupName>/<_.resourceName>" -ForEach $gateways {
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
                . ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("Az.KeyVault")
                
                $elements = $keyVaultSecretId.Split('/')
                $certificateExpiryDate = (Get-AzKeyVaultCertificate -VaultName $elements[2].Split('.')[0] -Name $elements[4]).Expires
            } 

        }

        It "Should have Provisioning State of 'Succeeded'" {
            $resource.ProvisioningState | Should -Be "Succeeded"
        }

        It "The certificate expiry date should be later than $($renewalStartDate.ToString($pipelineConfiguration.dateFormat))" {    
            $certificateExpiryDate | Should -BeGreaterThan $renewalStartDate
        }

        AfterAll {
            Write-Information -MessageData ("`nApplication Gateway certificate expiry date: {0}`n" -f $certificateExpiryDate.ToString($pipelineConfiguration.dateFormat))

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
        Write-Information -MessageData ("`nRunbook: {0}`n" -f $_.runbook)

        Clear-Variable -Name "renewalStartDate"
    }
}

AfterAll {
    Clear-AzContext -Scope CurrentUser -Force
}
