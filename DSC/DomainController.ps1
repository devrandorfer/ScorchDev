configuration DomainController 
{ 
    Import-DscResource -ModuleName xActiveDirectory, 
                                   xDisk,
                                   xNetworking,
                                   xPendingReboot,
                                   cDisk
    
    $GlobalVars = Get-BatchAutomationVariable -Prefix 'Global' `
                                              -Name 'DomainCredentialName',
                                                    'DomainName'

    $DomainCredentail = Get-AutomationPSCredential -Name $GlobalVars.DomainCredentialName
    $RetryCount = 20
    $RetryIntervalSec = 30

    Node PDC
    {
        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
        }

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]DNS"
        }

        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        cDiskNoRestart ADDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
        }  

        xADDomain FirstDS 
        {
            DomainName = $GlobalVars.DomainName
            DomainAdministratorCredential = $DomainCredentail
            SafemodeAdministratorPassword = $DomainCredentail
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
            DependsOn = "[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress","[cDiskNoRestart]ADDataDisk"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainCredentail
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = "[xADDomain]FirstDS"
        } 

        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }
    }
    Node BDC
    {
        xWaitforDisk Disk2
        {
                DiskNumber = 2
                RetryIntervalSec =$RetryIntervalSec
                RetryCount = $RetryCount
        }
        cDiskNoRestart ADDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }
        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
        }
        WindowsFeature ADDSTools
        {
            Ensure = "Present" 
            Name = "RSAT-ADDS"
        }
        xWaitForADDomain DscForestWait 
        { 
            DomainName = $GlobalVars.DomainName
            DomainUserCredential = $DomainCredentail
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec
        } 
        xADDomainController BDC 
        { 
            DomainName = $GlobalVars.DomainName
            DomainAdministratorCredential = $DomainCredentail
            SafemodeAdministratorPassword = $DomainCredentail
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
        }

        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xADDomainController]BDC"
        }
    }
} 