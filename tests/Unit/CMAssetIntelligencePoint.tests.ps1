param ()

# Begin Testing
BeforeAll {
    # Import Stub function
    Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Stubs\ConfigMgrCBDscStub.psm1') -Force -WarningAction 'SilentlyContinue'

    # Import DscResource.Test Module
    try
    {
        Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
    }

    # Variables used for each Initialize-TestEnvironment
    $initalize = @{
        DSCModuleName   = 'ConfigMgrCBDsc'
        DSCResourceName = 'DSC_CMAssetIntelligencePoint'
        ResourceType    = 'Mof'
        TestType        = 'Unit'
    }
}

Describe 'ConfigMgrCBDsc - DSC_CMAssetIntelligencePoint\Get-TargetResource' -Tag 'Get' {
    BeforeAll {
        $testEnvironment = Initialize-TestEnvironment @initalize

        Mock -CommandName Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName Set-Location -ModuleName DSC_CMAssetIntelligencePoint

        $getInput = @{
            SiteCode         = 'Lab'
            IsSingleInstance = 'Yes'
        }

        $getAPReturnNoCert = @{
            SiteCode                      = 'Lab'
            ProxyName                     = 'CA01.contoso.com'
            ProxyCertPath                 = $null
            ProxyEnabled                  = $true
            PeriodicCatalogUpdateEnabled  = $true
            PeriodicCatalogUpdateSchedule = '0001200000100038'
            IsSingleInstance              = 'Yes'
        }

        $networkOSPath = @{
            NetworkOSPath = '\\CA01.Contoso.com'
        }

        $mockCimSchedule = (New-CimInstance -ClassName DSC_CMAssetIntelligenceSynchronizationSchedule `
            -Namespace root/microsoft/Windows/DesiredStateConfiguration `
            -Property @{
                'RecurInterval' = 'Days'
                'RecurCount'    = 7
            } -ClientOnly
        )

        $getAPReturnWithCert = @{
            SiteCode                      = 'Lab'
            ProxyName                     = 'CA01.contoso.com'
            ProxyCertPath                 = '\\CA01.Contoso.com\c$\cert.pfx'
            ProxyEnabled                  = $true
            PeriodicCatalogUpdateEnabled  = $true
            PeriodicCatalogUpdateSchedule = '0001200000100038'
            IsSingleInstance              = 'Yes'
        }
    }
    AfterAll {
        Restore-TestEnvironment -TestEnvironment $testEnvironment
    }

    Context 'When retrieving asset intelligence point settings' {
        It 'Should return desired result when asset intelligence point is not currently installed' {
            Mock -CommandName Get-CMAssetIntelligenceProxy -ModuleName DSC_CMAssetIntelligencePoint

            $result = Get-TargetResource @getInput
            $result                       | Should -BeOfType System.Collections.HashTable
            $result.SiteCode              | Should -Be -ExpectedValue 'Lab'
            $result.SiteServerName        | Should -BeNullOrEmpty
            $result.CertificateFile       | Should -BeNullOrEmpty
            $result.Enable                | Should -BeNullOrEmpty
            $result.EnableSynchronization | Should -BeNullOrEmpty
            $result.Schedule              | Should -BeNullOrEmpty
            $result.Ensure                | Should -Be -ExpectedValue 'Absent'
        }

        It 'Should return desired result when asset intelligence point is currently installed with no certificate file' {
            Mock -CommandName Get-CMAssetIntelligenceProxy -MockWith { $getAPReturnNoCert } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Get-CMAssetIntelligenceSynchronizationPoint -MockWith { $networkOSPath } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName ConvertTo-CimCMScheduleString -MockWith { $mockCimSchedule } -ModuleName DSC_CMAssetIntelligencePoint

            $result = Get-TargetResource @getInput
            $result                       | Should -BeOfType System.Collections.HashTable
            $result.SiteCode              | Should -Be -ExpectedValue 'Lab'
            $result.SiteServerName        | Should -Be -ExpectedValue 'CA01.contoso.com'
            $result.CertificateFile       | Should -BeNullOrEmpty
            $result.Enable                | Should -BeTrue
            $result.EnableSynchronization | Should -BeTrue
            $result.Schedule              | Should -Match $mockCimSchedule
            $result.Schedule              | Should -BeOfType '[Microsoft.Management.Infrastructure.CimInstance]'
            $result.Ensure                | Should -Be -ExpectedValue 'Present'
        }

        It 'Should return desired result when asset intelligence point is currently installed with a certificate file' {
            Mock -CommandName Get-CMAssetIntelligenceProxy -MockWith { $getAPReturnWithCert } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Get-CMAssetIntelligenceSynchronizationPoint -MockWith { $networkOSPath } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName ConvertTo-CimCMScheduleString -MockWith { $mockCimSchedule } -ModuleName DSC_CMAssetIntelligencePoint

            $result = Get-TargetResource @getInput
            $result                       | Should -BeOfType System.Collections.HashTable
            $result.SiteCode              | Should -Be -ExpectedValue 'Lab'
            $result.SiteServerName        | Should -Be -ExpectedValue 'CA01.contoso.com'
            $result.CertificateFile       | Should -Be -ExpectedValue '\\CA01.Contoso.com\c$\cert.pfx'
            $result.Enable                | Should -BeTrue
            $result.EnableSynchronization | Should -BeTrue
            $result.Schedule              | Should -Match $mockCimSchedule
            $result.Schedule              | Should -BeOfType '[Microsoft.Management.Infrastructure.CimInstance]'
            $result.Ensure                | Should -Be -ExpectedValue 'Present'
        }
    }
}

