Function Get-ADOWorkItemById {
	
    [CmdletBinding()]
    param (

        [Parameter(Mandatory=$false)]
        [hashtable]$headers = @{"content-type" = "application/jsonn"},

        [Parameter(Mandatory=$false)]
        [ValidateScript({            
            If ([uri]::IsWellFormedUriString($_,[urikind]::Absolute)) {Return $true}
        })]
        [string]$baseURL = ("{0}{1}" -f $env:SYSTEM_COLLECTIONURI, $env:SYSTEM_TEAMPROJECT),

        [Parameter(Mandatory=$false)]
        [string]$apiVersion = "7.1",

        [Parameter(Mandatory=$false)]
        [string]$systemAccessToken = $env:SYSTEM_ACCESSTOKEN,
        
        [Parameter(Mandatory=$true)]
        [string]$wiId
    )

    $parameters = @{
        method = "GET"
        headers = $headers
    }

    $accessToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($systemAccessToken)"))
    $queryParameters = ("`$expand=relations&api-version={0}" -f $apiVersion)

    $parameters.Add('uri', [URI]::EscapeUriString(("{0}/_apis/{1}?{2}" -f $baseURL, ("wit/workitems/{0}" -f $wiId), $queryParameters)))
    $parameters.headers.Add('Authorization', ("Basic {0}" -f $accessToken))
   
    $response = Invoke-RestMethod @parameters | Write-Output
    
    return $response
}
