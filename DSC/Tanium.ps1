Configuration Tanium
{
    #Import Modules
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module xWindowsUpdate
    Import-DscResource -Module cWindowscomputer
    Import-DscResource -Module cDisk
    Import-DscResource -Module xDisk
    Import-DscResource -Module xNetworking

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

    $SysmonZipUri = 'https://download.sysinternals.com/files/Sysmon.zip'
    $SysmonZip = 'Sysmon.zip'
    $SysmonExe = 'Sysmon64.exe'
    $SysmonConfigUri = 'https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml'
    $SysmonConfigXML = 'sysmonconfig-export.xml'
    $SysmonArgs = "-accepteula -i $($SourceDir)\$($SysmonConfigXML)"

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
            Name = 'Microsoft SQL Server 2012 Native Client '
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
            Name = 'Microsoft SQL Server 2012 Command Line Utilities '
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
            Name = 'Microsoft SQL Server 2012 Express LocalDB '
            Path = "$($SourceDir)\$($SqlExprWT)" 
            Arguments = '/q /Action=Install /Hideconsole /Features=SQL,Tools/InstanceName=SQLExpress /SQLSYSADMINACCOUNTS="Builtin\Administrators"'
            Ensure = 'Present'
            DependsOn = @(
                '[xRemoteFile]DownloadSqlExprWT'
                '[cDiskNoRestart]DataDisk'
            )
            ProductId = '13D558FE-A863-402C-B115-160007277033'
        }
        xRemoteFile DownloadTaniumServerSetup
        {
            Uri = $TaniumSetupExeURI
            DestinationPath = "$($SourceDir)\$($TaniumServerExe)"
            MatchSource = $False
        }
        xPackage InstallTaniumServer
        {
            Name = "Tanium Server $TaniumVersion"
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
            InstalledCheckRegKey = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Tanium Server'
            InstalledCheckRegValueName = 'DisplayVersion'
            InstalledCheckRegValueData = $TaniumVersion
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
        xFirewall TaniumRecieverInbound
        {
            Name                  = "TaniumRecieverInboundRules"
            DisplayName           = "Firewall Rule for TaniumReciever.exe"
            Group                 = "Tanium Firewall Group"
            Ensure                = "Present"
            Enabled               = "True"
            Direction             = "Inbound"
            LocalPort             = ("443", "17472")
            Protocol              = "TCP"
            Description           = "Firewall Rule for TaniumReciever.exe"
            Program               = "$InstallDir\Tanium\Tanium Server\TaniumReceiver.exe"
        }
        xFirewall TaniumModuleServerInbound
        {
            Name                  = "TaniumModuleServerInboundRules"
            DisplayName           = "Firewall Rule for TaniumModuleServer.exe"
            Group                 = "Tanium Firewall Group"
            Ensure                = "Present"
            Enabled               = "True"
            Direction             = "Inbound"
            LocalPort             = ("17477")
            Protocol              = "TCP"
            Description           = "Firewall Rule for TaniumModuleServer.exe"
            Program               = "$InstallDir\Tanium\Tanium Module Server\TaniumModuleServer.exe"
        }
        xRemoteFile SysmonZip
        {
            Uri = $SysmonZipUri
            DestinationPath = "$($SourceDir)\$($SysmonZip)"
            MatchSource = $False
        }
        
        # Unpack Sysmon
        Archive UnpackSysmon
        {
            Path = "$($SourceDir)\$($SysmonZip)"
            Destination = $SourceDir
            Ensure = 'Present'
            DependsOn = '[xRemoteFile]SysmonZip'
        }

        xRemoteFile SysmonConfig
        {
            Uri = $SysmonConfigUri
            DestinationPath = "$($SourceDir)\$($SysmonConfigXML)"
            MatchSource = $False
        }

        xPackage InstallSysmon
        {
             Name = "Sysmon"
             Path = "$($SourceDir)\$($SysmonExe)" 
             Arguments = $SysmonArgs
             Ensure = 'Present'
             InstalledCheckRegKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Sysmon/Operational'
             ProductID = ''
             DependsOn = @(
                '[Archive]UnpackSysmon'
                '[xRemoteFile]SysmonConfig'
             )
        }
    }
}
