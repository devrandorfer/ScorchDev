<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

Login-AzureRmAccount

$adminUserCredential = Get-Credential

$automationresourcegroup = 'automationtest'
$automationaccountname = 'scoautotest'

$VMResourceGroupName = 'tempserver'

Try
{
        
    $RegistrationInfo = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName $automationresourcegroup `
                                                              -AutomationAccountName $automationaccountname

    $VMName = "$(New-RandomString -MinLength 5 -MaxLength 5 -InputString 'abcdefghijklmnopqrstuvwxyz')"
    

    New-AzureRmResourcegroup -Name $ResourceGroupName `
                             -Location 'eastus2' `
                             -Verbose `
                             -Force

    New-AzureRmResourceGroupDeployment -Name InitialDeployment `
                                       -TemplateFile 'C:\git\ScorchDev\ARM\Iaas-WindowsVM-DSC\azuredeploy.json' `
                                       -adminUsername $adminUserCredential.UserName `
                                       -adminPassword $adminUserCredential.Password `
                                       -storageAccountName "$($VMResourceGroupName.ToLower())store" `
                                       -vmName $VMName `
                                       -ResourceGroupName $VMResourceGroupName `
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
