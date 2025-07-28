# HarjTech Power Platform Inventory

This package inventories your Microsoft Power Platform tenant using **PnP PowerShell** and related admin modules.  It produces a comprehensive report in a single Excel workbook with multiple worksheets covering apps, flows, connectors, data loss prevention policies, environments and security roles.  Use this solution to understand how the platform is being used, identify potential governance gaps and plan remediation actions.

## Contents

* **`HarjTech_PowerPlatform_Scan.ps1`** – PowerShell script that collects data and generates the report.  It includes HarjTech branding and citations linking to the official documentation used.
* **`HarjTech_PowerPlatform_Scan_README.md`** – This instruction file.

After running the script you will obtain **`HarjTech_PowerPlatform_Report.xlsx`** (or your specified path) with the following worksheets:

1. **PowerApps** – lists every Power App, its environment, primary owner, number of connectors and a semicolon‑separated list of connectors used.  The script calls `Get‑PnPPowerApp` with `-AsAdmin` to retrieve all apps in an environment【800570560665573†L845-L913】 and extracts connector references from the app’s internal `connectionReferences` property【493828033850901†L31-L44】.
2. **Flows** – lists every Power Automate flow, its environment, owners (resolved using `Get‑PnPFlowOwner`【960425369747814†L860-L879】), number of connectors and connector names.  Flows are obtained with `Get‑PnPFlow -AsAdmin`【363849683572617†L873-L904】.  Connector usage is derived from each flow’s internal `connectionReferences` property【493828033850901†L31-L44】.
3. **Connectors** – consolidates all connectors used by apps and flows as well as custom connectors retrieved using `Get‑PnPPowerPlatformCustomConnector`【689084732510419†L850-L876】.
4. **DLPPolicies** – lists Data Loss Prevention policies in your tenant.  Policies are fetched using `Get‑DlpPolicy` from the Power Apps administration module【539155472726819†L700-L740】.
5. **Environments** – enumerates all Power Platform environments (name, display name, region, SKU, default flag, created time and type) using `Get‑PnPPowerPlatformEnvironment`【902194326128828†L874-L918】.
6. **SecurityRoles** – lists environment role assignments (admin/maker) and associated users using `Get‑AdminPowerAppEnvironmentRoleAssignment`【628249980798264†L82-L110】.

## Prerequisites

1. **Windows PowerShell 5.x** – The Power Apps administration module requires .NET Framework and doesn’t work on PowerShell 7【539155472726819†L114-L126】.
2. **Modules**:
   * `PnP.PowerShell` version 2.1.0 or later – provides cmdlets for Power Platform management.
   * `ImportExcel` – used to create a multi‑worksheet Excel file.  Install via `Install‑Module ImportExcel` if not already present.
   * `Microsoft.PowerApps.Administration.PowerShell` and `Microsoft.PowerApps.PowerShell` – required to retrieve DLP policies and environment role assignments.  Install via PowerShell Gallery【539155472726819†L136-L167】.
3. **Administrator rights** – You must be a Power Platform administrator or tenant administrator.  Cmdlets like `Get‑PnPPowerApp -AsAdmin` and `Get‑PnPFlow -AsAdmin` return all apps and flows across the tenant【800570560665573†L845-L913】【363849683572617†L873-L904】.
4. **Authentication** – The script supports both interactive and credential‑based login.  Provide `-Username` and `-Password` parameters to run unattended.  If omitted, you will be prompted to sign in interactively.

## Usage

1. **Extract the package** to a directory on your computer (e.g., `C:\HarjTech\PPInventory`).

2. **Open PowerShell** as an administrator (Windows PowerShell 5.x).  Navigate to the extracted folder:

   ```powershell
   Set‑Location "C:\HarjTech\PPInventory"
   ```

3. **Install required modules** if they are not already installed:

   ```powershell
   Install‑Module PnP.PowerShell -Scope CurrentUser
   Install‑Module ImportExcel -Scope CurrentUser
   Install‑Module Microsoft.PowerApps.Administration.PowerShell -Scope CurrentUser
   Install‑Module Microsoft.PowerApps.PowerShell -AllowClobber -Scope CurrentUser
   ```

4. **Run the script**, supplying credentials if desired and specifying an output path for the report:

   ```powershell
   # With interactive login
   .\HarjTech_PowerPlatform_Scan.ps1 -ReportPath "C:\Reports\PPInventory.xlsx"

   # With credential‑based login
   .\HarjTech_PowerPlatform_Scan.ps1 -Username "admin@contoso.com" -Password "PlainTextPassword" -ReportPath "C:\Reports\PPInventory.xlsx"
   ```

5. When prompted (if running interactively), sign in with an account that has administrator privileges.

6. **Open the generated Excel file** to explore each worksheet.  Use filters and pivot tables to analyze connectors usage, identify apps and flows with risky connectors, cross‑reference environment roles and ensure your DLP policies cover the required connectors.

## Notes & Troubleshooting

* **Modules cannot be loaded** – Ensure you are running Windows PowerShell 5.x and not PowerShell 7; the Power Apps admin modules require .NET Framework【539155472726819†L114-L126】.
* **Authentication failures** – If login fails, try running `Add‑PowerAppsAccount` before executing the script to ensure the PowerApps modules are authenticated, or supply `-Username` and `-Password` to avoid prompts.
* **Partial data** – If DLP or security role worksheets are empty, confirm that the Power Apps administration modules were imported successfully.  Without these modules, those sections cannot be populated.

## About HarjTech

HarjTech specializes in Microsoft 365 and Power Platform governance, automation and adoption.  Our consultants help clients build robust governance frameworks, migrate legacy systems and implement solutions that drive digital transformation.  Contact us at **[www.harjtech.com](https://www.harjtech.com)** to learn how we can help with:

* **Tenant and environment audits** – assess the health of your Power Platform and Microsoft 365 environments.
* **Governance policy design** – establish controls for app proliferation, data loss prevention and lifecycle management.
* **Automation and integration** – leverage Power Automate, Azure Functions and Dataverse to streamline processes.

If this script provided value to you, please share it with your team and consider HarjTech for your next project.

## Disclaimer

This script is provided “as‑is” without any warranty.  HarjTech disclaims any liability for direct or indirect damages arising from its use.  Always test scripts in a development environment before running in production.
