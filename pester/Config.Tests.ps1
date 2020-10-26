Import-Module "$PSScriptRoot/../WaykBastion"

Describe 'Wayk Bastion config' {
	InModuleScope WaykBastion {
		Context 'Fresh environment' {
			It 'Creates new configuration with realm and external url' {
                $ConfigPath = $TestDrive
                New-WaykBastionConfig -ConfigPath:$ConfigPath `
                    -Realm 'buzzword.marketing' -ExternalUrl 'https://den.buzzword.marketing'
                $(Get-WaykBastionConfig -ConfigPath:$ConfigPath).Realm | Should -Be 'buzzword.marketing'
                $(Get-WaykBastionConfig -ConfigPath:$ConfigPath).ExternalUrl | Should -Be 'https://den.buzzword.marketing'
			}
            It 'Sets and clears MongoDB configuration' {
                $ConfigPath = $TestDrive
                Set-WaykBastionConfig -ConfigPath:$ConfigPath `
                    -MongoExternal $true -MongoUrl 'mongodb://mongo-server:27017'
                $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath
                $config.MongoExternal | Should -Be $true
                $config.MongoUrl | Should -Be 'mongodb://mongo-server:27017'
                Clear-WaykBastionConfig -ConfigPath:$ConfigPath 'Mongo*'
                $config = Get-WaykBastionConfig -ConfigPath:$ConfigPath
                $config.MongoExternal | Should -Be $false
                $config.MongoUrl | Should -BeNullOrEmpty
			}
		}
	}
}
