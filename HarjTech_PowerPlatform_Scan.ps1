# ============================================================================
#  HarjTech Power Platform Inventory Script
#
#  Purpose:
#    This PnP.PowerShell based script inventories the Microsoft Power Platform
#    across your tenant and compiles an Excel workbook with multiple
#    worksheets.  The workbook contains:
#      1. **Power Apps** – a list of all Power Apps in each environment, the
#         primary owner and a summary of connectors used.  The script uses
#         `Get-PnPPowerApp` with the `-AsAdmin` switch to retrieve all apps
#         across the tenant【800570560665573†L845-L913】.  Connector usage is
#         derived from the app’s internal `connectionReferences` property
#         exposed by the underlying API【493828033850901†L31-L44】.
#      2. **Power Automate Flows** – a list of all flows, their owners and
#         connectors.  Flows are retrieved via `Get-PnPFlow -AsAdmin`
#         【363849683572617†L873-L904】 and owners are resolved using
#         `Get-PnPFlowOwner`【960425369747814†L860-L879】.  Connector
#         information is extracted from each flow’s internal
#         `connectionReferences` property【493828033850901†L31-L44】.
#      3. **Custom Connectors** – all custom connectors defined in each
#         environment, obtained through `Get-PnPPowerPlatformCustomConnector`
#         【689084732510419†L850-L876】.
#      4. **Data Loss Prevention (DLP) Policies** – retrieved via
#         `Get-DlpPolicy` from the Microsoft.PowerApps.Administration.PowerShell
#         module.  The Power Platform documentation notes that
#         `Get-DlpPolicy` returns all DLP policies for the tenant【539155472726819†L700-L740】.
#      5. **Environments** – a list of all Power Platform environments with
#         details such as display name, region, sku and whether it is the
#         default environment.  Environments are obtained with
#         `Get-PnPPowerPlatformEnvironment`【902194326128828†L874-L918】.
#      6. **Environment Security Groups** – lists the security role
#         assignments for each environment using `Get-AdminPowerAppEnvironmentRoleAssignment`.
#         This command returns environment role assignments for environment
#         administrators and makers【628249980798264†L82-L110】.
#
#  Copyright:
#    © 2025 HarjTech.  All rights reserved.  This solution was developed by
#    HarjTech and is provided "as‑is" without any warranties.  To learn
#    more about our professional services, governance assessments and
#    automation offerings, please visit https://www.harjtech.com.
#
#  Prerequisites:
#    • PnP.PowerShell module version 2.1.0 or higher.
#    • ImportExcel module (to generate multi‑worksheet reports).
#    • Microsoft.PowerApps.Administration.PowerShell module and
#      Microsoft.PowerApps.PowerShell module for DLP and environment role
#      assignments (requires Windows PowerShell 5.x).  See Microsoft
#      documentation for installation instructions【539155472726819†L136-L167】.
#    • You must be a Power Platform or tenant administrator to run this
#      script.  When using `Get-PnPPowerApp` and `Get-PnPFlow` the
#      `-AsAdmin` switch returns all resources【800570560665573†L845-L913】【363849683572617†L873-L904】.
#    • Use the -Username and -Password parameters to provide credentials
#      for unattended execution.  If omitted, an interactive login will be
#      used.
#
#  Usage:
#    .\HarjTech_PowerPlatform_Scan.ps1 -Username "admin@contoso.com" \
#      -Password "PlainTextPassword" -ReportPath "C:\Reports\PPInventory.xlsx"
#
# ============================================================================

[CmdletBinding()]
param(
    # Optional credentials for authentication
    [Parameter(Mandatory = $false)]
    [string] $Username,

    [Parameter(Mandatory = $false)]
    [string] $Password,

    # Path to the Excel workbook to create
    [Parameter(Mandatory = $false)]
    [string] $ReportPath = "$(Join-Path -Path (Get-Location) -ChildPath 'HarjTech_PowerPlatform_Report.xlsx')"
)

