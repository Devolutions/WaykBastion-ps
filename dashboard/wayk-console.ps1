$Navigation = @(
    New-UDListItem -Label "Introduction" -OnClick { Invoke-UDRedirect '/introduction' }
    New-UDListItem -Label "Prerequisites" -OnClick { Invoke-UDRedirect '/prerequisites' }
    New-UDListItem -Label "Installation" -OnClick { Invoke-UDRedirect '/installation' }
    New-UDListItem -Label "Configuration" -OnClick { Invoke-UDRedirect '/configuration' }
)

$Pages = @()

$Pages += New-UDPage -Name 'Introduction' -Content {
    New-UDList -Content {
        New-UDTypography -Text "Welcome to the Wayk Bastion console!" -Variant h4
        New-UDTypography -Text "This installation and configuration helper should be used along with the "
        New-UDLink -Text "official documentation" -Url "https://docs.devolutions.net/wayk"
    }
} -NavigationLayout permanent -Navigation $Navigation

$Pages += New-UDPage -Name 'Prerequisites' -Content {

    function Get-DockerPrerequisite() {
        $DockerCommand = Get-Command -Name 'docker' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $DockerVersion = $(docker --version).Trim()

        $Prerequisite = [PSCustomObject]@{
            Name = "Docker Engine";
            VersionString = "N/A";
            InstallStatus = "❌";
        }

        if ($DockerCommand -And $DockerVersion) {
            $Prerequisite.VersionString = $DockerVersion
            $Prerequisite.InstallStatus = "✔️"
        }

        $Prerequisite
    }

    function Get-PwshPrerequisite() {
        $PwshCommand = Get-Command -Name 'pwsh' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $PwshVersion = $(pwsh --version).Trim()

        $Prerequisite = [PSCustomObject]@{
            Name = "PowerShell 7";
            VersionString = "N/A";
            InstallStatus = "❌";
        }

        if ($PwshCommand -And $PwshVersion) {
            $Prerequisite.VersionString = $PwshVersion
            $Prerequisite.InstallStatus = "✔️"
        }

        $Prerequisite
    }

    $Docker = Get-DockerPrerequisite
    $Pwsh = Get-PwshPrerequisite 

    $Data = @(
        @{ Name = $Docker.Name; VersionString = $Docker.VersionString; InstallStatus = $Docker.InstallStatus;
            DocsTitle = "Docker Installation";
            DocsUrl = "https://docs.devolutions.net/wayk/bastion/docker-installation.html" }
        @{ Name = $Pwsh.Name; VersionString = $Pwsh.VersionString; InstallStatus = $Pwsh.InstallStatus;
            DocsTitle = "PowerShell Installation";
            DocsUrl = "https://docs.devolutions.net/wayk/bastion/powershell-installation.html" }
    )

    $Columns = @(
        New-UDTableColumn -Property Name -Title Prerequisite
        New-UDTableColumn -Property VersionString -Title Version
        New-UDTableColumn -Property InstallStatus -Title Installed 
        New-UDTableColumn -Property Documentation -Title Documentation -Render {
            New-UDLink -Text $EventData.DocsTitle -Url $EventData.DocsUrl
        }
    )

    New-UDTable -Data $Data -Columns $Columns

} -NavigationLayout permanent -Navigation $Navigation

$Pages += New-UDPage -Name 'Installation' -Content {

    $Modules = Get-Module -Name "WaykBastion" -ListAvailable

    if ($Modules) {
        $Modules[0] | Add-Member -Type NoteProperty -Name "DefaultModule" -Value $true
    }

    $Columns = @(
        New-UDTableColumn -Property Name -Title "Name"
        New-UDTableColumn -Property VersionString -Title "Version" -Render {
            $EventData.Version.ToString()
        }
        New-UDTableColumn -Property ModuleBase -Title "Path" -Render {
            $EventData.ModuleBase.ToString()
        }
        New-UDTableColumn -Property DefaultModule -Title "Default" -Render {
            if ($EventData.DefaultModule) { "✓" } else { "" }
        }
    )

    New-UDTable -Data $Modules -Columns $Columns

    $DocsTitle = "PowerShell Module Installation"
    $DocsUrl = "https://docs.devolutions.net/wayk/bastion/index.html#powershell-module"
    New-UDLink -Text $DocsTitle -Url $DocsUrl

} -NavigationLayout permanent -Navigation $Navigation

