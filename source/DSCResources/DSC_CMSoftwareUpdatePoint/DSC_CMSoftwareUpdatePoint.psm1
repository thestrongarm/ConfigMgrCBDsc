$script:dscResourceCommonPath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Modules\DscResource.Common'
$script:configMgrResourcehelper = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Modules\ConfigMgrCBDsc.ResourceHelper'

Import-Module -Name $script:dscResourceCommonPath
Import-Module -Name $script:configMgrResourcehelper

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

 <#
    .SYNOPSIS
        This will return a hashtable of results.

    .PARAMETER SiteCode
        Specifies the site code for Configuration Manager site.

    .PARAMETER SiteServerName
        Specifies the Site Server to install or configure the role on.

    .Notes
        This must be run on the Primary servers to install the software update role.
        The Primary server computer account must be in the local
        administrators group to perform the install.

#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $SiteCode,

        [Parameter(Mandatory = $true)]
        [String]
        $SiteServerName
    )

    Write-Verbose -Message $script:localizedData.RetrieveSettingValue
    Import-ConfigMgrPowerShellModule -SiteCode $SiteCode
    Set-Location -Path "$($SiteCode):\"

    $supProps = (Get-CMSoftwareUpdatePoint -SiteCode $SiteCode -SiteSystemServerName $SiteServerName).Props

    if ($supProps)
    {
        foreach ($supProp in $supProps)
        {
            switch ($supProp.PropertyName)
            {
                'AllowProxyTraffic' { $cloudGateway = $supProp.Value }
                'IsINF'             {
                                        if ($supProp.Value -eq '1')
                                        {
                                            $internet = 'Internet'
                                        }
                                    }
                'IsIntranet'        {
                                        if ($supProp.Value -eq '1')
                                        {
                                            $intranet = 'Intranet'
                                        }
                                    }
                'SSLWSUS'           { $enableSsl = $supProp.Value }
                'UseProxy'          { $useProxyGeneral = $supProp.Value }
                'UseProxyForADR'    { $useProxyForADR = $supProp.Value }
                'WSUSAccessAccount' {
                                        $accessAccount = $supProp.Value2
                                        if ([string]::IsNullOrEmpty($supProp.Value2))
                                        {
                                            $anonymousWsus = $true
                                        }
                                        else
                                        {
                                            $anonymousWsus = $false
                                        }
                                    }
                'WSUSIISPort'       { $wsusIis = $supProp.Value }
                'WSUSIISSSLPort'    { $wsusIisSsl = $supProp.Value }
            }
        }
        if ($internet -and $intranet)
        {
            $connectionType = 'InternetAndIntranet'
        }
        else
        {
            $connectionType = $internet + $intranet
        }

        $status = 'Present'
    }
    else
    {
        $status = 'Absent'
    }

    return @{
        SiteServerName                = $SiteServerName
        SiteCode                      = $SiteCode
        AnonymousWSUSAccess           = $anonymousWsus
        ClientConnectionType          = $connectionType
        EnableCloudGateway            = $cloudGateway
        UseProxy                      = $useProxyGeneral
        UseProxyForAutoDeploymentRule = $useProxyForADR
        WSUSAccessAccount             = $accessAccount
        WSUSIISPort                   = $wsusIis
        WSUSIISSSLPort                = $wsusIisSsl
        WSUSSSL                       = $enableSsl
        Ensure                        = $status
    }
}

 <#
    .SYNOPSIS
        This will set the desired state.

    .PARAMETER SiteCode
        Specifies a site code for the Configuration Manager site.

    .PARAMETER SiteServerName
        Specifies the Site Server to install or configure the role on.

    .PARAMETER AnonymousWSUSAccess
        Indicates that the software update point allows anonymous access. Mutually exclusive with WSUSAccessAccount.

    .PARAMETER ClientConnectionType
        Specifies the type of the client connection. The acceptable value are Internet,
        Intranet, and InterneAndIntranet.

    .PARAMETER EnableCloudGateway
        Specifies if a cloud gateway is to be used for the software update point.
        When enabling the cloud gateway, the client connectiontype must be either Internet or InterneAndIntranet.
        When enabling the cloud gateway, SSL must be enabled.

    .PARAMETER UseProxy
        Indicates whether a software update point uses the proxy configured for the site system server.

    .PARAMETER UseProxyForAutoDeploymentRule
        Indicates whether an auto deployment rule can use a proxy.

    .PARAMETER WSUSAccessAccount
        Specifies an account used to connect to the WSUS server. When not used, specify the AnonymousWSUSAccess parameter.

        If specifying an account the account must already exist in
        Configuration Manager. This can be achieved by using the CMAccounts Resource.

    .PARAMETER WsusIisPort
        Specifies a port to use for unsecured access to the WSUS server.

    .PARAMETER WsusIisSslPort
        Specifies a port to use for secured access to the WSUS server.

    .PARAMETER WsusSsl
        Specifies whether the software update point uses SSL to connect to the WSUS server.

    .PARAMETER Ensure
        Specifies whether the software update point is present or absent.

    .Notes
        This must be run on the Primary servers to install the software update role.
        The Primary server computer account must be in the local
        administrators group to perform the install.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $SiteCode,

        [Parameter(Mandatory = $true)]
        [String]
        $SiteServerName,

        [Parameter()]
        [Boolean]
        $AnonymousWsusAccess,

        [Parameter()]
        [ValidateSet('Internet', 'Intranet', 'InternetAndIntranet')]
        [String]
        $ClientConnectionType,

        [Parameter()]
        [Boolean]
        $EnableCloudGateway,

        [Parameter()]
        [Boolean]
        $UseProxy,

        [Parameter()]
        [Boolean]
        $UseProxyForAutoDeploymentRule,

        [Parameter()]
        [String]
        $WSUSAccessAccount,

        [Parameter()]
        [UInt32]
        $WsusIisPort,

        [Parameter()]
        [UInt32]
        $WsusIisSslPort,

        [Parameter()]
        [Boolean]
        $WsusSsl,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure = 'Present'
    )

    Import-ConfigMgrPowerShellModule -SiteCode $SiteCode
    Set-Location -Path "$($SiteCode):\"
    $state = Get-TargetResource -SiteCode $SiteCode -SiteServerName $SiteServerName

    try
    {
        if (($EnableCloudGateway -eq $true) -and (($PSBoundParameter.EnableCloudGateway -ne $false) -or
           ($state.EnableCloudGateway -eq $true)))
        {
            if (($ClientConnectionType -eq 'Intranet') -or ([string]::IsNullOrEmpty($ClientConnectionType) -and
                ([string]::IsNullOrEmpty($state.ClientConnectionType) -or $state.ClientConnectionType -eq 'Intranet')))
            {
                throw $script:localizedData.EnableGateway
            }

            if (($PSBoundParameters.WsusSsl -eq $false) -or
                ([string]::IsNullOrEmpty($PSBoundParameters.WsusSsl) -and
                ([string]::IsNullOrEmpty($state.EnableSSL) -or $state.WsusSsl -eq $false)))
            {
                throw $script:localizedData.GatewaySsl
            }
        }

        if (($WSUSAccessAccount) -and ($AnonymousWsusAccess -eq $true))
        {
            throw $script:localizedData.UsernameComputer
        }

        if ($Ensure -eq 'Present')
        {
            if ($state.Ensure -eq 'Absent')
            {
                if ($null -eq (Get-CMSiteSystemServer -SiteCode $SiteCode -SiteSystemServerName $SiteServerName))
                {
                    Write-Verbose -Message ($script:localizedData.SiteServerRole -f $SiteServerName)
                    New-CMSiteSystemServer -SiteCode $SiteCode -SiteSystemServerName $SiteServerName
                }

                Write-Verbose -Message ($script:localizedData.AddSUPRole -f $SiteServerName)
                Add-CMSoftwareUpdatePoint -SiteSystemServerName $SiteServerName -SiteCode $SiteCode
            }

            $evalList = @('AnonymousWSUSAccess','ClientConnectionType','EnableCloudGateway','UseProxy',
            'UseProxyForAutoDeploymentRule','WSUSAccessAccount','WSUSIISPort','WSUSIISSSLPort','WSUSSSL')

            foreach ($param in $PSBoundParameters.GetEnumerator())
            {
                if ($evalList -contains $param.key)
                    {
                        if ($param.Value -ne $state[$param.key])
                        {
                            Write-Verbose -Message ($script:localizedData.SettingValue -f $param.Key, $param.Value)
                            $buildingParams += @{
                                $param.Key = $param.Value
                            }
                        }
                    }
                }

            if ($buildingParams)
            {
                Set-CMSoftwareUpdatePoint -SiteSystemServerName $SiteServerName -SiteCode $SiteCode @buildingParams
            }
        }
        elseif ($state.Ensure -eq 'Present')
        {
            Write-Verbose -Message ($script:localizedData.RemoveSUPRole -f $SiteServerName)
            Remove-CMSoftwareUpdatePoint -SiteSystemServerName $SiteServerName -SiteCode $SiteCode
        }
    }
    catch
    {
        throw $_
    }
    finally
    {
        Set-Location -Path "$env:temp"
    }
}