begin {
    # Create a global credential if provided
    if ($Username -and $Password) {
        try {
            $secPwd = ConvertTo-SecureString -String $Password -AsPlainText -Force
            $script:SessionCredential = [System.Management.Automation.PSCredential]::new($Username, $secPwd)
        } catch {
            Write-Warning "Unable to create credential: $_"
            $script:SessionCredential = $null
        }
    } else {
        $script:SessionCredential = $null
    }

    # Ensure required modules are available
    function Ensure-Module {
        param(
            [Parameter(Mandatory=$true)] [string] $Name
        )
        if (-not (Get-Module -ListAvailable -Name $Name)) {
            Write-Warning "Module $Name is not installed.  Installing..."
            Install-Module -Name $Name -Scope CurrentUser -Force -ErrorAction Stop
        }
        Import-Module $Name -ErrorAction Stop
    }

    Ensure-Module -Name "PnP.PowerShell"
    Ensure-Module -Name "ImportExcel"
    # The PowerApps modules may only load in Windows PowerShell 5.x; attempt to import but ignore errors
    try {
        Ensure-Module -Name "Microsoft.PowerApps.Administration.PowerShell"
        Ensure-Module -Name "Microsoft.PowerApps.PowerShell"
    } catch {
        Write-Warning "Could not load PowerApps Administration modules. DLP and role assignment data may not be collected."
    }
}

