Configuration Demo
{
    Import-DscResource -module xNetworking

    $Cred = Get-AutomationPSCredential -name 'mycred'
    Node Dev
    {
        xHostsFile DomainController
        {
          HostName  = 'dc01'
          IPAddress = '192.168.0.1'
          Ensure    = 'Present'
        }
        xHostsFile DomainController2
        {
          HostName  = 'dc02'
          IPAddress = '192.168.0.2'
          Ensure    = 'Present'
        }
        xHostsFile DomainController3
        {
          HostName  = 'dc03'
          IPAddress = '192.168.0.3'
          Ensure    = 'Present'
        }

    }

    Node QA
    {
        xHostsFile DomainController
        {
          HostName  = 'dc01'
          IPAddress = '192.168.1.1'
          Ensure    = 'Present'
        }
        xHostsFile DomainController2
        {
          HostName  = 'dc02'
          IPAddress = '192.168.1.2'
          Ensure    = 'Present'
        }
        xHostsFile DomainController3
        {
          HostName  = 'dc03'
          IPAddress = '192.168.1.3'
          Ensure    = 'Present'
        }
    }

    Node Prod
    {
        xHostsFile DomainController
        {
          HostName  = 'dc01'
          IPAddress = '192.168.2.1'
          Ensure    = 'Present'
        }
        xHostsFile DomainController2
        {
          HostName  = 'dc02'
          IPAddress = '192.168.2.2'
          Ensure    = 'Present'
        }
        xHostsFile DomainController3
        {
          HostName  = 'dc03'
          IPAddress = '192.168.2.3'
          Ensure    = 'Present'
        }
    }
}
