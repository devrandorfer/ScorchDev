
$moduleName = 'Patchy'            
$ModuleRoot = "$home\Documents\WindowsPowerShell\Modules\$moduleName"            
            
$formatting = @()            
$formatting += Write-FormatView -TypeName "System.__ComObject#{c1c2f21a-d2f4-4902-b5c6-8a081c19a890}",
"System.__ComObject#{70cf5c82-8642-42bb-9dbc-0cfd263c6c4f}" -Action {            
    if ($_.IsMandatory) {    
        Write-Host $_.Title -ForegroundColor Red
    } elseif ($_.AutoSelectOnWebSites) {
        Write-Host $_.Title -ForegroundColor DarkYellow
    } else {
        Write-Host $_.Title -ForegroundColor Green
    }
    ""
}            

$formatting += Write-FormatView -TypeName "System.__ComObject#{c2bfb780-4539-4132-ab8c-0a8772013ab6}" -Action {            
    Write-Host "$($_.Date) $($_.Title)" 
    ""
}


            
            
$formatting |            
    Out-FormatData |            
    Set-Content "$moduleRoot\$ModuleName.Format.ps1xml"  


