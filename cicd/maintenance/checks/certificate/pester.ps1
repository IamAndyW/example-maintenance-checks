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

Describe $((Get-Culture).TextInfo.ToTitleCase($(Split-Path -Path $PSScriptRoot -Leaf).Replace('_', ' '))) {

    BeforeAll {
        Write-Host "`n"

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
    }

    Context "Digicert" -Tag "prod" {
        
        BeforeAll {
            Write-Host "`n"

            $webRequestParameters = @{
                "method" = "GET"
                "headers" = @{
                    "content-type" = "application/json"
                    "X-DC-DEVKEY" = $runtimeConfiguration.digicertAPIkey
                }
            }

            $baseURL = $checkConfiguration.digicert.baseURL
            $organisationId = $runtimeConfiguration.digicertOrganisationId
        }

        # // START of tests //
        It "The organisation status should be 'active'" {
            $webRequestParameters.Add('uri', ("{0}/{1}" -f $baseURL, ("organization/{0}" -f $organisationId)))

            $response = (Invoke-WebRequest @webRequestParameters -UseBasicParsing -ErrorAction Stop).RawContent -split "`n" |
            Where-Object { $_ -match '^\s*{.*}\s*$' } |
                Out-String |
                    ConvertFrom-Json -Depth 99

            $response.status | Should -BeExactly "active"
        }

        It "The organisation contact and technical contact should be correct" {
            $webRequestParameters.Add('uri', ("{0}/{1}" -f $baseURL, ("organization/{0}/contact" -f $organisationId)))

            $response = (Invoke-WebRequest @webRequestParameters -UseBasicParsing -ErrorAction Stop).RawContent -split "`n" |
            Where-Object { $_ -match '^\s*{.*}\s*$' } |
                Out-String |
                    ConvertFrom-Json -Depth 99

            $response.organization_contact.name | Should -Be $checkConfiguration.digicert.organisationContact
            $response.technical_contact.name | Should -Be $checkConfiguration.digicert.technicalContact
        }

        It "There should be no expirying orders within the renewal window" {
            $webRequestParameters.Add('uri', ("{0}/{1}" -f $baseURL, "report/order/expiring"))

            $response = (Invoke-WebRequest @webRequestParameters -UseBasicParsing -ErrorAction Stop).RawContent -split "`n" |
            Where-Object { $_ -match '^\s*{.*}\s*$' } |
                Out-String |
                    ConvertFrom-Json -Depth 99

            ($response.expiring_orders | Where-Object {$_.days_expiring -eq $checkConfiguration.digicert.ordersExpiringRenewBeforeInDays}).order_count | Should -Be 0
        }

        It "The organisation validation (OV) should be valid within the expirying orders renewal window" {
            $webRequestParameters.Add('uri', ("{0}/{1}" -f $baseURL, ("organization/{0}/validation" -f $organisationId)))

            $response = (Invoke-WebRequest @webRequestParameters -UseBasicParsing -ErrorAction Stop).RawContent -split "`n" |
            Where-Object { $_ -match '^\s*{.*}\s*$' } |
                Out-String |
                    ConvertFrom-Json -Depth 99

            ($response.validations | Where-Object {$_.type -eq "ov"}).validated_until -gt (Get-Date).AddDays($checkConfiguration.digicert.ordersExpiringRenewBeforeInDays) | Should -Be $true
        }

        It "If there are expirying orders within 60 days, the total available funds in USD should be enough to cover certificate renewal" {
            $webRequestParameters.Add('uri', ("{0}/{1}" -f $baseURL, "report/order/expiring"))

            $response = (Invoke-WebRequest @webRequestParameters -UseBasicParsing -ErrorAction Stop).RawContent -split "`n" |
            Where-Object { $_ -match '^\s*{.*}\s*$' } |
                Out-String |
                    ConvertFrom-Json -Depth 99

            if (($response.expiring_orders | Where-Object {$_.days_expiring -eq 60}).order_count -ne 0) {
                Clear-Variable -Name "response"
                $webRequestParameters.Remove('uri')
                $webRequestParameters.Add('uri', ("{0}/{1}" -f $baseURL, "finance/balance"))

                $response = (Invoke-WebRequest @webRequestParameters -UseBasicParsing -ErrorAction Stop).RawContent -split "`n" |
                Where-Object { $_ -match '^\s*{.*}\s*$' } |
                    Out-String |
                        ConvertFrom-Json -Depth 99

                [decimal]$response.total_available_funds | Should -BeGreaterOrEqual $checkConfiguration.digicert.totalAvailableFundsMinInUSD
            }
        }
        # // END of tests //

        AfterEach {
            $webRequestParameters.Remove('uri')
            Clear-Variable -Name "response"
        }

        AfterAll {
            Write-Host ("`nDigicert orders expiring renewal window in days: {0}`n" -f $checkConfiguration.digicert.ordersExpiringRenewBeforeInDays)
            
            Clear-Variable -Name "webRequestParameters"
            Clear-Variable -Name "baseURL"
            Clear-Variable -Name "organisationId"
        }
    }

    Context "Application Gateway: '<_.resourceGroupName>/<_.resourceName>'" -Tag "nonprod", "prod" -ForEach $discovery {

        BeforeAll {
            Write-Host "`n"

            # Azure authentication
            . ../../powershell/Connect-Azure.ps1
            
            # installing dependencies
            . ../../powershell/Install-PowerShellModules.ps1 -modules ("Az.Network")
            
            $resourceGroupName = $_.resourceGroupName
            $resourceName = $_.resourceName

            try {
                $azureResource = Get-AzApplicationGateway -ResourceGroupName $resourceGroupName -Name $resourceName
            }
            catch {
                throw ("Cannot find resource: '{0}' in resource group" -f $resourceName, $resourceGroupName)
            }
            
            if ([string]::IsNullOrEmpty($azureResource.SslCertificates.KeyVaultSecretId)) {
                $keyVaultSecretId = $null
                
                $certificateBytes = [Convert]::FromBase64String($azureResource.SslCertificates.PublicCertData)
                $p7b = New-Object System.Security.Cryptography.Pkcs.SignedCms
                $p7b.Decode($certificateBytes)
                $certificateExpiryDate = $p7b.Certificates[0].NotAfter

            } else {
                # installing dependencies
                . ../../powershell/Install-PowerShellModules.ps1 -modules ("Az.KeyVault")
                
                $keyVaultSecretId = $azureResource.SslCertificates.KeyVaultSecretId
                $elements = $keyVaultSecretId.Split('/')
                $certificateExpiryDate = (Get-AzKeyVaultCertificate -VaultName $elements[2].Split('.')[0] -Name $elements[4]).Expires
            }       

            Write-Host "`n"
        }

        # // START of tests //
        It "Should have 'ProvisioningState' of 'Succeeded'" {
            $azureResource.ProvisioningState | Should -Be "Succeeded"
        }
        
        It "The Ssl certificate should not be in the renewal window (now + <_.certificateRenewalBeforeInDays> days)" {    
            $certificateExpiryDate -gt (Get-Date).AddDays($_.certificateRenewalBeforeInDays) | Should -Be $true
        }
        # // END of tests //

        AfterAll {
            Write-Host ("`nApplication Gateway certificate expiry date: {0}`n" -f $certificateExpiryDate.ToString("dd/MM/yyyy HH:mm:ss"))
            
            Clear-Variable -Name "resourceGroupName"
            Clear-Variable -Name "resourceName"
            Clear-Variable -Name "azureResource"
            Clear-Variable -Name "certificateBytes" -ErrorAction Continue
            Clear-Variable -Name "p7b" -ErrorAction Continue
            Clear-Variable -Name "keyVaultSecretId"
            Clear-Variable -Name "certificateExpiryDate"
        }
    }

    AfterAll {
        Clear-Variable -Name "checkConfigurationFilename"
        Clear-Variable -Name "stageName"
        Clear-Variable -Name "checkName"
        Clear-Variable -Name "checkConfiguration"
    }
}
