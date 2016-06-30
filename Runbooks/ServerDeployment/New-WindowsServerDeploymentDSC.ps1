<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName New-WindowsServerDeploymentDSC

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'AutomationAccountName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$RunbookWorkerAccessCredential = Get-AutomationPSCredential -Name 'ryan'


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName
    
    $RegistrationInfo = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName $GlobalVars.ResourceGroupName `
                                                              -AutomationAccountName $GlobalVars.AutomationAccountName

    $VMName = "$(New-RandomString -MinLength 5 -MaxLength 5 -InputString 'abcdefghijklmnopqrstuvwxyz')"
    $ResourceGroupName = 'tempserver'

    New-AzureRmResourcegroup -Name $ResourceGroupName `
                             -Location 'eastus2' `
                             -Verbose `
                             -Force

    New-AzureRmResourceGroupDeployment -Name InitialDeployment `
                                       -TemplateFile 'C:\git\ScorchDev\ARM\Iaas-WindowsVM-DSC\azuredeploy.json' `
                                       -adminUsername $RunbookWorkerAccessCredential.UserName `
                                       -adminPassword $RunbookWorkerAccessCredential.Password `
                                       -storageAccountName "$($ResourceGroupName.ToLower())store" `
                                       -vmName $VMName `
                                       -ResourceGroupName $ResourceGroupName `
                                       -registrationUrl $RegistrationInfo.Endpoint `
                                       -registrationKey ($RegistrationInfo.PrimaryKey | ConvertTo-SecureString -AsPlainText -Force) `
                                       -serverConfiguration 'DomainComputer.MemberServerDev' `
                                       -Verbose
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
