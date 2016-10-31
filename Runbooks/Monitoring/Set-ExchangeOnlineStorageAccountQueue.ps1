<#
    .SYNOPSIS
       Script to collect Exchange Online log data and ingest it into Log Analytics

    .Description
       Script to collect Exchange Online log data and ingest it into Log Analytics

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Set-ExchangeOnlineStorageAccountQueue

$Office365Vars = Get-BatchAutomationVariable -Prefix 'Office365' `
                                             -Name 'CredentialName'

$ExchangeOnlineVars = Get-BatchAutomationVariable -Prefix 'ExchangeOnline' `
                                                  -Name 'StorageAccountName',
                                                        'StorageAccountResourceGroupName',
                                                        'QueueName'

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant'

$Office365Credential = Get-AutomationPSCredential -Name $Office365Vars.CredentialName
$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName

$DataType = @(
    'MessageTrace',
    'MailDetailMalwareReport',
    'MailDetailSpamReport'
)

# AdvancedThreatProtectionTraffic
# URLTrace

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

    $StorageAccount = Get-AzureRmStorageAccount -StorageAccountName $ExchangeOnlineVars.StorageAccountName -ResourceGroupName $ExchangeOnlineVars.StorageAccountResourceGroupName

    Try
    {
        $Queue = Get-AzureStorageQueue -Name $ExchangeOnlineVars.QueueName -Context $StorageAccount.Context
    }
    Catch
    {
        $Queue = New-AzureStorageQueue -Name $ExchangeOnlineVars.QueueName -Context $StorageAccount.Context
    }

    #Build List of currently queued users
    $CurrentDataType = @()
    Do
    {
        $Message = $Queue.CloudQueue.GetMessage()
        if($Message -eq $Null) { break }
        $CurrentDataType += $Message.AsString.Split(';')[0]
    }
    While($Message -ne $Null)

    #Add new users into the queue
    Foreach($_DataType in $DataType)
    {
        if($_DataType -inotin $CurrentDataType)
        {
            $QueueMessage = New-Object -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage `
                                       -ArgumentList "$_DataType;$((Get-Date).AddDays(-30).ToUniversalTime().ToString())"
            $Queue.CloudQueue.AddMessage($QueueMessage)        
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

Write-CompletedMessage @CompletedParameters

