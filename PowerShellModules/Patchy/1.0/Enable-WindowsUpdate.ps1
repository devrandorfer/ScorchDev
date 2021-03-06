function Enable-WindowsUpdate
{
    <#
    .Synopsis
        Enables automatic updates    
    .Description
        Enables automatic updates on the current machine
    .Link
        Disable-WindowsUpdate
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
    $AUSettigns.NotificationLevel = 4
    $AUSettigns.Save()    

    if($ComputerName) { Exit-PSSession }
} 
