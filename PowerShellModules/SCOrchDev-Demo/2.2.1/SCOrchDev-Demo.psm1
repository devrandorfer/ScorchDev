Function Invoke-Step1
{
    WRite-Verbose -Message 'Step 1'
}
Function Invoke-Step2
{
    WRite-Verbose -Message 'Step 2'
}
Function Invoke-Step3
{
    WRite-Verbose -Message 'Step 3'
}
Export-ModuleMember -Function * -Alias * -Verbose:$False