Configuration Demo
{
    Param(
    )

    Import-DscResource -ModuleName cDemo

    Node HybridRunbookWorker
    {
       cDemoResource Demo
       {
            Repository = 'https://github.com/randorfer/ScorchDev'
            BaseDirectory = 'c:\git'
            Ensure = 'Present'
       }
    }
}
