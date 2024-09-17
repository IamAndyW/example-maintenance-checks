[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]
    $tenantId = $env:ARM_TENANT_ID,
    
    [Parameter(Mandatory = $false)]
    [string]
    $subscriptionId = $env:ARM_SUBSCRIPTION_ID,

    [Parameter(Mandatory = $false)]
    [string]
    $clientId = $env:ARM_CLIENT_ID,

    [Parameter(Mandatory = $false)]
    [string]
    $clientSecret = $env:ARM_CLIENT_SECRET
)

. $PSScriptRoot/Install-PowerShellModules.ps1 -modules ("Az.Accounts")

$secureClientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$clientId = $clientId
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $secureClientSecret
Connect-AzAccount -ServicePrincipal -TenantId $tenantId -Credential $credential -Subscription $subscriptionId

$azContext = Get-AzContext
return Write-Host ("`nTenantId: {0}`nSubscription Name: {1}" -f $azContext.Tenant.Id, $azContext.Subscription.Name)
