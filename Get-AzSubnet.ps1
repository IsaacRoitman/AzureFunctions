using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$VnetName = $Request.Query.VnetName
if (-not $VnetName) {
    $VnetName = $Request.Body.VnetName
}

# PowerShell function code
function Get-AzSubnet
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$SubscriptionName,
        [string]$VnetName
    )

    if ($SubscriptionName) {
        $subscription = Get-AzSubscription -SubscriptionName $SubscriptionName -WarningAction Ignore
        $subscriptionId = $subscription.SubscriptionId
    }
    else {
        $subscription = (Get-AzContext).Subscription
        $subscriptionId = $subscription.Id
    }

    $vnet = Search-AzGraph -Query "Resources 
    | where type == 'microsoft.network/virtualnetworks' 
    | where subscriptionId == '$subscriptionId'
    | where name == '$VnetName'"

    $subnets = $vnet.properties.subnets

    foreach ($subnet in $subnets)
    {
        [PSCustomObject]@{
            subscriptionName = $subscription.name
            subscriptionId = $vnet.subscriptionId
            location = $vnet.location
            resourceGroup = $vnet.resourceGroup
            vnetName = $vnet.name
            vnetAddressSpace = $vnet.properties.addressSpace.addressPrefixes[0]
            subnetName = $subnet.name
            subnetAddressSpace = $subnet.properties.addressPrefix        
        }
    }
}

# Run command to generate subnet output
if ($VnetName) {
    $output = Get-AzSubnet -VnetName $VnetName
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $output
})
