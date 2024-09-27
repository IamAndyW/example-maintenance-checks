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

    $internalConfiguration = (Get-Content -Path $internalConfigurationFilename |
        ConvertFrom-Json -Depth 99)
    
    if ($null -eq $internalConfiguration) {
        throw ("Cannot find configuration: {0} in file: {1}" -f $checkName, $internalConfigurationFilename)
    }

    # building the discovery object
    $discovery = $internalConfiguration
} 

Describe "$($externalConfiguration.checkDisplayName) / <_.organisation>" -ForEach $discovery.$($externalConfiguration.checkName) {

    BeforeAll {
        $accessToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($externalConfiguration.adoAccessToken)"))

        $parameters = @{
            "method" = "GET"
            "headers" = @{
                "Authorization" = ("Basic {0}" -f $accessToken)
                "Accept" = "application/json"
            }
        }

        $baseURL = $_.baseURL
        $organisation = $_.organisation
    }

    Context "Project: <_.name>" -ForEach $_.projects {

        BeforeAll {
            $projectName = $_.name
        }
        
        It "Build result for <_.buildName> with branch: <_.buildBranch> should be 'succeeded'" -ForEach $_.builds {
            $queryParameters = ("name={0}&api-version={1}" -f $_.buildName, "7.1")
            $parameters.Add('uri', ("{0}/{1}/{2}/_apis/{3}?{4}" -f $baseURL, $organisation, $projectName, "build/definitions", $queryParameters))
            $definitionIds = (Invoke-RestMethod @parameters | Write-Output).value.id

            foreach ($definitionId in $definitionIds ) {
                $parameters.Remove('uri')
                
                $queryParameters = ("`$top=1&branchName={0}&definitions={1}&queryOrder=finishTimeDescending&statusFilter=completed&api-version={2}" -f $_.buildBranch, $definitionId, "7.1")
                $parameters.Add('uri', ("{0}/{1}/{2}/_apis/{3}?{4}" -f $baseURL, $organisation, $projectName, "build/builds", $queryParameters))

                (Invoke-RestMethod @parameters | Write-Output).value.result | Should -Be "succeeded"
            }
        }

        AfterEach {
            $parameters.Remove('uri')
            Clear-Variable -Name "queryParameters"
            Clear-Variable -Name "definitionIds"
            Clear-Variable -Name "definitionId"
        }

        AfterAll {
            Clear-Variable -Name "projectName"
        }
    }

    AfterAll {
        Clear-Variable -Name "accessToken"
        Clear-Variable -Name "parameters"
        Clear-Variable -Name "organisation"
        Clear-Variable -Name "baseURL"
    }
}
