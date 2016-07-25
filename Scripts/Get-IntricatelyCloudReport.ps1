$Token = '37f5bf608500904513513f1eaeea26ec'

<#
    Idea for increasing datadump / populating company list
    
    $CompanyMegaList = Invoke-WebRequest -Uri "https://my.intricately.com/es?q=a&v=0"
#>


$CompanyList = @(
   '3M'
   'the mosaic company'
   'EcoLab'
   'Fastenal'
   'CliftonLarsonAllen'
   'General Mills'
   'U S Bank'
   'Ameriprise Financial Services inc'
   'vista outdoor inc'
   'Ceridian'
   'C H Robinson'
   'SuperValu'
   'Best Buy'
   'Target'
   'Cargill  2'
   'Thomson Reuters  2'
)

$SavePath = "~\Desktop\intricatelyReport.csv"
if(Test-Path -Path $SavePath) { Remove-Item -Path $SavePath -Force }

$Reports = @()
Foreach($CompanyName in $CompanyList)
{
    $Request = Invoke-WebRequest -Uri "https://api.intricately.com/api/v1/companies/$($CompanyName.Replace(' ','-').Replace('.','-').ToLower())?token=$($Token)"
    $Result = ($Request.Content | ConvertFrom-JSON).Company
    $Reports += $Result
    Foreach($Service in $Result.services)
    {
        Foreach($_Service in $Service)
        {
            Foreach($Vendor in $_Service.Vendors)
            {
                if($Vendor.hostnames)
                {
                    $ExportObject = [pscustomobject] @{
                        CompanyName = $CompanyName
                        ServiceName = $_Service.Name
                        VendorName = $Vendor.Name
                        Spend = $Vendor.spend
                        HostNames = $Vendor.HostNames.name -join ';'
                    }

                }
                else
                {
                    $ExportObject = [pscustomobject]@{
                        CompanyName = $CompanyName
                        ServiceName = $_Service.Name
                        VendorName = $Vendor.Name
                        Spend = $Vendor.spend
                        HostNames = [string]::Empty
                    }
                }
                $ExportObject | Select-Object -Property CompanyName,ServiceName,VendorName,Spend,HostNames | Export-Csv -Path $SavePath -Append
            }
        }
    }
}
$Reports | % { $_ | ConvertTo-Json -Depth ([int]::MaxValue) | Add-Content -Path "~\Desktop\$($_.id).json" }