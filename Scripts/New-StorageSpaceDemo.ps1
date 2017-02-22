#Setup Servers
$NodePrefix = 'sco-storage2'
$Node = @(1..2) | % { "$NodePrefix-$_" }

icm $node {Install-WindowsFeature Failover-Clustering -IncludeAllSubFeature -IncludeManagementTools}

# Create Cluster
New-Cluster -Name $NodePrefix -Node $Node

# Enable Spaces Direct
Enable-ClusterStorageSpacesDirect

1..5 | Foreach {
    New-Volume -Size 50GB -FriendlyName "Volume $_" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName S2D*
}

icm $node {Install-WindowsFeature FS-FileServer}
Add-ClusterScaleOutFileServerRole -Name "$NodePrefix-fileserver"

New-Item -Path C:\ClusterStorage\Volume1\Data -ItemType Directory
New-SmbShare -Name Share1 -Path C:\ClusterStorage\Volume1\Data -FullAccess scorchdev\randorfer

# Scale-Out
Add-ClusterNode -Name "$NodePrefix-3" -Cluster .

# Scale-In
Remove-ClusterNode -Name "$NodePrefix-3" -CleanUpDisks

# List Cluster Nodes
Get-ClusterNode

# List Unpooled Drives
Get-PhysicalDisk -CanPool $True | Sort Model

# List Pooled Drives
Get-StoragePool S* | Get-PhysicalDisk | Sort Model

#### QoS ####
Get-ClusterResource -Name "Storage Qos Resource"  

Get-StorageQosVolume | Format-List

$100to200IopsPolicy = New-StorageQosPolicy -Name 100to200Iops -PolicyType Dedicated -MinimumIops 100 -MaximumIops 200
