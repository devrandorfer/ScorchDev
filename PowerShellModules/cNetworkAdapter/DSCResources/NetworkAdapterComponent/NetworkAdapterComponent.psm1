# updated to add a paramter to suppress restart

if(([environment]::OSVersion.Version).Major -ge 6)
{
    if(([environment]::OSVersion.Version).Major -gt 6)
    {
        $Above2012R2 = $true
    }
    elseif (([environment]::OSVersion.Version).Minor -ge 3)
    {
        $Above2012R2 = $true
    }
    else
    {
        $Above2012R2 = $false
    }
}

function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory)]
        [string] $ComponentId,

        [parameter(Mandatory)]
        [bool] $Enabled
    )

    $ErrorActionPreference = 'Stop'
    $NetworkAdapter = Get-NetAdapter
    
    if($Above2012R2)
    {
        Try
        {
            Foreach($_NetworkAdapter in $NetworkAdapter)
            {
                $NetworkAdapterBinding = Get-NetAdapterBinding -Name $_NetworkAdapter.Name -ComponentID $ComponentId

                if($Enabled -ne $NetworkAdapterBinding.Enabled) { $_Enabled = $NetworkAdapterBinding.Enabled; break }
            }
        }
        Catch {}
    }
    else
    {
        $Result = Invoke-Expression ".\$($PSScriptRoot)\Binary\nvspbind.exe /o $($ComponentId)"
        if($Enabled -eq $true)
        {
            $_Enabled = -not (($Result -join ';') -like '*disabled*')
        }
        else
        {
            $_Enabled = -not ((($Result -join ';') -like '*enabled*'))
        }
    }
    

    $returnValue = @{
        ComponentID = $ComponentId
        Enabled = $_Enabled
    }
    $returnValue
}

function Set-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [string] $AdapterName,

        [parameter(Mandatory)]
        [string] $ComponentId,

        [parameter(Mandatory)]
        [string] $Enabled
    )
    
    $ErrorActionPreference = 'Stop'

    If($Above2012R2)
    {
        $NetworkAdapter = Get-NetAdapter
        Try
        {
            Foreach($_NetworkAdapter in $NetworkAdapter)
            {
                if($Enabled -eq $true)
                {
                    Enable-NetAdapterBinding -Name $_NetworkAdapter.Name -ComponentID $ComponentId | Out-Null
                }
                else
                {
                    Disable-NetAdapterBinding -Name $_NetworkAdapter.Name -ComponentID $ComponentId | Out-Null
                }
            }
        }
        Catch {}
    }
    Else
    {
        if($Enabled -eq $true)
        {
            Invoke-Expression ".\$($PSScriptRoot)\Binary\nvspbind.exe /e * $($ComponentId)"
        }
        else
        {
            Invoke-Expression ".\$($PSScriptRoot)\Binary\nvspbind.exe /d * $($ComponentId)"
        }
    }
}

function Test-TargetResource
{
	[OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory)]
        [string] $ComponentId,

        [parameter(Mandatory)]
        [string] $Enabled
    )

    $AdapterSetting = Get-TargetResource -AdapterName $AdapterName -ComponentId $ComponentId -Enabled $Enabled

    return $Enabled -eq $AdapterSetting.Enabled
}


Export-ModuleMember -Function *-TargetResource
