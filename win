# ============================================================
# 👉 MASTER WINDOWS SETUP & CLEANUP SCRIPT
# 👉 Developed By @MRGARGSIR
# 👉 PART A: ALL FUNCTIONS (Sections 1-22)
# ============================================================

#Requires -RunAsAdministrator
Set-ExecutionPolicy Bypass -Scope Process -Force
Add-Type -AssemblyName System.Windows.Forms   # 👉 loaded once here, used by menu + all GUI functions
Add-Type -AssemblyName System.Drawing

# ---------------- SECTION 1: BLOATWARE REMOVAL ----------------
function Remove-WindowsBloat {
    Write-Host "`n[*] Removing Windows bloatware apps..." -ForegroundColor Cyan
    $KeepApps = @("Microsoft.WindowsCalculator","Microsoft.WindowsNotepad","Microsoft.Paint","Microsoft.Paint3D","Microsoft.Windows.Photos","Microsoft.WindowsStore","Microsoft.StorePurchaseApp","Microsoft.WindowsCamera")
    $BloatApps = @("Microsoft.3DBuilder","Microsoft.BingFinance","Microsoft.BingNews","Microsoft.BingSports","Microsoft.BingWeather","Microsoft.GetHelp","Microsoft.Getstarted","Microsoft.Messaging","Microsoft.Microsoft3DViewer","Microsoft.MicrosoftOfficeHub","Microsoft.MicrosoftSolitaireCollection","Microsoft.MixedReality.Portal","Microsoft.NetworkSpeedTest","Microsoft.News","Microsoft.Office.OneNote","Microsoft.People","Microsoft.Print3D","Microsoft.SkypeApp","Microsoft.Wallet","Microsoft.WindowsAlarms","Microsoft.WindowsFeedbackHub","Microsoft.WindowsMaps","Microsoft.WindowsSoundRecorder","Microsoft.Xbox.TCUI","Microsoft.XboxApp","Microsoft.XboxGameOverlay","Microsoft.XboxGamingOverlay","Microsoft.XboxIdentityProvider","Microsoft.XboxSpeechToTextOverlay","Microsoft.YourPhone","Microsoft.ZuneMusic","Microsoft.ZuneVideo","Microsoft.GamingApp","Microsoft.Todos","Microsoft.PowerAutomateDesktop","Microsoft.OutlookForWindows","MicrosoftTeams","Clipchamp.Clipchamp","Microsoft.549981C3F5F10")
    foreach ($app in $BloatApps) {
        if ($KeepApps -notcontains $app) {
            Write-Host "  Removing $app" -ForegroundColor DarkGray
            Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }
    }
    Write-Host "[+] Bloatware removal complete." -ForegroundColor Green
}

