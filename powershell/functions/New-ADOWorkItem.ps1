Function New-ADOWorkItem {
	
    [CmdletBinding()]
    param (

        [Parameter(Mandatory=$false)]
        [hashtable]$headers = @{"content-type" = "application/json-patch+json"},

        [Parameter(Mandatory=$true)]
        [ValidateScript({            
            If ([uri]::IsWellFormedUriString($_,[urikind]::Absolute)) {Return $true}
        })]
        [string]$baseURL,

        [Parameter(Mandatory=$false)]
        [string]$apiVersion = "7.1",

        [Parameter(Mandatory=$true)]
        [string]$systemAccessToken,
        
        [Parameter(Mandatory=$false)]
        [string]$wiType = "User Story",

        [Parameter(Mandatory=$true)]
        [string]$wiTitle,

        [Parameter(Mandatory=$true)]
        [string]$wiDescription
    )

    $parameters = @{
        method = "POST"
        headers = $headers
    }

    $accessToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($systemAccessToken)"))
    $queryParameters = ("api-version={0}" -f $apiVersion)
    $body = @(
        @{
            op = "add"
            path = "/fields/System.Title"
            from = $null
            value = ("{0}" -f $wiTitle)
        }
        @{
            op = "add"
            path = "/fields/System.Description"
            from = $null
            value = ("{0}" -f $wiDescription)
        }
    ) | ConvertTo-Json

    $parameters.Add('uri', [URI]::EscapeUriString(("{0}/_apis/{1}?{2}" -f $baseURL, ("wit/workitems/`${0}" -f $wiType), $queryParameters)))
    $parameters.headers.Add('Authorization', ("Basic {0}" -f $accessToken))
    $parameters.Add('body', $body)
    
    $response = Invoke-RestMethod @parameters | Write-Output
    
    return $response
}
