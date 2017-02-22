<#
.Synopsis
    Finds the min, max, average and standard deviation of processes over a time window
#>
Param(
    $Window = 30
)

function Get-StandardDeviation
{
    [CmdletBinding()]            
    param (            
      [double[]]$Numbers,
      [int]$Count,
      [double]$Average
    )            
            
    $popdev = 0            
            
    foreach ($number in $numbers){            
      $popdev +=  [math]::pow(($number - $Average), 2)            
    }            
            
    $sd = [math]::sqrt($popdev / ($Count-1))            
    Return $sd
}

$Null = $(
    $EndTime = (Get-Date).AddSeconds($Window)
    $PollFrequency = 5

    $ProcessTable = @{}

    While(($RunTime = (Get-Date)).CompareTo($EndTime) -lt 0)
    {

        Get-Process | ForEach-Object -Process {
            if($ProcessTable.ContainsKey("$($_.ProcessName)|$($_.Id)"))
            {
                ($ProcessTable."$($_.ProcessName)|$($_.Id)").Add($_.CPU)
            }
            else
            {
                $ItemList = New-Object -TypeName "System.Collections.Generic.List[double]"
                $ItemList.Add($_.CPU)
                $ProcessTable.Add("$($_.ProcessName)|$($_.Id)", $ItemList)
            }
        }
    
        if(($SleepTime = ($RunTime.AddSeconds($PollFrequency) - (Get-Date)).TotalSeconds) -gt 0)
        {
            Start-Sleep -Seconds $SleepTime
        }
    }

    $ReturnArray = New-Object -TypeName System.Collections.ArrayList
    Foreach($Key in $ProcessTable.Keys)
    {
        $Values = $ProcessTable.$Key | Measure-Object -Sum -Average -Maximum -Minimum
        $StdDev = Get-StandardDeviation -Numbers $ProcessTable.$Key -Count $Values.Count -Average $Values.Average

        $ReturnArray.Add("$Key|$($Values.Average)|$($Values.Maximum)|$($Values.Minimum)|$($StdDev)")
    }
)

$ReturnArray