
$ModuleName = $(Get-Item $PSCommandPath).BaseName
$Manifest = Import-PowerShellDataFile -Path $(Join-Path $PSScriptRoot "${ModuleName}.psd1")

Export-ModuleMember -Cmdlet @($Manifest.CmdletsToExport)

$Public = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -Recurse)
$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -Recurse)

Foreach ($Import in @($Public + $Private))
{
    Try
    {
        . $Import.FullName
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($Import.FullName): $_"
    }
}

Export-ModuleMember -Function @($Manifest.FunctionsToExport)

$LegacyFunctionNames = @($Manifest.AliasesToExport) | Where-Object { $_ -Match 'WaykDen' }

Foreach ($FunctionName in $LegacyFunctionNames) {
    $OldFunctionName = $FunctionName
    $NewFunctionName = $FunctionName -Replace 'WaykDen', 'WaykBastion'
    New-Alias -Name $OldFunctionName -Value $NewFunctionName
}

Export-ModuleMember -Alias $LegacyFunctionNames
