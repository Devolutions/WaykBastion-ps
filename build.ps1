
$module = 'WaykBastion'
Push-Location $PSScriptRoot

Remove-Item -Path .\package -Recurse -Force -ErrorAction SilentlyContinue

New-Item -Path "$PSScriptRoot\package\$module" -ItemType 'Directory' -Force | Out-Null
@('bin', 'Public', 'Private') | foreach {
    New-Item -Path "$PSScriptRoot\package\$module\$_" -ItemType 'Directory' -Force | Out-Null
}

& dotnet nuget add source "https://api.nuget.org/v3/index.json" -n "nuget.org" | Out-Null

& dotnet publish "$PSScriptRoot\$module\src" -f netstandard2.0 -c Release -o "$PSScriptRoot\$module\bin"

Expand-Archive -Path .\resources\cmdlet-service.zip -DestinationPath "$PSScriptRoot\$module\bin" -Force
Copy-Item "$PSScriptRoot\$module\bin" -Destination "$PSScriptRoot\package\$module" -Recurse -Force

Copy-Item "$PSScriptRoot\$module\Private" -Destination "$PSScriptRoot\package\$module" -Recurse -Force
Copy-Item "$PSScriptRoot\$module\Public" -Destination "$PSScriptRoot\package\$module" -Recurse -Force

Copy-Item "$PSScriptRoot\$module\$module.psd1" -Destination "$PSScriptRoot\package\$module" -Force
Copy-Item "$PSScriptRoot\$module\$module.psm1" -Destination "$PSScriptRoot\package\$module" -Force