function New-UDWaykConfigWizard
{
    param(
        [Parameter()]
        [string]$ComputerName,
        [Parameter()]
        [PSCredential]$Credential,
        [Parameter()]
        [string]$IsoPath
    )

    $ConnectionInfo = @{}

    if ($ComputerName)
    {
        $ConnectionInfo["ComputerName"] = $ComputerName 
    }

    if ($Credential)
    {
        $ConnectionInfo["Credential"] = $Credential 
    }

    New-UDStepper -Steps {

        New-UDStep -OnLoad {

            $ConfigPath = Get-WaykBastionPath "ConfigPath"
            $EventData.Context.ConfigPath = $ConfigPath

            New-UDRow {
                New-UDTypography -Text "Choose a configuration directory for Wayk Bastion"
            }

            New-UDRow {
                New-UDTextbox -Id 'ConfigPath' -Value $EventData.Context.ConfigPath -Label "Configuration directory"
            }

            New-UDRow {
                New-UDTypography "Leave empty for default path: `"$ConfigPath`""
            }

        } -Label "Configuration directory"
        New-UDStep -OnLoad {
            New-UDTypography -Text "Choose a name for the Wayk Bastion realm."
            New-UDTypography -Text "This should normally be the same as your company domain name."
            New-UDTypography -Text "For instance: it-help.ninja for a company called `"IT Help Ninja`""

            New-UDRow {
                New-UDTextbox -Id 'Realm' -Value $EventData.Context.Realm -Label "bastion.local"
            }

        } -Label "Realm Name"
        New-UDStep -OnLoad {
            New-UDTypography -Text "Specify a listener url:"

            New-UDRow {
                New-UDTextbox -Id 'ListenerUrl' -Value $EventData.Context.ListenerUrl -Label "http://localhost:4000"
            }

        } -Label "Listener URL"
        New-UDStep -OnLoad {
            New-UDTypography -Text "Specify an external url:"

            New-UDRow {
                New-UDTextbox -Id 'ExternalUrl' -Value $EventData.Context.ExternalUrl -Label "http://localhost:4000"
            }

        } -Label "External URL"
        New-UDStep -OnLoad {
            $ConfigPath = $EventData.Context.ConfigPath
            $Realm = $EventData.Context.Realm
            $ListenerUrl = $EventData.Context.ListenerUrl
            $ExternalUrl = $EventData.Context.ExternalUrl

            $Data = @(
                @{ ParameterName = "ConfigPath"; ParameterValue = $ConfigPath }
                @{ ParameterName = "Realm"; ParameterValue = $Realm }
                @{ ParameterName = "ListenerUrl"; ParameterValue = $ListenerUrl }
                @{ ParameterName = "ExternalUrl"; ParameterValue = $ExternalUrl }
            ) 

            $Columns = @(
                New-UDTableColumn -Property ParameterName -Title "Parameter Name"
                New-UDTableColumn -Property ParameterValue -Title "Parameter Value" 
            )

            New-UDTable -Data $Data -Columns $Columns

        } -Label "Summary"
    } -OnFinish {

        try
        {
            $ConfigPath = $EventData.Context.ConfigPath
            $Realm = $EventData.Context.Realm
            $ListenerUrl = $EventData.Context.ListenerUrl
            $ExternalUrl = $EventData.Context.ExternalUrl

            $params = @{
                ConfigPath = $ConfigPath;
                Realm = $Realm;
                ListenerUrl = $ListenerUrl;
                ExternalUrl = $ExternalUrl;
            }

            New-WaykBastionConfig @params

            Show-UDToast -Message "Successfully created Wayk Bastion configuration" -Duration 5000
        }
        catch 
        {
            Show-UDToast -Message "Failed to create Wayk Bastion configuration" -Duration 5000
        }
    } -Orientation vertical
}

$Pages += New-UDPage -Name 'Configuration' -Content {

    New-UDWaykConfigWizard

} -NavigationLayout permanent -Navigation $Navigation

New-UDDashboard -Title "Wayk Bastion Console" -Pages $Pages
