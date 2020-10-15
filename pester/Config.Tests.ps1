Import-Module "$PSScriptRoot/../WaykBastion"

Describe 'Wayk Bastion config' {
	InModuleScope WaykBastion {
		Context 'Fresh environment' {
			It 'Creates new configuration with realm and external url' {
                New-WaykBastionConfig -ConfigPath $TestDrive `
                    -Realm 'buzzword.marketing' -ExternalUrl 'https://den.buzzword.marketing'
                $(Get-WaykBastionConfig -ConfigPath $TestDrive).Realm | Should -Be 'buzzword.marketing'
                $(Get-WaykBastionConfig -ConfigPath $TestDrive).ExternalUrl | Should -Be 'https://den.buzzword.marketing'
			}
            It 'Sets and clears MongoDB configuration' {
                Set-WaykBastionConfig -ConfigPath $TestDrive `
                    -MongoExternal $true -MongoUrl 'mongodb://mongo-server:27017'
                $config = Get-WaykBastionConfig -ConfigPath $TestDrive
                $config.MongoExternal | Should -Be $true
                $config.MongoUrl | Should -Be 'mongodb://mongo-server:27017'
                Clear-WaykBastionConfig -ConfigPath $TestDrive 'Mongo*'
                $config = Get-WaykBastionConfig -ConfigPath $TestDrive
                $config.MongoExternal | Should -Be $false
                $config.MongoUrl | Should -BeNullOrEmpty
			}
		}
	}
}
