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
            vnetName = $vnet.name
            location = $vnet.location
            resourceGroup = $vnet.resourceGroup
            vnetAddressSpace = $vnet.properties.addressSpace.addressPrefixes[0]
            subnetName = $subnet.name
            subnetAddressSpace = $subnet.properties.addressPrefix        
        }
    }
}

<#
#   We query the vnet for a CIDR range of subnet e.g either range /26/27 or subnet x.x.x.x/26
#   API to return next available subnet or tell us if the given subnet is available in the Vnet or not
#
#>

function ConvertTo-IPv4MaskString {
    param (
        [parameter(Mandatory=$true)]
        [ValidateRange(0,32)]
        [Int]$MaskBits
    )
    $mask = ([Math]::Pow(2, $MaskBits) - 1) * [Math]::Pow(2, (32 - $MaskBits))
    $bytes = [BitConverter]::GetBytes([UInt32] $mask)
    (($bytes.Count - 1)..0 | ForEach-Object { [String] $bytes[$_] }) -join "."
}

function Compare-Subnets
{
    param (
        [parameter(Mandatory=$true)]
        [Net.IPAddress]
        $Subnet1,
     
        [parameter(Mandatory=$true)]
        [Net.IPAddress]
        $Subnet2,
     
        [parameter()]
        [Net.IPAddress]$SubnetMask,

        [parameter()]
        [int]$MaskBits
    )
    
    if ($MaskBits) {
        [Net.IPAddress]$SubnetMask = ConvertTo-IPv4MaskString -MaskBits $MaskBits
    }
    
    if (($Subnet1.address -band $SubnetMask.address) -eq ($Subnet2.address -band $SubnetMask.address)) {
        $true
    }
    else {
        $false
    } 
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
