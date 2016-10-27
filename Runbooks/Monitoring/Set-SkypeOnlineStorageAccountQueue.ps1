<#
    .SYNOPSIS
       Script to collect Skype for Business log data and ingest it into Log Analytics

    .Description
       Script to collect Skype for Business log data and ingest it into Log Analytics

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Set-SkypeOnlineStorageAccountQueue

$Office365Vars = Get-BatchAutomationVariable -Prefix 'Office365' `
                                             -Name 'CredentialName'

$SkypeForBusinessVars = Get-BatchAutomationVariable -Prefix 'SkypeForBusiness' `
                                                    -Name 'StorageAccountName',
                                                          'StorageAccountResourceGroupName',
                                                          'QueueName'

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant'

$Office365Credential = Get-AutomationPSCredential -Name $Office365Vars.CredentialName
$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

    Import-Module 'C:\Program Files\Common Files\Skype for Business Online\Modules\SkypeOnlineConnector'
    New-CsOnlineSession -Credential $Office365Credential | % { Import-PSSession -Session $_ -AllowClobber } | Out-Null
    
    $Users = Get-CsOnlineUser -Filter {Enabled -eq $True} -WarningAction SilentlyContinue | Select-Object -Property UserPrincipalName
    
    $StorageAccount = Get-AzureRmStorageAccount -StorageAccountName $SkypeForBusinessVars.StorageAccountName -ResourceGroupName $SkypeForBusinessVars.StorageAccountResourceGroupName

    Try
    {
        $Queue = Get-AzureStorageQueue -Name $SkypeForBusinessVars.QueueName -Context $StorageAccount.Context
    }
    Catch
    {
        $Queue = New-AzureStorageQueue -Name $SkypeForBusinessVars.QueueName -Context $StorageAccount.Context
    }

    #Build List of currently queued users
    $CurrentUsers = @()
    Do
    {
        $Message = $Queue.CloudQueue.GetMessage()
        if($Message -eq $Null) { break }
        $CurrentUsers += $Message.AsString.Split(';')[0]
    }
    While($Message -ne $Null)

    #Add new users into the queue
    Foreach($User in $Users)
    {
        if($User -inotin $CurrentUsers)
        {
            $QueueMessage = New-Object -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage `
                                       -ArgumentList "$($User.UserPrincipalName);$((Get-Date).ToUniversalTime().ToString())"
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

