$StartingLat = 45.2088139415905 -as [double]
$StartingLong = -93.4882834291458 -as [double]
$Distance = .008 -as [double]

$ScanTable = @{}

for($i = 0 ; $i -gt -70 ; $i-=1)
{
    $Page = new-object -typename system.collections.arraylist
    for($j = 0 ; $j -lt 75; $j++)
    {
        $ScanningLat = $StartingLat + ($Distance * $i)
        $ScanningLong = $StartingLong + ($Distance * $j)
        
        $Request = invoke-webrequest -uri "https://pokevision.com/map/data/$ScanningLat/$ScanningLong"
        $Pokemon = ($Request.Content | ConvertFrom-JSON).Pokemon

        Foreach($_Pokemon in $Pokemon)
        {
            if(-not $ScanTable.ContainsKey($_Pokemon.id))
            {
                $_Pokemon | Add-Member NoteProperty 'url' "http://ugc.pokevision.com/images/pokemon/$($_Pokemon.id).png"
                $_Pokemon | Add-Member NoteProperty 'scan_time' ([datetime]::Now)
                $_Pokemon | Add-Member NoteProperty 'scan_latitude' $ScanningLat
                $_Pokemon | Add-Member NoteProperty 'scan_longitude' $ScanningLat
                $ScanTable.Add($_Pokemon.id, $_Pokemon)
                $Page.Add($_Pokemon) | Out-Null
            }
        }
    }
    $Page | ConvertTo-JSON -Depth ([int]::MaxValue) > "~\Desktop\Page$($i).json"
}
