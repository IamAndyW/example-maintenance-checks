param (
    [Parameter(Mandatory = $true)]
    [hashtable] $runtimeConfiguration
)

Describe $runtimeConfiguration.checkDisplayName {

    BeforeAll {
        Write-Host "`n"

        $checkConfigurationFilename = $runtimeConfiguration.checkConfigurationFilename
        $stageName = $runtimeConfiguration.stageName
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

        $webRequestParameters = @{
            "method" = "GET"
            "headers" = @{
                "content-type" = "application/json"
                "X-DC-DEVKEY" = $runtimeConfiguration.digicertAPIkey
            }
        }

        $baseURL = $checkConfiguration.baseURL
        $organisationId = $runtimeConfiguration.digicertOrganisationId
    }

    Context "Organisation" {
        
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

            $response.organization_contact.name | Should -Be $checkConfiguration.organisationContact
            $response.technical_contact.name | Should -Be $checkConfiguration.technicalContact
        }

        It "The organisation validation (OV) should be valid within the expirying orders renewal window" {
            $webRequestParameters.Add('uri', ("{0}/{1}" -f $baseURL, ("organization/{0}/validation" -f $organisationId)))

            $response = (Invoke-WebRequest @webRequestParameters -UseBasicParsing -ErrorAction Stop).RawContent -split "`n" |
            Where-Object { $_ -match '^\s*{.*}\s*$' } |
                Out-String |
                    ConvertFrom-Json -Depth 99

            ($response.validations | Where-Object {$_.type -eq "ov"}).validated_until -gt $runtimeConfiguration.checkDateTime.AddDays($checkConfiguration.ordersExpiringRenewBeforeInDays) | Should -Be $true
        }

        AfterEach {
            $webRequestParameters.Remove('uri')
            Clear-Variable -Name "response"
        }
    }

    Context "Orders" {
        
        It "There should be no expirying orders within the renewal window" {
            $webRequestParameters.Add('uri', ("{0}/{1}" -f $baseURL, "report/order/expiring"))

            $response = (Invoke-WebRequest @webRequestParameters -UseBasicParsing -ErrorAction Stop).RawContent -split "`n" |
            Where-Object { $_ -match '^\s*{.*}\s*$' } |
                Out-String |
                    ConvertFrom-Json -Depth 99

            ($response.expiring_orders | Where-Object {$_.days_expiring -eq $checkConfiguration.ordersExpiringRenewBeforeInDays}).order_count | Should -Be 0
        }

        AfterEach {
            $webRequestParameters.Remove('uri')
            Clear-Variable -Name "response"
        }

        AfterAll {
            Write-Host ("`nDigicert orders expiring renewal window in days: {0}`n" -f $checkConfiguration.ordersExpiringRenewBeforeInDays)
        }
    }

    Context "Finance" {
        
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

                [decimal]$response.total_available_funds | Should -BeGreaterOrEqual $checkConfiguration.totalAvailableFundsMinInUSD
            }
        }

        AfterEach {
            $webRequestParameters.Remove('uri')
            Clear-Variable -Name "response"
        }
    }

    AfterAll {
        Clear-Variable -Name "checkConfigurationFilename"
        Clear-Variable -Name "stageName"
        Clear-Variable -Name "checkName"
        Clear-Variable -Name "checkConfiguration"
        Clear-Variable -Name "webRequestParameters"
        Clear-Variable -Name "baseURL"
        Clear-Variable -Name "organisationId"
    }
}
