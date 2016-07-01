Configuration DomainComputer
{
    # Import the required modules
    Import-DscResource -Module xPSDesiredStateConfiguration
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module cWindowscomputer
    Import-DscResource -Module cAzureAutomation
    Import-DscResource -Module xPendingReboot
    Import-DscResource -Module xDSCDomainjoin -ModuleVersion 1.1

    $SourceDir = 'd:\Source'
    $GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                              -Name @(
        'DomainJoinCredentialName',
        'DefaultDomainName'
    )

    $DomainJoinCredential = Get-AutomationPSCredential -Name $GlobalVars.DomainJoinCredentialName

    $MMARemotSetupExeURI = 'https://go.microsoft.com/fwlink/?LinkID=517476'
    $MMASetupExe = 'MMASetup-AMD64.exe'

    Node MemberServerDev
    {
        File SourceFolder
        {
            DestinationPath = $($SourceDir)
            Type = 'Directory'
            Ensure = 'Present'
        }
        xRemoteFile DownloadMicrosoftManagementAgent
        {
            Uri = $MMARemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($MMASetupExe)"
            MatchSource = $False
        }
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DefaultDomainName
            Credential = $DomainJoinCredential
        }
    }
    Node MemberServerQA
    {
        File SourceFolder
        {
            DestinationPath = $($SourceDir)
            Type = 'Directory'
            Ensure = 'Present'
        }
        xRemoteFile DownloadMicrosoftManagementAgent
        {
            Uri = $MMARemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($MMASetupExe)"
            MatchSource = $False
        }
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DefaultDomainName
            Credential = $DomainJoinCredential
        }
    }
    Node MemberServerProd
    {
        File SourceFolder
        {
            DestinationPath = $($SourceDir)
            Type = 'Directory'
            Ensure = 'Present'
        }
        xRemoteFile DownloadMicrosoftManagementAgent
        {
            Uri = $MMARemotSetupExeURI
            DestinationPath = "$($SourceDir)\$($MMASetupExe)"
            MatchSource = $False
        }
        xDSCDomainjoin JoinDomain
        {
            Domain = $GlobalVars.DefaultDomainName
            Credential = $DomainJoinCredential
        }
    }
}
