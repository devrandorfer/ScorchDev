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

    $SqlServer2012CLIURI = 'http://go.microsoft.com/fwlink/?LinkID=239648&clcid=0x409'
    $SqlServer2012CLI = 'sqlncli.msi'

    $SqlServer2012CmdUtilsURI = 'http://go.microsoft.com/fwlink/?LinkID=239650&clcid=0x409'
    $SqlServer2012CmdUtils = 'SQLCmdLnUtils.msi'
    
    $SqlExprWTURI = 'https://download.microsoft.com/download/8/D/D/8DD7BDBA-CEF7-4D8E-8C16-D9F69527F909/ENU/x64/SQLEXPRWT_x64_ENU.exe'
    $SqlExprWT = 'SQLEXPRWT_x64_ENU.exe'

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

    $RetryCount = 20
    $RetryIntervalSec = 30

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
        xRemoteFile DownloadSqlServer2012CLI
        {
            Uri = $SqlServer2012CLIURI
            DestinationPath = "$($SourceDir)\$($SqlServer2012CLI)"
            MatchSource = $False
        }
        xPackage InstallSqlServer2012CLI
        {
            Name = 'Microsoft SQL Server 2012 Native Client'
            Path = "$($SourceDir)\$($SqlServer2012CLI)" 
            Arguments = '/qn'
            Ensure = 'Present'
            DependsOn = @(
                '[xRemoteFile]DownloadSqlServer2012CLI'
                '[cDiskNoRestart]DataDisk'
            )
            ProductId = '49D665A2-4C2A-476E-9AB8-FCC425F526FC'
        }
        xRemoteFile DownloadSqlServer2012CmdUtilsURI
        {
            Uri = $SqlServer2012CmdUtilsURI
            DestinationPath = "$($SourceDir)\$($SqlServer2012CmdUtils)"
            MatchSource = $False
        }
        xPackage InstallSqlServer2012CmdUtils
        {
            Name = 'Microsoft SQL Server 2012 Command Line Utilities'
            Path = "$($SourceDir)\$($SqlServer2012CmdUtils)" 
            Arguments = '/qn'
            Ensure = 'Present'
            DependsOn = @(
                '[xRemoteFile]DownloadSqlServer2012CmdUtilsURI'
                '[cDiskNoRestart]DataDisk'
            )
            ProductId = '9D573E71-1077-4C7E-B4DB-4E22A5D2B48B'
        }
        xRemoteFile DownloadSqlExprWT
        {
            Uri = $SqlExprWTURI
            DestinationPath = "$($SourceDir)\$($SqlExprWT)"
            MatchSource = $False
        }
        xPackage InstallSqlExprWT
        {
            Name = 'SqlExprWT'
            Path = "$($SourceDir)\$($SqlExprWT)" 
            Arguments = '/S'
            Ensure = 'Present'
            DependsOn = @(
                '[xRemoteFile]DownloadSqlExprWT'
                '[cDiskNoRestart]DataDisk'
            )
            ProductId = ''
        }
        xRemoteFile DownloadTaniumServerSetup
        {
            Uri = $TaniumSetupExeURI
            DestinationPath = "$($SourceDir)\$($TaniumServerExe)"
            MatchSource = $False
        }
        <#
        xPackage InstallTaniumServer
        {
            Name = 'TaniumServer'
            Path = "$($SourceDir)\$($TaniumServerExe)" 
            Arguments = $TaniumServerCommandLineArgs 
            Ensure = 'Present'
            DependsOn = @(
                '[xRemoteFile]DownloadTaniumServerSetup'
                '[xPackage]InstallSqlServer2012CLI',
                '[xPackage]InstallSqlServer2012CmdUtils',
                '[xPackage]InstallSqlExprWT',
                '[cDiskNoRestart]DataDisk'
            )
            ProductId = ''
        }#>
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
