Configuration Demo
{
    Param(
    )

    
    Node HybridRunbookWorker
    {
        File SourceFolder
        {
            DestinationPath = 'c:\git'
            Type = 'Directory'
            Ensure = 'Present'
        }
    }
}