process {
    # Connect to PnP and Power Apps service
    if ($script:SessionCredential) {
        Connect-PnPOnline -Url "https://graph.microsoft.com" -Credentials $script:SessionCredential -ErrorAction Stop
        # Add-PowerAppsAccount for admin modules
        try {
            Add-PowerAppsAccount -Username $Username -Password (ConvertTo-SecureString $Password -AsPlainText -Force) -ErrorAction Stop
        } catch {
            Write-Warning "Add-PowerAppsAccount failed: $_"
        }
    } else {
        Connect-PnPOnline -Url "https://graph.microsoft.com" -Interactive -ErrorAction Stop
        try { Add-PowerAppsAccount -ErrorAction Stop } catch { Write-Warning "Interactive PowerApps login failed: $_" }
    }

    # Retrieve all Power Platform environments
    Write-Host "Retrieving environments..." -ForegroundColor Cyan
    $environments = Get-PnPPowerPlatformEnvironment

    # Initialize collections for worksheets
    $appsReport = @()
    $flowsReport = @()
    $connectorsReport = @()
    $dlpReport = @()
    $envReport = @()
    $securityReport = @()

    foreach ($env in $environments) {
        Write-Host "Processing environment: $($env.DisplayName)" -ForegroundColor Green
        $envId = $env.Name
        # Collect environment metadata
        $envRow = [ordered]@{}
        $envRow.EnvironmentId = $envId
        $envRow.DisplayName = $env.DisplayName
        $envRow.Region = $env.Region
        $envRow.Sku = $env.EnvironmentSku
        $envRow.IsDefault = $env.IsDefault
        $envRow.CreatedTime = $env.CreatedTime
        $envRow.Type = $env.EnvironmentType
        $envReport += [PSCustomObject]$envRow

        # Apps in environment
        $apps = Get-PnPPowerApp -Environment $env -AsAdmin
        foreach ($app in $apps) {
            $appRow = [ordered]@{}
            $appRow.EnvironmentId = $envId
            $appRow.AppName = $app.DisplayName
            $appRow.AppId = $app.Name
            # Determine primary owner
            $owner = $null
            if ($app.Owner) { $owner = $app.Owner.DisplayName }
            elseif ($app.CreatedBy -and $app.CreatedBy.UserPrincipalName) { $owner = $app.CreatedBy.UserPrincipalName }
            else { $owner = $app.Internal.properties.creator.userPrincipalName }
            $appRow.Owner = $owner
            # Extract connectors used
            $connNames = @()
            try {
                $connRefs = $app.Internal.properties.connectionReferences
                if ($connRefs) {
                    foreach ($prop in $connRefs.PSObject.Properties) {
                        $val = $prop.Value
                        if ($val.DisplayName) { $connNames += $val.DisplayName }
                        elseif ($val.apiId) { $connNames += $val.apiId }
                    }
                }
            } catch {
                Write-Verbose "Failed to read connectors for app $($app.DisplayName)"
            }
            $appRow.ConnectorCount = $connNames.Count
            $appRow.Connectors = ($connNames -join ';')
            $appsReport += [PSCustomObject]$appRow
            # Add to connectorsReport list
            foreach ($c in $connNames) {
                $connectorsReport += [PSCustomObject]@{ EnvironmentId = $envId; ParentType = 'App'; ParentName = $app.DisplayName; Connector = $c }
            }
        }

        # Flows in environment
        $flows = Get-PnPFlow -Environment $env -AsAdmin
        foreach ($flow in $flows) {
            $flowRow = [ordered]@{}
            $flowRow.EnvironmentId = $envId
            $flowRow.FlowName = $flow.DisplayName
            $flowRow.FlowId = $flow.Name
            # Determine owners
            $owners = @()
            try {
                $ownerObjs = Get-PnPFlowOwner -Environment $env -Identity $flow.Name -AsAdmin -ErrorAction Stop
                foreach ($o in $ownerObjs) { $owners += $o.PrincipalDisplayName }
            } catch {
                Write-Verbose "Failed to get owners for flow $($flow.DisplayName)"
            }
            $flowRow.Owners = ($owners -join ';')
            # Extract connectors
            $flowConns = @()
            try {
                $connRefs = $flow.Internal.properties.connectionReferences
                if ($connRefs) {
                    foreach ($prop in $connRefs.PSObject.Properties) {
                        $val = $prop.Value
                        if ($val.DisplayName) { $flowConns += $val.DisplayName }
                        elseif ($val.apiId) { $flowConns += $val.apiId }
                    }
                }
            } catch {
                Write-Verbose "Failed to read connectors for flow $($flow.DisplayName)"
            }
            $flowRow.ConnectorCount = $flowConns.Count
            $flowRow.Connectors = ($flowConns -join ';')
            $flowsReport += [PSCustomObject]$flowRow
            # Add to connectorsReport list
            foreach ($c in $flowConns) {
                $connectorsReport += [PSCustomObject]@{ EnvironmentId = $envId; ParentType = 'Flow'; ParentName = $flow.DisplayName; Connector = $c }
            }
        }

        # Custom connectors in environment
        try {
            $customConns = Get-PnPPowerPlatformCustomConnector -Environment $env -AsAdmin
            foreach ($cc in $customConns) {
                $connectorsReport += [PSCustomObject]@{ EnvironmentId = $envId; ParentType = 'CustomConnector'; ParentName = $cc.DisplayName; Connector = $cc.DisplayName }
            }
        } catch {
            Write-Verbose "Could not retrieve custom connectors for environment $($env.DisplayName): $_"
        }

        # Security groups / role assignments for environment (requires PowerApps admin module)
        try {
            $assignments = Get-AdminPowerAppEnvironmentRoleAssignment -EnvironmentName $envId
            foreach ($assign in $assignments) {
                $securityReport += [PSCustomObject]@{
                    EnvironmentId = $envId
                    RoleName = $assign.RoleName
                    PrincipalType = $assign.PrincipalType
                    PrincipalName = $assign.PrincipalDisplayName
                }
            }
        } catch {
            Write-Verbose "Could not retrieve environment role assignments for $($env.DisplayName): $_"
        }
    }

    # Data Loss Prevention policies
    try {
        $dlps = Get-DlpPolicy
        foreach ($p in $dlps) {
            $dlpReport += [PSCustomObject]@{
                PolicyName = $p.DisplayName
                PolicyId = $p.ObjectId
                CreatedOn = $p.CreatedTime
                LastModifiedOn = $p.LastModifiedTime
                Mode = $p.Mode
            }
        }
    } catch {
        Write-Verbose "Could not retrieve DLP policies: $_"
    }

    # Create Excel workbook with multiple worksheets
    Write-Host "Creating Excel report..." -ForegroundColor Cyan
    $excelParams = @{ Path = $ReportPath; ClearSheet = $true }
    $appsReport | Export-Excel @excelParams -WorksheetName "PowerApps"
    $flowsReport | Export-Excel @excelParams -WorksheetName "Flows" -Append
    $connectorsReport | Export-Excel @excelParams -WorksheetName "Connectors" -Append
    $dlpReport | Export-Excel @excelParams -WorksheetName "DLPPolicies" -Append
    $envReport | Export-Excel @excelParams -WorksheetName "Environments" -Append
    $securityReport | Export-Excel @excelParams -WorksheetName "SecurityRoles" -Append

    Write-Host "Report generated at $ReportPath" -ForegroundColor Green
}