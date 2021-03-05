
function Get-DockerVersion() {
    $(docker version --format '{{.Server.Version}}').trim()
}

function Get-IsWindows
{
    if (-Not (Test-Path 'variable:global:IsWindows')) {
        return $true # Windows PowerShell 5.1 or earlier
    } else {
        return $IsWindows
    }
}

function Get-OsVersionInfo() {
    if (Get-IsWindows) {
        $ProductName = (Get-ItemProperty -path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
        $ReleaseId = (Get-ItemProperty -path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
        return "$ProductName $ReleaseId"
	} elseif ($IsMacOS) {
        $ProductVersion = $(sw_vers -productVersion).trim()
        $BuildVersion = $(sw_vers -buildVersion).trim()
        return "macOS $ProductVersion $BuildVersion"
	} elseif ($IsLinux) {
        $LsbRelease = $(lsb_release -d -s).trim()
        return "Linux $LsbRelease"
    }
}

$Pages = @()

$Pages += New-UDPage -Name 'Prerequisites' -Content {
    New-UDTypography -Text "$ModuleName PowerShell Module" -Variant h3

    New-UDColumn -LargeSize 6 -Content {
        New-UDLink -Text "PowerShell installation instructions" `
            -Url "https://docs.devolutions.net/wayk/bastion/powershell-installation.html"
    }

    New-UDRow -Columns {
        $ModuleName = "WaykBastion"
        $Module = Get-Module -Name $ModuleName -ListAvailable | Select-Object -First 1
        $ModuleEnabled = [bool] $Module
        $ModuleVersion = ""
        
        if ($Module) {
            $ModuleVersion = $Module.Version
        }

        New-UDColumn -LargeSize 6 -Content {
            New-UDCheckBox -Checked $ModuleEnabled -Disabled
            New-UDTypography -Text "$ModuleName PowerShell Module"
        }
        New-UDColumn -LargeSize 6 -Content {
            New-UDTextbox -Id 'ModuleVersion' -Label 'Module Version' -Value $ModuleVersion
        }
        New-UDButton -Variant 'contained' -Text 'Install PowerShell Module' -Disabled -OnClick {
            Show-UDToast 'Installing PowerShell Module...'
            Install-Module -Name $ModuleName -Scope AllUsers -Force
        }
    }

    New-UDTypography -Text "Docker" -Variant h3

    New-UDRow -Columns {
        $DockerVersion = Get-DockerVersion

        New-UDColumn -LargeSize 6 -Content {
            New-UDLink -Text "Docker installation instructions" `
                -Url "https://docs.devolutions.net/wayk/bastion/docker-installation.html"
        }

        New-UDColumn -LargeSize 6 -Content {
            New-UDTextbox -Id 'DockerVersion' -Label 'Docker Version' -Value $DockerVersion
        }
    }

    New-UDRow -Columns {
        $OsVersionInfo = Get-OsVersionInfo
        New-UDColumn -LargeSize 6 -Content {
            New-UDTextbox -Id 'OsVersion' -Label 'Operating System' -Value $OsVersionInfo
        }
    }
}

$Pages += New-UDPage -Name 'Management' -Content {
    New-UDRow -Columns {
        New-UDColumn -LargeSize 6 -Content {
            New-UDButton -Variant 'contained' -Text 'Start Wayk Bastion' -OnClick {
                Show-UDToast 'Starting Wayk Bastion'
            }
        
            New-UDButton -Variant 'contained' -Text 'Stop Wayk Bastion' -OnClick {
                Show-UDToast 'Stopping Wayk Bastion'
            }
        }
    }
}

New-UDDashboard -Pages $Pages -Title 'Dashboard'
