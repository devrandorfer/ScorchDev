function Get-InstalledUpdate
{
    <#
    .Synopsis
        Gets updates installed on the system
    .Description
        Gets windows and microsoft updates installed on the system
    .Example
        Get-InstalledUpdate
    .Link
        Get-InstalledKBNumber
    #>
    param(
        $ComputerName,
        $Credential
    )
    
    begin {
        if($ComputerName) 
        {
            $Params = @{
                'ComputerName' = $ComputerName
            }
            if($Credential) { $Params.Add('Credential', $Credential) }
            Enter-PSSession @Params
        }
    }
    
    process {
    
        $objSession = 

        $srch = (New-Object -ComObject "Microsoft.Update.Session").CreateUpdateSearcher()
    	$count = $srch.GetTotalHistoryCount()
        for ($i = 0; $i -lt $count; $i++) {
            $perc = $i * 100 / $count
            Write-Progress "Getting Update History" "Update $i" -PercentComplete $perc
            $srch.QueryHistory($i, 1)        
        }
        Write-Progress "Getting Update History" "Completed" -Completed
    
    }

    end {
        if($ComputerName) { Exit-PSSession }
    }
}
    
