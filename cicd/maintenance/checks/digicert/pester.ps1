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

    # building the discovery object
    $discovery = $internalConfiguration
}

Describe $externalConfiguration.checkDisplayName -ForEach $discovery.$($externalConfiguration.checkName) {

    BeforeAll {
        $parameters = @{
            "method" = "GET"
            "headers" = @{
                "content-type" = "application/json"
                "X-DC-DEVKEY" = $externalConfiguration.digicertAPIkey
            }
        }

        $baseURL = $_.baseURL
        $organisationId = $externalConfiguration.digicertOrganisationId

        $organisationURL = ("{0}/{1}" -f $baseURL, ("organization/{0}" -f $organisationId))
        $reportURL = ("{0}/{1}" -f $baseURL, "report")
        $financeURL = ("{0}/{1}" -f $baseURL, "finance")
    }

    Context "Organisation" {
        
        It "The organisation status should be 'active'" {
            $parameters.Add('uri', ("{0}" -f $organisationURL))
            $response = (Invoke-RestMethod @parameters).status
            
            $response  | Should -BeExactly "active"
        }

        It "The organisation contact and technical contact should be correct" {
            $parameters.Add('uri', ("{0}/{1}" -f $organisationURL, "contact"))
            $response = Invoke-RestMethod @parameters

            $response.organization_contact.name | Should -Be $_.organisationContact
            $response.technical_contact.name | Should -Be $_.technicalContact
        }

        It "The organisation validation (OV) should be valid within the next <_.ordersExpiringRenewBeforeInDays> days" {
            $parameters.Add('uri', ("{0}/{1}" -f $organisationURL, "validation"))
            $response = Invoke-RestMethod @parameters

            ($response.validations | Where-Object {$_.type -eq "ov"}).validated_until |
                Should -BeGreaterThan $externalConfiguration.checkDateTime.AddDays($_.ordersExpiringRenewBeforeInDays)
        }

        AfterEach {
            $parameters.Remove('uri')
            Clear-Variable -Name "response"
        }
    }

    Context "Orders" {
        
        It "There should be no expirying orders within the next <_.ordersExpiringRenewBeforeInDays> days" {
            $parameters.Add('uri', ("{0}/{1}" -f $reportURL, "order/expiring"))
            $ordersExpiringRenewBeforeInDays = $_.ordersExpiringRenewBeforeInDays

            $response = Invoke-RestMethod @parameters

            ($response.expiring_orders | Where-Object {$_.days_expiring -eq $ordersExpiringRenewBeforeInDays}).order_count | Should -Be 0
        }

        AfterEach {
            $parameters.Remove('uri')
            Clear-Variable -Name "response"
        }
    }

    Context "Finance" {
        
        It "If there are expirying orders within 60 days, the total available funds in USD should be greater than <_.totalAvailableFundsMinInUSD> USD" {
            $parameters.Add('uri', ("{0}/{1}" -f $reportURL, "order/expiring"))

            $response = Invoke-RestMethod @parameters

            if (($response.expiring_orders | Where-Object {$_.days_expiring -eq 60}).order_count -ne 0) {
                Clear-Variable -Name "response"
                $parameters.Remove('uri')
                $parameters.Add('uri', ("{0}/{1}" -f $financeURL, "balance"))

                $response = Invoke-RestMethod @parameters

                [decimal]$response.total_available_funds | Should -BeGreaterOrEqual $_.totalAvailableFundsMinInUSD
            }
        }

        AfterEach {
            $parameters.Remove('uri')
            Clear-Variable -Name "response"
        }
    }

    AfterAll {
        Clear-Variable -Name "parameters"
        Clear-Variable -Name "baseURL"
        Clear-Variable -Name "organisationId"
        Clear-Variable -Name "organisationURL"
        Clear-Variable -Name "reportURL"
        Clear-Variable -Name "financeURL"
    }
}
