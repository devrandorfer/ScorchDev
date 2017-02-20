Configuration Tanium
{
    #Import Modules
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module xWindowsUpdate
    Import-DscResource -Module cWindowscomputer
    Import-DscResource -Module cDisk
    Import-DscResource -Module xDisk

    $SourceDir = 'D:\Source'

    $TaniumVersion = '7.0.314.6319'
    $TaniumSetupExeURI = "https://content.tanium.com/files/install/$TaniumVersion/SetupServer.exe"
    $TaniumServerExe = 'SetupServer.exe'
    
    $InstallDir = 'F:\Program Files'

    $TaniumServerCommandLineArgs = 
        '/S /UseHTTPS=true ' +
        "/ApacheDir=`"$InstallDir\Apache Software Foundation`"" +
        "/CertPath=`"$InstallDir\Apache Software Foundation\Apache2.2\conf\installedcacert.crt`"" +
        "/KeyPath=`"$InstallDir\Tanium\Tanium Server\tanium.pub`"" +
        "/PHPDir=`"$InstallDir\PHP`""

    Node Server
    {
        File SourceFolder
        {
            DestinationPath = $($SourceDir)
            Type = 'Directory'
            Ensure = 'Present'
        }
        xWaitforDisk Disk2
        {
                DiskNumber = 2
                RetryIntervalSec =$RetryIntervalSec
                RetryCount = $RetryCount
        }
        cDiskNoRestart DataDisk
        {
            DiskNumber = 2
            DriveLetter = 'F'
            DependsOn = '[xWaitforDisk]Disk2'
        }
        xRemoteFile DownloadTaniumServerSetup
        {
            Uri = $TaniumSetupExeURI
            DestinationPath = "$($SourceDir)\$($TaniumServerExe)"
            MatchSource = $False
        }
        xPackage InstallTaniumServer
        {
             Name = 'TaniumServer'
             Path = "$($SourceDir)\$($TaniumServerExe)" 
             Arguments = $TaniumServerCommandLineArgs 
             Ensure = 'Present'
             DependsOn = @(
                '[xRemoteFile]DownloadTaniumServerSetup'
                '[cDiskNoRestart]DataDisk'
            )
             ProductId = ''
        }
        cAzureNetworkPerformanceMonitoring EnableAzureNPM
        {
            Name = 'EnableNPM'
            Ensure = 'Present'
        }
        xWindowsUpdateAgent MuSecurityImportant
        {
            IsSingleInstance = 'Yes'
            UpdateNow        = $true
            Category         = @('Security','Important')
            Source           = 'MicrosoftUpdate'
            Notifications    = 'Disabled'
        }
    }
}