Describe 'ConfigMgrCBDsc - DSC_CMAssetIntelligencePoint\Set-TargetResource' -Tag 'Set' {
    BeforeAll{
        $testEnvironment = Initialize-TestEnvironment @initalize

        $mockCimSchedule = (New-CimInstance -ClassName DSC_CMAssetIntelligenceSynchronizationSchedule `
            -Namespace root/microsoft/Windows/DesiredStateConfiguration `
            -Property @{
                'RecurInterval' = 'Days'
                'RecurCount'    = 7
            } -ClientOnly
        )

        $mockCimScheduleDayMismatch = (New-CimInstance -ClassName DSC_CMAssetIntelligenceSynchronizationSchedule `
            -Namespace root/microsoft/Windows/DesiredStateConfiguration `
            -Property @{
                'RecurInterval' = 'Days'
                'RecurCount'    = 6
            } -ClientOnly
        )

        $getReturnAll = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            CertificateFile       = '\\CA01.Contoso.com\c$\cert.pfx'
            Enable                = $true
            EnableSynchronization = $true
            Schedule              = $mockCimSchedule
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $getReturnAbsent = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            CertificateFile       = $null
            Enable                = $null
            EnableSynchronization = $null
            Schedule              = $null
            Ensure                = 'Absent'
            IsSingleInstance      = 'Yes'
        }

        $returnEnabledDaysMismatch = @{
            SiteCode         = 'Lab'
            SiteServerName   = 'CA01.contoso.com'
            Schedule         = $mockCimScheduleDayMismatch
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
        }

        $inputNoSync = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            Enable                = $true
            EnableSynchronization = $false
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $inputNoCert = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            Enable                = $true
            EnableSynchronization = $true
            RemoveCertificate     = $true
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $inputAbsent = @{
            SiteCode         = 'Lab'
            SiteServerName   = 'CA01.contoso.com'
            Ensure           = 'Absent'
            IsSingleInstance = 'Yes'
        }

        $getReturnEnabledDays = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            CertificateFile       = $null
            Enable                = $true
            EnableSynchronization = $true
            Schedule              = $mockCimSchedule
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        Mock -CommandName Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName Set-Location -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint
    }
    AfterAll {
        Restore-TestEnvironment -TestEnvironment $testEnvironment
    }

    Context 'When Set-TargetResource runs successfully' {
        BeforeEach {
            $mockCimScheduleZero = (New-CimInstance -ClassName DSC_CMAssetIntelligenceSynchronizationSchedule `
                -Namespace root/microsoft/Windows/DesiredStateConfiguration `
                -Property @{
                    'RecurInterval' = 'Days'
                    'RecurCount'    = 0
                } -ClientOnly
            )

            $getReturnEnabledZero = @{
                SiteCode              = 'Lab'
                SiteServerName        = 'CA01.contoso.com'
                Schedule              = $mockCimScheduleZero
                EnableSynchronization = $true
                Ensure                = 'Present'
                IsSingleInstance      = 'Yes'
            }

            $getReturnNoSchedule = @{
                SiteCode              = 'Lab'
                SiteServerName        = 'CA01.contoso.com'
                CertificateFile       = $null
                Enable                = $true
                EnableSynchronization = $true
                Ensure                = 'Present'
                IsSingleInstance      = 'Yes'
            }

            $scheduleConvertDays = @{
                DayDuration    = 0
                DaySpan        = 7
                HourDuration   = 0
                HourSpan       = 0
                MinuteDuration = 0
                MinuteSpan     = 0
            }

            $scheduleConvertDaysMismatch = @{
                DayDuration    = 0
                DaySpan        = 6
                HourDuration   = 0
                HourSpan       = 0
                MinuteDuration = 0
                MinuteSpan     = 0
            }

            $scheduleConvertZero = @{
                DayDuration    = 0
                HourDuration   = 0
                IsGMT          = $false
                MinuteDuration = 0
            }
        }
        It 'Should call expected commands for when changing settings' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            Set-TargetResource @inputNoSync
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands when asset intelligence synchronization point is absent' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAbsent } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint

            Set-TargetResource @inputNoCert
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands when a certificate is present and needs to be removed' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            Set-TargetResource @inputNoCert
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands when changing the schedule' {
            Mock -CommandName Get-TargetResource -MockWith { $returnEnabledDaysMismatch } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { $scheduleConvertDays } -ParameterFilter { $RecurCount -eq 7 } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { $scheduleConvertDaysMismatch } -ParameterFilter { $RecurCount -eq 6 } -ModuleName DSC_CMAssetIntelligencePoint

            Set-TargetResource @getReturnEnabledDays
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands when asset intelligence point exists and expected absent' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            Set-TargetResource @inputAbsent
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
        }

        It 'Should call expected commands when a schedule is present and a nonrecurring schedule is specified' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnEnabledDays } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { $scheduleConvertZero } -ModuleName DSC_CMAssetIntelligencePoint

            Set-TargetResource @getReturnEnabledZero
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands when no schedule is present and a schedule is specified' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnNoSchedule } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { $scheduleConvertDays } -ModuleName DSC_CMAssetIntelligencePoint

            Set-TargetResource @getReturnEnabledDays
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands when a state is absent and a nonrecurring schedule is specified' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAbsent } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { $scheduleConvertZero } -ModuleName DSC_CMAssetIntelligencePoint

            Set-TargetResource @getReturnEnabledZero
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }
    }

    Context 'When Set-TargetResource throws' {
        BeforeEach{
            $syncScheduleThrow = @{
                SiteCode              = 'Lab'
                SiteServerName        = 'CA01.contoso.com'
                EnableSynchronization = $false
                Schedule              = $mockCimSchedule
                IsSingleInstance      = 'Yes'
            }

            $syncScheduleThrowMsg = 'When specifying a schedule, the EnableSynchronization paramater must be true.'

            $installThrow = @{
                SiteCode         = 'Lab'
                Ensure           = 'Present'
                IsSingleInstance = 'Yes'
            }

            $installThrowMsg = 'Role is not installed, need to specify SiteServerName to add.'

            $removeThrow = @{
                SiteCode         = 'Lab'
                Ensure           = 'Absent'
                IsSingleInstance = 'Yes'
            }

            $removeThrowMsg = 'Role is installed, need to specify SiteServerName to remove.'

            $certThrow = @{
                SiteCode          = 'Lab'
                SiteServerName    = 'CA01.contoso.com'
                RemoveCertificate = $true
                CertificateFile   = '\\CA01.Contoso.com\c$\cert.pfx'
                IsSingleInstance  = 'Yes'
            }

            $certThrowMsg = "When specifying a certificate, you can't specify RemoveCertificate as true."

            $inputPresent = @{
                SiteCode         = 'Lab'
                SiteServerName   = 'CA01.contoso.com'
                Ensure           = 'Present'
                IsSingleInstance = 'Yes'
            }
        }
        It 'Should call throws when a schedule is specified and enable synchronization is false' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @syncScheduleThrow } | Should -Throw -ExpectedMessage $syncScheduleThrowMsg
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call throws when the role needs to be installed and the SiteServerName parameter is not specified' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAbsent } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @installThrow } | Should -Throw -ExpectedMessage $installThrowMsg
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call throws when a certificate is specified and RemoveCertificate is true' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @certThrow } | Should -Throw -ExpectedMessage $certThrowMsg
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call throws when the role needs to be removed and the SiteServerName parameter is not specified' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @removeThrow } | Should -Throw -ExpectedMessage $removeThrowMsg
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands and throw if Get-CMSiteSystemServer throws' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAbsent } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Get-CMSiteSystemServer -MockWith { throw } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @inputPresent } | Should -Throw
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands and throw if New-CMSiteSystemServer throws' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAbsent } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSiteSystemServer -MockWith { throw } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @inputPresent } | Should -Throw
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands and throw if Add-CMAssetIntelligenceSynchronizationPoint throws' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAbsent } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSiteSystemServer -MockWith { $true } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Add-CMAssetIntelligenceSynchronizationPoint -MockWith { throw } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @inputNoCert } | Should -Throw
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands and throw if New-CMSchedule throws' {
            Mock -CommandName Get-TargetResource -MockWith { $returnEnabledDaysMismatch } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { throw } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @getReturnEnabledDays } | Should -Throw
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands and throw if Set-CMAssetIntelligenceSynchronizationPoint throws' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Set-CMAssetIntelligenceSynchronizationPoint -MockWith { throw } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @inputNoSync } | Should -Throw
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
        }

        It 'Should call expected commands and throw if Remove-CMAssetIntelligenceSynchronizationPoint throws' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName Remove-CMAssetIntelligenceSynchronizationPoint -MockWith { throw } -ModuleName DSC_CMAssetIntelligencePoint

            { Set-TargetResource @inputAbsent } | Should -Throw
            Should -Invoke Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Set-Location -ModuleName DSC_CMAssetIntelligencePoint -Exactly 2 -Scope It
            Should -Invoke Get-TargetResource -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
            Should -Invoke Get-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSiteSystemServer -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Add-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke New-CMSchedule -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Set-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 0 -Scope It
            Should -Invoke Remove-CMAssetIntelligenceSynchronizationPoint -ModuleName DSC_CMAssetIntelligencePoint -Exactly 1 -Scope It
        }
    }
}

