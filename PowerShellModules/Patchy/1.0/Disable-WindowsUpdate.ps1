function Disable-WindowsUpdate
{
    <#
    .Synopsis
        Disables automatic updates
    .Description
        Disables automatic updates on the current machine
    .Link
        Enable-WindowsUpdate
    #>
    Param(
        [string]$ComputerName,
        [PSCredential]$Credential
    )

    if($ComputerName) 
    {
        $Params = @{
            'ComputerName' = $ComputerName
        }
        if($Credential) { $Params.Add('Credential', $Credential) }
        Enter-PSSession @Params
    }
    $AUSettigns = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
    $AUSettigns.NotificationLevel = 1
    $AUSettigns.Save()    

    if($ComputerName) { Exit-PSSession }
} 
