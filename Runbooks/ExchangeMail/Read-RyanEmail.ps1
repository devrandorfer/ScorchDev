<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script!

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Read-RyanEmail

$Vars = Get-BatchAutomationVariable -Name  'AccessCredentialName',
                                           'WebserviceURL' `
                                    -Prefix 'RyanEmail'

$Credential = Get-AutomationPSCredential -Name $Vars.AccessCredentialName

Try
{
    $Connection = New-EWSMailboxConnection -Credential $Credential -webserviceURL $Vars.WebserviceURL
    $Connection | Read-EWSEmail -maxEmailCount 1 -doNotMarkRead -readMailFilter All
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