Describe 'ConfigMgrCBDsc - DSC_CMAssetIntelligencePoint\Test-TargetResource' -Tag 'Test'{
    BeforeAll{
        $testEnvironment = Initialize-TestEnvironment @initalize

        $mockCimSchedule = (New-CimInstance -ClassName DSC_CMAssetIntelligenceSynchronizationSchedule `
            -Namespace root/microsoft/Windows/DesiredStateConfiguration `
            -Property @{
                'RecurInterval' = 'Days'
                'RecurCount'    = 7
            } -ClientOnly
        )

        $mockCimScheduleZero = (New-CimInstance -ClassName DSC_CMAssetIntelligenceSynchronizationSchedule `
                -Namespace root/microsoft/Windows/DesiredStateConfiguration `
                -Property @{
                    'RecurInterval' = 'Days'
                    'RecurCount'    = 0
                } -ClientOnly
            )

        $mockCimScheduleDayMismatch = (New-CimInstance -ClassName DSC_CMAssetIntelligenceSynchronizationSchedule `
            -Namespace root/microsoft/Windows/DesiredStateConfiguration `
            -Property @{
                'RecurInterval' = 'Days'
                'RecurCount'    = 6
            } -ClientOnly
        )

        $getReturnAll = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            CertificateFile       = '\\CA01.Contoso.com\c$\cert.pfx'
            Enable                = $true
            EnableSynchronization = $true
            Schedule              = $mockCimSchedule
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $getReturnAbsent = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            CertificateFile       = $null
            Enable                = $null
            EnableSynchronization = $null
            Schedule              = $null
            Ensure                = 'Absent'
            IsSingleInstance      = 'Yes'
        }

        $getReturnEnabledDays = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            CertificateFile       = $null
            Enable                = $true
            EnableSynchronization = $true
            Schedule              = $mockCimSchedule
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $getReturnEnabledZero = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            Schedule              = $mockCimScheduleZero
            EnableSynchronization = $true
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $getReturnNoSchedule = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            CertificateFile       = $null
            Enable                = $true
            EnableSynchronization = $true
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $getReturnNoCert = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            CertificateFile       = $null
            Enable                = $true
            EnableSynchronization = $true
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $inputPresent = @{
            SiteCode         = 'Lab'
            SiteServerName   = 'CA01.contoso.com'
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
        }

        $inputUseCert = @{
            SiteCode         = 'Lab'
            SiteServerName   = 'CA01.contoso.com'
            CertificateFile  = '\\CA01.Contoso.com\c$\cert.pfx'
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
        }

        $inputNoCert = @{
            SiteCode              = 'Lab'
            SiteServerName        = 'CA01.contoso.com'
            Enable                = $true
            EnableSynchronization = $true
            RemoveCertificate     = $true
            Ensure                = 'Present'
            IsSingleInstance      = 'Yes'
        }

        $inputAbsent = @{
            SiteCode         = 'Lab'
            SiteServerName   = 'CA01.contoso.com'
            Ensure           = 'Absent'
            IsSingleInstance = 'Yes'
        }

        $scheduleConvertDays = @{
            DayDuration    = 0
            DaySpan        = 7
            HourDuration   = 0
            HourSpan       = 0
            MinuteDuration = 0
            MinuteSpan     = 0
        }

        $scheduleConvertDaysMismatch = @{
            DayDuration    = 0
            DaySpan        = 6
            HourDuration   = 0
            HourSpan       = 0
            MinuteDuration = 0
            MinuteSpan     = 0
        }

        $returnEnabledDaysMismatch = @{
            SiteCode         = 'Lab'
            SiteServerName   = 'CA01.contoso.com'
            Schedule         = $mockCimScheduleDayMismatch
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
        }

        Mock -CommandName Set-Location -ModuleName DSC_CMAssetIntelligencePoint
        Mock -CommandName Import-ConfigMgrPowerShellModule -ModuleName DSC_CMAssetIntelligencePoint
    }
    AfterAll {
        Restore-TestEnvironment -TestEnvironment $testEnvironment
    }

    Context 'When running Test-TargetResource' {
        It 'Should return desired result false when ensure = present and AP is absent' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAbsent } -ModuleName DSC_CMAssetIntelligencePoint

            Test-TargetResource @inputPresent  | Should -BeFalse
        }

        It 'Should return desired result true when ensure = absent and AP is absent' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAbsent } -ModuleName DSC_CMAssetIntelligencePoint

            Test-TargetResource @inputAbsent | Should -BeTrue
        }

        It 'Should return desired result false when ensure = absent and AP is present' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            Test-TargetResource @inputAbsent | Should -BeFalse
        }

        It 'Should return desired result true when a certificate file is specified and a certificate file is present' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            Test-TargetResource @inputUseCert | Should -BeTrue
        }

        It 'Should return desired result false when a certificate file is not specified and a certificate file is present' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint

            Test-TargetResource @inputNoCert | Should -BeFalse
        }

        It 'Should return desired result true when no certificate file is specified and no certificate file is present' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnNoCert } -ModuleName DSC_CMAssetIntelligencePoint

            Test-TargetResource @inputNoCert | Should -BeTrue
        }

        It 'Should return desired result false when a certificate file is specified and no certificate file is present' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnNoCert  } -ModuleName DSC_CMAssetIntelligencePoint

            Test-TargetResource @inputUseCert  | Should -BeFalse
        }

        It 'Should return desired result false schedule days mismatch' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnEnabledDays } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { $scheduleConvertDays } -ParameterFilter { $RecurCount -eq 7 } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { $scheduleConvertDaysMismatch } -ParameterFilter { $RecurCount -eq 6 } -ModuleName DSC_CMAssetIntelligencePoint
            Test-TargetResource @returnEnabledDaysMismatch | Should -BeFalse
        }

        It 'Should return desired result true schedule matches' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnAll } -ModuleName DSC_CMAssetIntelligencePoint
            Mock -CommandName New-CMSchedule -MockWith { $scheduleConvertDays } -ModuleName DSC_CMAssetIntelligencePoint
            Test-TargetResource @getReturnAll | Should -BeTrue
        }

        It 'Should return desired result false schedule present but nonrecurring specified' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnEnabledDays } -ModuleName DSC_CMAssetIntelligencePoint
            Test-TargetResource @getReturnEnabledZero | Should -BeFalse
        }

        It 'Should return desired result false no schedule present but schedule specified' {
            Mock -CommandName Get-TargetResource -MockWith { $getReturnNoSchedule } -ModuleName DSC_CMAssetIntelligencePoint
            Test-TargetResource @getReturnEnabledDays | Should -BeFalse
        }
    }
}
