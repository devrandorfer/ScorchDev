$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                       -SubscriptionName $GlobalVars.SubscriptionName `
                       -Tenant $GlobalVars.SubscriptionAccessTenant


Get-AzureRMVMImage -Location 'West Europe' `
                   -Offer 'WindowsServer' `
                   -PublisherName 'MicrosoftWindowsServer' `
                   -Skus '2012-R2-Datacenter'