<#
    .SYNOPSIS
        This will test the desired state.

    .PARAMETER SiteCode
        Specifies a site code for the Configuration Manager site.

    .PARAMETER SiteServerName
        Specifies the Site Server to install or configure the role on.

    .PARAMETER AnonymousWSUSAccess
        Indicates that the software update point allows anonymous access. Mutually exclusive with WSUSAccessAccount.

    .PARAMETER ClientConnectionType
        Specifies the type of the client connection. The acceptable value are Internet,
        Intranet, and InterneAndIntranet.

    .PARAMETER EnableCloudGateway
        Specifies if a cloud gateway is to be used for the software update point.
        When enabling the cloud gateway, the client connectiontype must be either Internet or InterneAndIntranet.
        When enabling the cloud gateway, SSL must be enabled.

    .PARAMETER UseProxy
        Indicates whether a software update point uses the proxy configured for the site system server.

    .PARAMETER UseProxyForAutoDeploymentRule
        Indicates whether an auto deployment rule can use a proxy.

    .PARAMETER WSUSAccessAccount
        Specifies an account used to connect to the WSUS server. When not used, specify the AnonymousWSUSAccess parameter.

        If specifying an account the account must already exist in
        Configuration Manager. This can be achieved by using the CMAccounts Resource.

    .PARAMETER WsusIisPort
        Specifies a port to use for unsecured access to the WSUS server.

    .PARAMETER WsusIisSslPort
        Specifies a port to use for secured access to the WSUS server.

    .PARAMETER WsusSsl
        Specifies whether the software update point uses SSL to connect to the WSUS server.

    .PARAMETER Ensure
        Specifies whether the software update point is present or absent.

    .Notes
        This must be run on the Primary servers to install the software update role.
        The Primary server computer account must be in the local
        administrators group to perform the install.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $SiteCode,

        [Parameter(Mandatory = $true)]
        [String]
        $SiteServerName,

        [Parameter()]
        [Boolean]
        $AnonymousWsusAccess,

        [Parameter()]
        [ValidateSet('Internet', 'Intranet', 'InternetAndIntranet')]
        [String]
        $ClientConnectionType,

        [Parameter()]
        [Boolean]
        $EnableCloudGateway,

        [Parameter()]
        [Boolean]
        $UseProxy,

        [Parameter()]
        [Boolean]
        $UseProxyForAutoDeploymentRule,

        [Parameter()]
        [String]
        $WSUSAccessAccount,

        [Parameter()]
        [UInt32]
        $WsusIisPort,

        [Parameter()]
        [UInt32]
        $WsusIisSslPort,

        [Parameter()]
        [Boolean]
        $WsusSsl,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure = 'Present'
    )

    Import-ConfigMgrPowerShellModule -SiteCode $SiteCode
    Set-Location -Path "$($SiteCode):\"
    $state = Get-TargetResource -SiteCode $SiteCode -SiteServerName $SiteServerName
    $result = $true

    if ($Ensure -eq 'Present')
    {
        if ($state.Ensure -eq 'Absent')
        {
            Write-Verbose -Message ($script:localizedData.SUPNotInstalled -f $SiteServerName)
            $result = $false
        }
        else
        {
            $evalList = @('AnonymousWSUSAccess','ClientConnectionType','EnableCloudGateway','UseProxy',
            'UseProxyForAutoDeploymentRule','WSUSAccessAccount','WSUSIISPort','WSUSIISSSLPort','WSUSSSL')

            foreach ($param in $PSBoundParameters.GetEnumerator())
            {
                if ($evalList -contains $param.key)
                {
                    if ($param.Value -ne $state[$param.key])
                    {
                        Write-Verbose -Message ($script:localizedData.TestSetting -f $param.Key, $param.Value, $state[$param.key])
                        $result = $false
                    }
                }
            }
        }
    }
    elseif ($state.Ensure -eq 'Present')
    {
        Write-Verbose -Message ($script:localizedData.SUPAbsent -f $SiteServerName)
        $result = $false
    }

    Write-Verbose -Message ($script:localizedData.TestState -f $result)
    Set-Location -Path "$env:temp"
    return $result
}

Export-ModuleMember -Function *-TargetResource