# ---------------- SECTION 2: SOFTWARE UNINSTALLER (GUI CHECKBOX) ----------------
function Show-InstalledSoftware {
    Write-Host "`n[*] Scanning installed software..." -ForegroundColor Cyan
    $paths = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*","HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
    $software = Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.UninstallString } | Select-Object DisplayName, UninstallString, PSChildName | Sort-Object DisplayName -Unique
    if (-not $software) { [System.Windows.Forms.MessageBox]::Show("No software found.", "Info") | Out-Null; return }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Software to Uninstall - @MRGARGSIR"
    $form.Size = New-Object System.Drawing.Size(560, 620)
    $form.StartPosition = "CenterScreen"; $form.FormBorderStyle = "FixedDialog"; $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30); $form.ForeColor = [System.Drawing.Color]::White

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Location = New-Object System.Drawing.Point(10, 10); $searchBox.Size = New-Object System.Drawing.Size(520, 24)
    $searchBox.BackColor = [System.Drawing.Color]::FromArgb(45,45,45); $searchBox.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($searchBox)

    $checkList = New-Object System.Windows.Forms.CheckedListBox
    $checkList.Location = New-Object System.Drawing.Point(10, 44); $checkList.Size = New-Object System.Drawing.Size(520, 460)
    $checkList.CheckOnClick = $true; $checkList.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
    $checkList.ForeColor = [System.Drawing.Color]::White; $checkList.BorderStyle = "FixedSingle"
    $form.Controls.Add($checkList)
    foreach ($item in $software) { [void]$checkList.Items.Add($item.DisplayName) }

    $searchBox.Add_TextChanged({
        $filter = $searchBox.Text; $checkList.Items.Clear()
        foreach ($item in $software) { if ($item.DisplayName -like "*$filter*") { [void]$checkList.Items.Add($item.DisplayName) } }
    })

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Select All"; $btnSelectAll.Location = New-Object System.Drawing.Point(10, 512); $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.Add_Click({ for ($i = 0; $i -lt $checkList.Items.Count; $i++) { $checkList.SetItemChecked($i, $true) } })
    $form.Controls.Add($btnSelectAll)

    $btnSelectNone = New-Object System.Windows.Forms.Button
    $btnSelectNone.Text = "Select None"; $btnSelectNone.Location = New-Object System.Drawing.Point(140, 512); $btnSelectNone.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectNone.Add_Click({ for ($i = 0; $i -lt $checkList.Items.Count; $i++) { $checkList.SetItemChecked($i, $false) } })
    $form.Controls.Add($btnSelectNone)

    $btnUninstall = New-Object System.Windows.Forms.Button
    $btnUninstall.Text = "Uninstall Selected"; $btnUninstall.Location = New-Object System.Drawing.Point(340, 512); $btnUninstall.Size = New-Object System.Drawing.Size(190, 34)
    $btnUninstall.BackColor = [System.Drawing.Color]::FromArgb(200,60,60); $btnUninstall.ForeColor = [System.Drawing.Color]::White
    $btnUninstall.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnUninstall); $form.AcceptButton = $btnUninstall

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"; $btnCancel.Location = New-Object System.Drawing.Point(340, 552); $btnCancel.Size = New-Object System.Drawing.Size(190, 30)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel); $form.CancelButton = $btnCancel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { Write-Host "Uninstall cancelled by user." -ForegroundColor DarkGray; return }

    $checkedNames = $checkList.CheckedItems | ForEach-Object { $_.ToString() }
    if ($checkedNames.Count -eq 0) { Write-Host "No items selected." -ForegroundColor Yellow; return }
    $targets = $software | Where-Object { $checkedNames -contains $_.DisplayName }

    foreach ($target in $targets) {
        Write-Host "  Uninstalling: $($target.DisplayName)" -ForegroundColor DarkGray
        try {
            if ($target.UninstallString -match "msiexec") {
                $productCode = $target.PSChildName
                Start-Process "msiexec.exe" -ArgumentList "/x $productCode /quiet /norestart" -Wait
            } else {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($target.UninstallString)`"" -Wait
            }
            Write-Host "  Done: $($target.DisplayName)" -ForegroundColor Green
        } catch { Write-Host "  Failed: $($target.DisplayName) - $($_.Exception.Message)" -ForegroundColor Red }
    }
    [System.Windows.Forms.MessageBox]::Show("Uninstall process finished. Check console for details.", "Done") | Out-Null
}

# ---------------- SECTION 3: STARTUP ITEMS ----------------
function Disable-StartupItems {
    Write-Host "`n[*] Disabling common startup items..." -ForegroundColor Cyan
    $targetKeywords = @("anydesk","bluestacks","hd-player","chrome","googlechrome","microsoftedgeautolaunch","edgeupdate","spotify","discord","teams","adobe","acrord32","acrotray","skype","steam","epicgameslauncher","onedrive")
    $regPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run","HKLM:\Software\Microsoft\Windows\CurrentVersion\Run","HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run")
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $entries = Get-Item $path
            foreach ($name in $entries.Property) {
                foreach ($keyword in $targetKeywords) {
                    if ($name -match $keyword) {
                        Write-Host "  Removing startup entry: $name ($path)" -ForegroundColor DarkGray
                        Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
    $startupApprovedPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run","HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32")
    foreach ($path in $startupApprovedPaths) {
        if (Test-Path $path) {
            $entries = Get-Item $path
            foreach ($name in $entries.Property) {
                foreach ($keyword in $targetKeywords) {
                    if ($name -match $keyword) {
                        Write-Host "  Disabling modern startup app: $name" -ForegroundColor DarkGray
                        $disabledValue = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                        Set-ItemProperty -Path $path -Name $name -Value $disabledValue -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "Adobe|Teams|Discord|Spotify|GoogleUpdate|EdgeUpdate|AnyDesk" }
    foreach ($task in $tasks) {
        Write-Host "  Disabling scheduled task: $($task.TaskName)" -ForegroundColor DarkGray
        Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Host "[+] Startup items disabled." -ForegroundColor Green
}

# ---------------- SECTION 4: TASKBAR TWEAKS ----------------
function Set-TaskbarTweaks {
    Write-Host "`n[*] Applying taskbar tweaks..." -ForegroundColor Cyan
    $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $feedsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"
    if (-not (Test-Path $advPath)) { New-Item -Path $advPath -Force | Out-Null }
    Set-ItemProperty -Path $advPath -Name "TaskbarAl" -Value 0 -Type DWord -Force
    if (-not (Test-Path $searchPath)) { New-Item -Path $searchPath -Force | Out-Null }
    Set-ItemProperty -Path $searchPath -Name "SearchboxTaskbarMode" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $advPath -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $advPath -Name "TaskbarDa" -Value 0 -Type DWord -Force
    if (-not (Test-Path $feedsPath)) { New-Item -Path $feedsPath -Force | Out-Null }
    Set-ItemProperty -Path $feedsPath -Name "ShellFeedsTaskbarViewMode" -Value 2 -Type DWord -Force
    Write-Host "[+] Taskbar tweaks applied." -ForegroundColor Green
}

# ---------------- SECTION 5: EXPLORER TWEAKS ----------------
function Set-ExplorerTweaks {
    Write-Host "`n[*] Applying File Explorer tweaks..." -ForegroundColor Cyan
    $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $advPath -Name "LaunchTo" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $advPath -Name "Hidden" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $advPath -Name "HideFileExt" -Value 0 -Type DWord -Force
    Write-Host "[+] Explorer tweaks applied." -ForegroundColor Green
}

# ---------------- SECTION 6: RESTART EXPLORER ----------------
function Restart-Explorer {
    Write-Host "`n[*] Restarting Explorer..." -ForegroundColor Cyan
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process explorer.exe
    Write-Host "[+] Explorer restarted." -ForegroundColor Green
}

# ---------------- SECTION 7: MULTIPLE ANTIVIRUS CHECK ----------------
function Test-MultipleAntivirus {
    Write-Host "`n[*] Checking installed antivirus products..." -ForegroundColor Cyan
    $avProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
    if (-not $avProducts) { Write-Host "  Could not query AV products." -ForegroundColor Yellow; return }
    $names = $avProducts | Select-Object -ExpandProperty displayName -Unique
    if ($names.Count -gt 1) {
        Write-Host "  WARNING: Multiple antivirus products detected:" -ForegroundColor Red
        $names | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
        $msg = "Multiple antivirus products were detected:`n`n" + ($names -join "`n") + "`n`nRunning more than one antivirus can cause conflicts and false positives.`n`nOpen 'Apps & Features' now to uninstall extras?"
        $result = [System.Windows.Forms.MessageBox]::Show($msg, "Multiple Antivirus Detected", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) { Start-Process "ms-settings:appsfeatures" }
    } else { Write-Host "  OK - single or no antivirus detected." -ForegroundColor Green }
}

# ---------------- SECTION 8: DISABLE COPILOT ----------------
function Disable-Copilot {
    Write-Host "`n[*] Disabling Windows Copilot..." -ForegroundColor Cyan
    $policyPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    $policyPathMachine = "HKLM:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    foreach ($p in @($policyPath, $policyPathMachine)) {
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        Set-ItemProperty -Path $p -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
    }
    Set-ItemProperty -Path $advPath -Name "ShowCopilotButton" -Value 0 -Type DWord -Force
    Get-AppxPackage -Name "Microsoft.Windows.Ai.Copilot.Provider" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    Write-Host "[+] Copilot disabled." -ForegroundColor Green
}

# ---------------- SECTION 9: DISABLE SCHEDULED TASKS ----------------
function Disable-UnnecessaryScheduledTasks {
    Write-Host "`n[*] Disabling unnecessary scheduled tasks..." -ForegroundColor Cyan
    $tasksToDisable = @("Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser","Microsoft\Windows\Application Experience\ProgramDataUpdater","Microsoft\Windows\Autochk\Proxy","Microsoft\Windows\Customer Experience Improvement Program\Consolidator","Microsoft\Windows\Customer Experience Improvement Program\UsbCeip","Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector","Microsoft\Windows\Feedback\Siuf\DmClient","Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload","Microsoft\Windows\Windows Error Reporting\QueueReporting","Microsoft\Windows\Maps\MapsToastTask","Microsoft\Windows\Maps\MapsUpdateTask","Microsoft\Windows\PI\Sqm-Tasks","Microsoft\Windows\Shell\FamilySafetyMonitor","Microsoft\Windows\Shell\FamilySafetyRefresh","Microsoft\Windows\Retail Demo\CleanupOffline")
    foreach ($taskPath in $tasksToDisable) {
        $taskName = Split-Path $taskPath -Leaf
        $folder = "\" + (Split-Path $taskPath -Parent).Replace("\", "\") + "\"
        try {
            Disable-ScheduledTask -TaskName $taskName -TaskPath $folder -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  Disabled: $taskPath" -ForegroundColor DarkGray
        } catch {}
    }
    Write-Host "[+] Unnecessary scheduled tasks disabled." -ForegroundColor Green
}

# ---------------- SECTION 10: TELEMETRY + ADVERTISING ID ----------------
function Disable-TelemetryAndAdvertising {
    Write-Host "`n[*] Disabling telemetry and advertising ID..." -ForegroundColor Cyan
    $telemetryPath = "HKLM:\Software\Policies\Microsoft\Windows\DataCollection"
    if (-not (Test-Path $telemetryPath)) { New-Item -Path $telemetryPath -Force | Out-Null }
    Set-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force
    Stop-Service "DiagTrack" -Force -ErrorAction SilentlyContinue
    Set-Service "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    $advertisingPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    if (-not (Test-Path $advertisingPath)) { New-Item -Path $advertisingPath -Force | Out-Null }
    Set-ItemProperty -Path $advertisingPath -Name "Enabled" -Value 0 -Type DWord -Force
    $advertisingPolicyPath = "HKLM:\Software\Policies\Microsoft\Windows\AdvertisingInfo"
    if (-not (Test-Path $advertisingPolicyPath)) { New-Item -Path $advertisingPolicyPath -Force | Out-Null }
    Set-ItemProperty -Path $advertisingPolicyPath -Name "DisabledByGroupPolicy" -Value 1 -Type DWord -Force
    $privacyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    if (-not (Test-Path $privacyPath)) { New-Item -Path $privacyPath -Force | Out-Null }
    Set-ItemProperty -Path $privacyPath -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force
    Write-Host "[+] Telemetry and advertising ID disabled." -ForegroundColor Green
}

# ---------------- SECTION 11: DEFENDER ENABLE + UPDATE ----------------
function Enable-DefenderAndUpdate {
    Write-Host "`n[*] Enabling Windows Defender and updating signatures..." -ForegroundColor Cyan
    try { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop; Write-Host "  Real-time protection enabled." -ForegroundColor DarkGray }
    catch { Write-Host "  Could not toggle real-time protection." -ForegroundColor Yellow }
    try { Update-MpSignature -ErrorAction Stop; Write-Host "  Defender signatures updated." -ForegroundColor DarkGray }
    catch { Write-Host "  Signature update failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    Write-Host "[+] Defender check complete." -ForegroundColor Green
}

# ---------------- SECTION 12: WINDOWS ACTIVATION CHECK ----------------
function Test-WindowsActivation {
    Write-Host "`n[*] Checking Windows activation status..." -ForegroundColor Cyan
    try {
        $lic = Get-CimInstance -Query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" -ErrorAction Stop
        $statusMap = @{0="Unlicensed";1="Licensed (Activated)";2="Out-Of-Box Grace Period";3="Out-Of-Tolerance Grace Period";4="Non-Genuine Grace Period";5="Notification";6="Extended Grace Period"}
        foreach ($item in $lic) {
            $statusText = $statusMap[[int]$item.LicenseStatus]
            $color = if ($item.LicenseStatus -eq 1) { "Green" } else { "Red" }
            Write-Host "  Edition: $($item.Name)" -ForegroundColor DarkGray
            Write-Host "  Status : $statusText" -ForegroundColor $color
        }
    } catch { Write-Host "  Could not query activation status: $($_.Exception.Message)" -ForegroundColor Yellow }
}

# ---------------- SECTION 13: OFFICE ACTIVATION CHECK ----------------
function Test-OfficeActivation {
    Write-Host "`n[*] Checking Microsoft Office activation status..." -ForegroundColor Cyan
    $osppPaths = @("$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs","${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs")
    $osppScript = $osppPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $osppScript) { Write-Host "  Microsoft Office not found (or ospp.vbs missing)." -ForegroundColor Yellow; return }
    try {
        $output = cscript //nologo "$osppScript" /dstatus 2>&1
        $blocks = ($output -join "`n") -split "----"
        foreach ($block in $blocks) {
            if ($block -match "LICENSE STATUS:\s*(.+)") {
                $status = $Matches[1].Trim()
                $nameMatch = [regex]::Match($block, "SKU ID:.*?LICENSE NAME:\s*(.+)")
                $name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value.Trim() } else { "Unknown SKU" }
                $color = if ($status -match "LICENSED") { "Green" } else { "Red" }
                Write-Host "  Product: $name" -ForegroundColor DarkGray
                Write-Host "  Status : $status" -ForegroundColor $color
            }
        }
    } catch { Write-Host "  Could not run ospp.vbs: $($_.Exception.Message)" -ForegroundColor Yellow }
}

# ---------------- SECTION 14: TEMP + UPDATE CACHE CLEANUP ----------------
function Clear-TempAndUpdateCache {
    Write-Host "`n[*] Cleaning temporary files and Windows Update cache..." -ForegroundColor Cyan
    $tempPaths = @("$env:TEMP\*","$env:WINDIR\Temp\*","$env:WINDIR\Prefetch\*")
    foreach ($path in $tempPaths) { Write-Host "  Clearing: $path" -ForegroundColor DarkGray; Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue }
    $services = @("wuauserv", "bits", "cryptsvc")
    foreach ($svc in $services) { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue }
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($svc in $services) { Start-Service -Name $svc -ErrorAction SilentlyContinue }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Temp files and Update cache cleared." -ForegroundColor Green
}

# ---------------- SECTION 15: UPDATE ALL APPS ----------------
function Update-AllApps {
    Write-Host "`n[*] Updating all apps..." -ForegroundColor Cyan
    try {
        Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" -ErrorAction SilentlyContinue | Invoke-CimMethod -MethodName UpdateScanMethod -ErrorAction SilentlyContinue | Out-Null
    } catch { Write-Host "  Store app scan trigger skipped." -ForegroundColor Yellow }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Running winget upgrade --all..." -ForegroundColor DarkGray
        winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
    } else { Write-Host "  winget not found - skipping desktop app updates." -ForegroundColor Yellow }
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Write-Host "  Running Windows Update..." -ForegroundColor DarkGray
        Import-Module PSWindowsUpdate
        Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false
    } else { Write-Host "  PSWindowsUpdate module not installed - skipping OS update step." -ForegroundColor Yellow }
    Write-Host "[+] Update pass complete." -ForegroundColor Green
}

# ---------------- SECTION 16: CLASSIC CONTEXT MENU ----------------
function Enable-ClassicContextMenu {
    Write-Host "`n[*] Restoring classic right-click context menu..." -ForegroundColor Cyan
    $clsidPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    if (-not (Test-Path $clsidPath)) { New-Item -Path $clsidPath -Force | Out-Null }
    Set-ItemProperty -Path $clsidPath -Name "(Default)" -Value "" -Force
    Write-Host "[+] Classic context menu enabled (Explorer restart required)." -ForegroundColor Green
}

# ---------------- SECTION 17: LOCK SCREEN ADS/TIPS ----------------
function Disable-LockScreenAdsAndTips {
    Write-Host "`n[*] Disabling lock screen ads and tips..." -ForegroundColor Cyan
    $contentDeliveryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (-not (Test-Path $contentDeliveryPath)) { New-Item -Path $contentDeliveryPath -Force | Out-Null }
    $cdmSettings = @{"RotatingLockScreenOverlayEnabled"=0;"SubscribedContent-338387Enabled"=0;"SubscribedContent-338388Enabled"=0;"SubscribedContent-338389Enabled"=0;"SubscribedContent-353694Enabled"=0;"SubscribedContent-353696Enabled"=0;"SilentInstalledAppsEnabled"=0;"SystemPaneSuggestionsEnabled"=0;"ContentDeliveryAllowed"=0;"OemPreInstalledAppsEnabled"=0;"PreInstalledAppsEnabled"=0;"PreInstalledAppsEverEnabled"=0}
    foreach ($key in $cdmSettings.Keys) { Set-ItemProperty -Path $contentDeliveryPath -Name $key -Value $cdmSettings[$key] -Type DWord -Force }
    Write-Host "[+] Lock screen ads and tips disabled." -ForegroundColor Green
}


# ---------------- SECTION 18: DARK MODE ----------------
function Enable-DarkMode {
    Write-Host "`n[*] Enabling dark mode..." -ForegroundColor Cyan
    $themePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if (-not (Test-Path $themePath)) { New-Item -Path $themePath -Force | Out-Null }
    Set-ItemProperty -Path $themePath -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $themePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force
    Write-Host "[+] Dark mode enabled." -ForegroundColor Green
}

# ---------------- SECTION 19: DISABLE CORTANA WEB SEARCH ----------------
function Disable-CortanaWebSearch {
    Write-Host "`n[*] Disabling web results in Start menu search..." -ForegroundColor Cyan
    $searchPolicyPath = "HKLM:\Software\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $searchPolicyPath)) { New-Item -Path $searchPolicyPath -Force | Out-Null }
    Set-ItemProperty -Path $searchPolicyPath -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force
    $windowsSearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    Set-ItemProperty -Path $windowsSearchPath -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $windowsSearchPath -Name "CortanaConsent" -Value 0 -Type DWord -Force
    Write-Host "[+] Web search results disabled in Start menu." -ForegroundColor Green
}

# ---------------- SECTION 20: PERFORMANCE VISUALS ----------------
function Set-PerformanceVisuals {
    Write-Host "`n[*] Applying performance-focused visual effects..." -ForegroundColor Cyan
    $vfxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (-not (Test-Path $vfxPath)) { New-Item -Path $vfxPath -Force | Out-Null }
    Set-ItemProperty -Path $vfxPath -Name "VisualFXSetting" -Value 3 -Type DWord -Force
    $desktopPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value 0 -Force
    Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value 0 -Force
    Write-Host "[+] Performance visual settings applied." -ForegroundColor Green
}


# ============================================================
# 👉 MASTER WINDOWS SETUP & CLEANUP SCRIPT
# 👉 Developed By @MRGARGSIR
# 👉 PART B: MASTER CHECKBOX MENU + EXECUTION ENGINE
# ============================================================

function Show-MasterMenu {

    # 👉 Task registry: Label shown in GUI -> function to call
    # 👉 "Checked" = pre-ticked by default (your core requested list), rest are optional extras (Part 5)
    $taskList = [ordered]@{
        "Remove Windows Bloatware (keep Calculator/Notepad/Paint/Photos/Store)" = @{ Fn = "Remove-WindowsBloat"; Checked = $true }
        "Disable Startup Items (AnyDesk, Bluestacks, Chrome, Spotify, etc.)"    = @{ Fn = "Disable-StartupItems"; Checked = $true }
        "Taskbar Tweaks (Left align, Search icon-only, Hide Task View, Widgets off)" = @{ Fn = "Set-TaskbarTweaks"; Checked = $true }
        "File Explorer Tweaks (This PC default, Show hidden items)"            = @{ Fn = "Set-ExplorerTweaks"; Checked = $true }
        "Uninstall Software (opens selection window)"                          = @{ Fn = "Show-InstalledSoftware"; Checked = $true }
        "Check for Multiple Antivirus (warning prompt)"                        = @{ Fn = "Test-MultipleAntivirus"; Checked = $true }
        "Disable Copilot"                                                      = @{ Fn = "Disable-Copilot"; Checked = $true }
        "Disable Unnecessary Scheduled Tasks"                                  = @{ Fn = "Disable-UnnecessaryScheduledTasks"; Checked = $true }
        "Disable Telemetry + Advertising ID"                                   = @{ Fn = "Disable-TelemetryAndAdvertising"; Checked = $true }
        "Enable Defender + Update Signatures"                                  = @{ Fn = "Enable-DefenderAndUpdate"; Checked = $true }
        "Check Windows Activation Status"                                      = @{ Fn = "Test-WindowsActivation"; Checked = $true }
        "Check MS Office Activation Status"                                    = @{ Fn = "Test-OfficeActivation"; Checked = $true }
        "Clean Temp Files + Windows Update Cache"                              = @{ Fn = "Clear-TempAndUpdateCache"; Checked = $true }
        "Update All Apps (Store + Winget + Windows Update)"                    = @{ Fn = "Update-AllApps"; Checked = $true }
        "-- OPTIONAL EXTRAS BELOW --"                                          = @{ Fn = $null; Checked = $false }   # 👉 separator row, not clickable
        "Enable Classic Right-Click Context Menu"                              = @{ Fn = "Enable-ClassicContextMenu"; Checked = $true }
        "Disable Lock Screen Ads / Tips"                                       = @{ Fn = "Disable-LockScreenAdsAndTips"; Checked = $true }
        "Enable Dark Mode"                                                     = @{ Fn = "Enable-DarkMode"; Checked = $false }
        "Disable Cortana Web Search Results in Start Menu"                     = @{ Fn = "Disable-CortanaWebSearch"; Checked = $false }
        "Performance-Focused Visual Effects"                                   = @{ Fn = "Set-PerformanceVisuals"; Checked = $false }
    }

    # 👉 ---- Build GUI ----
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "MRGARGSIR Windows Setup Utility - @MRGARGSIR"
    $form.Size = New-Object System.Drawing.Size(620, 650)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)
    $form.ForeColor = [System.Drawing.Color]::White

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Select tweaks to apply"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(10, 10)
    $title.AutoSize = $true
    $form.Controls.Add($title)

    $checkList = New-Object System.Windows.Forms.CheckedListBox
    $checkList.Location = New-Object System.Drawing.Point(10, 44)
    $checkList.Size = New-Object System.Drawing.Size(580, 470)
    $checkList.CheckOnClick = $true
    $checkList.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
    $checkList.ForeColor = [System.Drawing.Color]::White
    $checkList.BorderStyle = "FixedSingle"
    $checkList.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.Controls.Add($checkList)

    # 👉 Populate list, pre-check the core requested items, keep separator visible but skip during execution
    foreach ($label in $taskList.Keys) {
        $index = $checkList.Items.Add($label)
        if ($taskList[$label].Checked) { $checkList.SetItemChecked($index, $true) }
    }

    # 👉 Select All / Select None buttons
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Select All"
    $btnSelectAll.Location = New-Object System.Drawing.Point(10, 480)
    $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.Add_Click({
        for ($i = 0; $i -lt $checkList.Items.Count; $i++) {
            $label = $checkList.Items[$i]
            if ($taskList[$label].Fn) { $checkList.SetItemChecked($i, $true) }  # 👉 skip separator row
        }
    })
    $form.Controls.Add($btnSelectAll)

    $btnSelectNone = New-Object System.Windows.Forms.Button
    $btnSelectNone.Text = "Select None"
    $btnSelectNone.Location = New-Object System.Drawing.Point(140, 480)
    $btnSelectNone.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectNone.Add_Click({
        for ($i = 0; $i -lt $checkList.Items.Count; $i++) { $checkList.SetItemChecked($i, $false) }
    })
    $form.Controls.Add($btnSelectNone)

    # 👉 Run button
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Run Selected Tweaks"
    $btnRun.Location = New-Object System.Drawing.Point(390, 480)
    $btnRun.Size = New-Object System.Drawing.Size(200, 34)
    $btnRun.BackColor = [System.Drawing.Color]::FromArgb(60,140,60)
    $btnRun.ForeColor = [System.Drawing.Color]::White
    $btnRun.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnRun)
    $form.AcceptButton = $btnRun

    # 👉 Cancel button
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(390, 520)
    $btnCancel.Size = New-Object System.Drawing.Size(200, 30)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel)
    $form.CancelButton = $btnCancel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Cancelled by user. No changes made." -ForegroundColor DarkGray
        return
    }

    $checkedLabels = $checkList.CheckedItems | ForEach-Object { $_.ToString() }
    if ($checkedLabels.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No tweaks selected.", "Info") | Out-Null
        return
    }

    # 👉 ---- Execute selected functions in defined order ----
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host " Running $($checkedLabels.Count) selected tweak(s)..." -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    $needsExplorerRestart = $false

    foreach ($label in $taskList.Keys) {
        if ($checkedLabels -contains $label -and $taskList[$label].Fn) {
            $fnName = $taskList[$label].Fn
            try {
                & $fnName   # 👉 dynamically invoke the mapped function
            } catch {
                Write-Host "  ERROR running $fnName : $($_.Exception.Message)" -ForegroundColor Red
            }

            # 👉 Track if any taskbar/explorer/context-menu tweak ran, so we restart Explorer once at the end
            if ($fnName -in @("Set-TaskbarTweaks","Set-ExplorerTweaks","Enable-ClassicContextMenu","Enable-DarkMode")) {
                $needsExplorerRestart = $true
            }
        }
    }

    if ($needsExplorerRestart) {
        Restart-Explorer
    }

    Write-Host "`n============================================" -ForegroundColor Green
    Write-Host " All selected tweaks completed." -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green

    [System.Windows.Forms.MessageBox]::Show("All selected tweaks completed. Check the console window for full details.", "Done") | Out-Null
}

# ============================================================
# 👉 ENTRY POINT - launches the menu when script is run
# ============================================================
Show-MasterMenu
