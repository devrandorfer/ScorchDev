<#
    .Synopsis
        Sets the current AzureRM policy for the target subscription(s)
#>

Param(
)

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'AutomationAccountName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName
    
    $ResourceGroup = Get-AzureRmResourceGroup

    # Create the policy definition
    $NoPublicDefinition = @'
    {
        "if": {
            "anyOf":[{
                "source":"action",
                "like":"Microsoft.Network/publicIPAddresses/*"
            }]
        },
        "then":{"effect":"deny"}
    }
'@
    $PublicDefinition = @'
    {
        "if": {
            "anyOf":[{
                "source":"action",
                "like":"Microsoft.Network/publicIPAddresses/*"
            }]
        },
        "then":{"effect":"audit"}
    }
'@
    $policydef = New-AzureRmPolicyDefinition -Name NoPubIPPolicyDefinition -Description 'No public IP addresses allowed' -Policy $NoPublicDefinition
    $PublicIpPolicydef = New-AzureRmPolicyDefinition -Name PubIPPolicyDefinition -Description 'Public IP addresses allowed' -Policy $PublicDefinition
    
    $Subscription = Get-AzureRmSubscription -SubscriptionName $GlobalVars.SubscriptionName
    
    New-AzureRmPolicyAssignment -Name NoPublicIPPolicyAssignment `
                                -PolicyDefinition $PublicIpPolicydef `
                                -Scope /Subscriptions/$Subscription
    
    Foreach($_ResourceGroup in $ResourceGroup)
    {
        $NetworkingTag = $_ResourceGroup.Tags | Where-Object { $_.Name -eq 'Networking' }
        if($NetworkingTag)
        {
            if(($_ResourceGroup.Tags | Where-Object { $_.Name -eq 'Networking' }).Value -eq 'Public')
            {
                New-AzureRmPolicyAssignment -Name NoPublicIPPolicyAssignment `
                                            -PolicyDefinition $policydef `
                                            -Scope $_ResourceGroup.ResourceId
            }
        }
    }
}
Catch
{
    $Exception = $_
    $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
    Switch ($ExceptionInfo.FullyQualifiedErrorId)
    {
        Default
        {
            Write-Exception $Exception -Stream Warning
        }
    }
}