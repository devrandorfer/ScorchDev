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
    
    $ResourceGroup = Get-AzureRmResourceGroup -Name 'Lab_Winteam'

    # Create the policy definition
    $Compute = @'
    {
      "if" : {
        "not" : {
          "anyOf" : [
            {
              "field" : "type",
              "like" : "Microsoft.Resources/*"
            },
            {
              "field" : "type",
              "like" : "Microsoft.Compute/*"
            },
            {
              "field" : "type",
              "like" : "Microsoft.Storage/*"
            },
            {
              "field" : "type",
              "equals" : "Microsoft.Network/networkInterfaces"
            },
            {
              "field" : "type",
              "equals" : "Microsoft.Network/applicationGateways"
            },
            {
              "field" : "type",
              "equals" : "Microsoft.Network/loadBalancers"
            },
            {
              "field" : "type",
              "equals" : "Microsoft.Network/networkSecurityGroups"
            },
            {
              "field" : "type",
              "equals" : "Microsoft.Network/trafficmanagerprofiles"
            }
          ]
        }
      },
      "then" : {
        "effect" : "deny"
      }
    }
'@
    $StorageSKU = @'
    {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Storage/storageAccounts"
          },
          {
            "not": {
              "allof": [
                {
                  "field": "Microsoft.Storage/storageAccounts/sku.name",
                  "in": ["Standard_LRS", "Standard_ZRS"]
                }
              ]
            }
          }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
'@

    $ComputePolicy = New-AzureRmPolicyDefinition -Name ComputePolicy -Description 'Curated Compute' -Policy $Compute
    $StorageSKUPolicy = New-AzureRmPolicyDefinition -Name StorageSKUPolicy -Description 'Curated Storage SKU' -Policy $StorageSKU
    $WindowsSKUPolicy = New-AzureRmPolicyDefinition -Name WindowsSKUPolicy -Description 'Curated Windows SKU' -Policy $WindowsSKU
    
    New-AzureRmPolicyAssignment -Name ComputePolicy_Assignment `
                                -PolicyDefinition $ComputePolicy `
                                -Scope $ResourceGroup.ResourceId

    New-AzureRmPolicyAssignment -Name StorageSKUPolicy_Assignment `
                                -PolicyDefinition $StorageSKUPolicy `
                                -Scope $ResourceGroup.ResourceId

    New-AzureRmPolicyAssignment -Name WindowsSKUPolicy_Assignment `
                                -PolicyDefinition $WindowsSKUPolicy `
                                -Scope $ResourceGroup.ResourceId
    
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