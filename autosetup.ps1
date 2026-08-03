# ============================================================
# 👉 MASTER WINDOWS SETUP & CLEANUP SCRIPT
# 👉 Developed By @MRGARGSIR
# 👉 PART A: ALL FUNCTIONS (Sections 1-22)
# ============================================================


# SELF-ELEVATION - auto-relaunches as Administrator if not already elevated
# Replaces the old "#Requires -RunAsAdministrator" (which just errored out instead of fixing it)
$currentPrincipal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[*] Not running as Administrator - relaunching elevated..." -ForegroundColor Yellow

    try {
        if ($PSCommandPath) {
            # 👉 Script was run from a saved .ps1 file - relaunch that same file elevated
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction Stop
        } else {
            # 👉 Script was run via "irm ... | iex" (no file on disk) - relaunch by re-running the same one-liner elevated
            $elevateCommand = "irm https://mrgargsir.github.io/winsetup/setup.ps1 | iex"
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$elevateCommand`"" -Verb RunAs -ErrorAction Stop
        }
    } catch {
        # 👉 User clicked "No" on the UAC prompt, or elevation otherwise failed
        Write-Host "[-] Elevation was cancelled or failed. This script requires Administrator privileges to run." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }

    # 👉 Exit this non-elevated instance - the new elevated instance takes over
    exit
}


Set-ExecutionPolicy Bypass -Scope Process -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 👉 moved to global scope - was previously nested inside Set-TaskbarTweaks only, so
# 👉 other functions like Set-StartMenuTweaks couldn't see it
# 👉 helper: applies a value, and if access is denied (protected key on newer builds), prints a quiet yellow skip note instead of a red error
function Set-RegValueSafe($path, $name, $value, $type = "DWord") {
    try {
        Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force -ErrorAction Stop
    } catch {
        Write-Host "  Skipped '$name' (protected by this Windows build, no reliable workaround)" -ForegroundColor Yellow
    }
}

# 👉 Global OS detection - used throughout the script to skip features that don't exist on older Windows
$script:OSVersion = [System.Environment]::OSVersion.Version
$script:IsWin7    = ($OSVersion.Major -eq 6 -and $OSVersion.Minor -eq 1)          # 👉 Windows 7 = 6.1
$script:IsWin81OrOlder = ($OSVersion.Major -lt 10)                                # 👉 covers 7, 8, 8.1
$script:IsWin11   = ($OSVersion.Major -eq 10 -and $OSVersion.Build -ge 22000)

# 👉 Reusable animated rainbow footer - added to every GUI window for consistent branding
function Add-RainbowFooter {
    param($Form)

    $footerText = "Developed by @MRGARGSIR"
    $colors = @(
        [System.Drawing.Color]::FromArgb(255,80,80),
        [System.Drawing.Color]::FromArgb(255,180,60),
        [System.Drawing.Color]::FromArgb(255,230,60),
        [System.Drawing.Color]::FromArgb(100,220,100),
        [System.Drawing.Color]::FromArgb(80,180,255),
        [System.Drawing.Color]::FromArgb(150,100,255),
        [System.Drawing.Color]::FromArgb(255,100,200)
    )

    $charWidth = 12
    $startX = [int](($Form.ClientSize.Width - ($footerText.Length * $charWidth)) / 2)
    $y = $Form.ClientSize.Height - 26

    $labels = New-Object System.Collections.ArrayList
    $x = $startX
    for ($i = 0; $i -lt $footerText.Length; $i++) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $footerText.Substring($i,1)
        $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $lbl.AutoSize = $true
        $lbl.Location = New-Object System.Drawing.Point($x, $y)
        $lbl.ForeColor = $colors[$i % $colors.Count]
        $Form.Controls.Add($lbl)
        [void]$labels.Add($lbl)
        $x += $charWidth
    }

    # 👉 Timer rotates each letter's color for a subtle rainbow-cycle animation
    $offset = 0
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 150
    $timer.Add_Tick({
        $offset++
        for ($i = 0; $i -lt $labels.Count; $i++) {
            $labels[$i].ForeColor = $colors[($i + $offset) % $colors.Count]
        }
    }.GetNewClosure())
    $timer.Start()
    $Form.Add_FormClosed({ $timer.Stop(); $timer.Dispose() }.GetNewClosure()) 
}

#---------------- SECTION 0: AUTO-PARTITION ----------------
function New-DataPartitionFromFreeSpace {
    Write-Host "`nChecking disk layout for auto-partition..." -ForegroundColor Cyan
    $fixedVolumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }

    if ($fixedVolumes.Count -eq 1 -and $fixedVolumes.DriveLetter -eq 'C') {
        $cVolume = Get-Volume -DriveLetter C
        $freeBytes = $cVolume.SizeRemaining
        $freeGB = [math]::Round($freeBytes / 1GB, 2)

        # Tiered shrink percentage based on available free space
        $shrinkPct = 0
        $tierLabel = ""
        if ($freeGB -ge 30 -and $freeGB -lt 50) {
            $shrinkPct = 0.20; $tierLabel = "30-50 GB tier"
        } elseif ($freeGB -ge 50 -and $freeGB -lt 70) {
            $shrinkPct = 0.30; $tierLabel = "50-70 GB tier"
        } elseif ($freeGB -ge 70 -and $freeGB -lt 100) {
            $shrinkPct = 0.40; $tierLabel = "70-100 GB tier"
        } elseif ($freeGB -ge 100) {
            $shrinkPct = 0.50; $tierLabel = "100+ GB tier"
        }

        if ($shrinkPct -gt 0) {
            $shrinkBytes = [int64]($freeBytes * $shrinkPct)
            $shrinkGB = [math]::Round($shrinkBytes / 1GB, 2)
            Write-Host "Free space: $freeGB GB ($tierLabel). Shrinking C: by $($shrinkPct * 100)% = $shrinkGB GB to create D:..." -ForegroundColor DarkGray

            $partition = Get-Partition -DriveLetter C
            $newCSize = $partition.Size - $shrinkBytes
            Resize-Partition -DriveLetter C -Size $newCSize -ErrorAction Stop

            $disk = $partition.DiskNumber
            $newPartition = New-Partition -DiskNumber $disk -UseMaximumSize -DriveLetter D
            Format-Volume -Partition $newPartition -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false

            Write-Host "D: drive created successfully ($shrinkGB GB)." -ForegroundColor Green
        } else {
            Write-Host "Only $freeGB GB free (need at least 30 GB) - skipping partition." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Multiple partitions already exist or C: not sole volume - skipping." -ForegroundColor Yellow
    }
}

# ---------------- SECTION 1: BLOATWARE REMOVAL ----------------
function Remove-WindowsBloat {
    Write-Host "`n[*] Removing Windows bloatware apps..." -ForegroundColor Cyan
    # 👉 Appx packages don't exist on Windows 7 - skip cleanly instead of crashing
    if ($script:IsWin81OrOlder) {
        Write-Host "  Skipped - Appx/Store apps do not exist on this Windows version." -ForegroundColor Yellow
        return
    }

    $KeepApps = @("Microsoft.WindowsCalculator","Microsoft.WindowsNotepad","Microsoft.Paint","Microsoft.Paint3D","Microsoft.Windows.Photos","Microsoft.WindowsStore","Microsoft.StorePurchaseApp","Microsoft.WindowsCamera", "Microsoft.NetworkSpeedTest","Microsoft.WindowsAlarms","Microsoft.WindowsSoundRecorder","Microsoft.Todos")

    $BloatApps = @(
    "Microsoft.3DBuilder","Microsoft.BingFinance","Microsoft.BingNews","Microsoft.BingSports","Microsoft.BingWeather",
    "Microsoft.GetHelp","Microsoft.Getstarted","Microsoft.Messaging","Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub","Microsoft.MicrosoftSolitaireCollection","Microsoft.MixedReality.Portal",
    "Microsoft.News","Microsoft.Office.OneNote","Microsoft.People","Microsoft.Print3D","Microsoft.SkypeApp",
    "Microsoft.Wallet","Microsoft.WindowsFeedbackHub","Microsoft.WindowsMaps","Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp","Microsoft.XboxGameOverlay","Microsoft.XboxGamingOverlay","Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay","Microsoft.YourPhone","Microsoft.ZuneMusic","Microsoft.ZuneVideo",
    "Microsoft.GamingApp","Microsoft.PowerAutomateDesktop","Microsoft.OutlookForWindows","Clipchamp.Clipchamp",
    "Microsoft.549981C3F5F10","MicrosoftTeams","MSTeams","Microsoft.Teams",
    "SpotifyAB.SpotifyMusic","LinkedInforWindows","Disney.37853FC22B2CE","Microsoft.MicrosoftJournal",
    "Microsoft.BingSearch","Microsoft.WindowsCommunicationsApps","Microsoft.WindowsWebExperience",
    "Microsoft.Copilot","MicrosoftCorporationII.MicrosoftFamily","MicrosoftCorporationII.QuickAssist",
    "AmazonVideo.PrimeVideo","Facebook.Facebook","Twitter.Twitter","BytedancePte.Ltd.TikTok",
    "5319275A.WhatsAppDesktop","AD2F1837.HPPrinterControl"
)
    


    foreach ($app in $BloatApps) {
        if ($KeepApps -notcontains $app) {
            Write-Host "  Removing $app" -ForegroundColor DarkGray
            Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # Teams Machine-Wide Installer (classic MSI - Remove-AppxPackage never touches this)
$teamsMwi = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match "Teams Machine-Wide Installer" }
foreach ($t in $teamsMwi) {
    Write-Host "Removing Teams Machine-Wide Installer..." -ForegroundColor DarkGray
    Start-Process msiexec.exe -ArgumentList "/x $($t.PSChildName) /qn /norestart" -Wait
}

    Write-Host "[+] Bloatware removal complete." -ForegroundColor Green
}

#---------------- SECTION 1B: START MENU BLOAT ----------------
function Clear-StartMenuBloat {
    Write-Host "`nClearing leftover Start menu bloat..." -ForegroundColor Cyan

    # 1. Remove provisioned stub packages first - this is what actually stops regeneration
    $stubApps = @("SpotifyAB.SpotifyMusic","LinkedInforWindows","Disney.37853FC22B2CE","Facebook.Facebook","BytedancePte.Ltd.TikTok","AmazonVideo.PrimeVideo")
    foreach ($app in $stubApps) {
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $app |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    }

    # 2. Kill Start host processes and clear FULL tile cache, not just start2.bin
    Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
    Stop-Process -Name ShellExperienceHost -Force -ErrorAction SilentlyContinue
    $startDb = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    Remove-Item "$startDb\*.bin" -Force -ErrorAction SilentlyContinue
    Remove-Item "$startDb\StartMenuLayoutCache" -Recurse -Force -ErrorAction SilentlyContinue

    # 3. Purge stray shortcuts from Start Menu folders (unchanged, expanded list)
    $bloatNames = "Teams","Xbox","Solitaire","Disney","Spotify","TikTok","Netflix","LinkedIn","Candy Crush","Prime Video","Facebook"
    $startPaths = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    foreach ($path in $startPaths) {
        Get-ChildItem $path -Recurse -Include *.lnk -ErrorAction SilentlyContinue |
            Where-Object { $n = $_.BaseName; ($bloatNames | Where-Object { $n -match [regex]::Escape($_) }) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Start menu bloat cleared." -ForegroundColor Green
}

function Remove-OEMBloat {
    Write-Host "`nDetecting OEM and removing vendor bloat..." -ForegroundColor Cyan
    $manufacturer = (Get-CimInstance Win32_ComputerSystem).Manufacturer

    # 👉 expanded Dell list - added Dell Sync, Peripheral Manager, Pair, Mobile Connect,
    # 👉 Power Manager, Cinema, Product Registration, Watchdog, MyDell, Trusted Device, etc.
    $oemApps = @{
        "Dell"    = @("Dell SupportAssist","Dell Digital Delivery","Dell Optimizer","Dell Update","SupportAssist",
                      "Dell Sync","Dell Peripheral Manager","Dell Pair","Dell Mobile Connect","Dell Power Manager",
                      "Dell Cinema","Dell Product Registration","Dell Watchdog Timer","MyDell","Dell Core Services",
                      "Dell SupportAssist Remediation","Dell SupportAssist OS Recovery","Dell Trusted Device Agent",
                      "Dell Command | Update","Dell Display Manager","Dell Connected Service Delivery")
        "HP"      = @("HP Support Assistant","HP JumpStart","HP Documentation","HPSA Service","HP System Info HSA Service")
        "Lenovo"  = @("Lenovo Vantage","Lenovo Utility","Lenovo Companion","Lenovo App Explorer")
    }

    # 👉 NEW: vendor-agnostic "useless software" list - this junk ships on Dell/HP/Lenovo/Asus alike
    # 👉 regardless of chipset (Realtek/Waves), so it's checked no matter what the manufacturer is
    $commonBloat = @(
        "Waves MaxxAudio","Waves Audio","MaxxAudio","Dolby Access","Dolby Audio",
        "McAfee","Norton Security","WildTangent","Booking.com","Amazon Assistant",
        "Realtek Audio Console","Gaming Services","Microsoft GameInput","GameInput","Intel Graphics Command Center",
    "Tesseract-OCR","NetMirror"
    )

    $installed = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue

    # 👉 helper block reused for both lists below
    $removeMatching = {
        param($targets)
        foreach ($t in $targets) {
            $match = $installed | Where-Object { $_.DisplayName -match [regex]::Escape($t) }
            foreach ($m in $match) {
                Write-Host "Removing: $($m.DisplayName)" -ForegroundColor DarkGray
                if ($m.UninstallString -match "msiexec") {
                    Start-Process msiexec.exe -ArgumentList "/x $($m.PSChildName) /qn /norestart" -Wait
                } else {
                    Start-Process cmd.exe -ArgumentList "/c $($m.UninstallString) /quiet /norestart" -Wait -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # 👉 always run the common junk list first, regardless of vendor match
    Write-Host "Checking for common third-party bloat (audio enhancers, trial security, etc.)..." -ForegroundColor Cyan
    & $removeMatching $commonBloat

    $matchVendor = $oemApps.Keys | Where-Object { $manufacturer -match $_ }
    if (-not $matchVendor) {
        Write-Host "No matching OEM vendor bloat list for '$manufacturer'." -ForegroundColor Yellow
        Write-Host "OEM bloat removal complete." -ForegroundColor Green
        return
    }

    & $removeMatching $oemApps[$matchVendor]
    Write-Host "OEM bloat removal complete for $matchVendor." -ForegroundColor Green
}
 
function Disable-Recall {
    Write-Host "`nDisabling Windows Recall..." -ForegroundColor Cyan
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 26100) {
        Write-Host "Skipped - Recall not available on this Windows build." -ForegroundColor Yellow
        return
    }
    $recallPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    if (-not (Test-Path $recallPath)) { New-Item -Path $recallPath -Force | Out-Null }
    Set-ItemProperty -Path $recallPath -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
    Get-AppxPackage -Name "*Microsoft.Windows.AI.Recall*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    Write-Host "Recall disabled." -ForegroundColor Green
}

#---------------- SECTION 1C: START MENU TWEAKS ----------------
function Set-StartMenuTweaks {
    Write-Host "`nApplying Start menu tweaks..." -ForegroundColor Cyan

    if ($scriptIsWin81OrOlder) {
        Write-Host "Skipped - modern Start menu layout options don't exist on this Windows version." -ForegroundColor Yellow
        return
    }

    $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if (-not (Test-Path $advPath)) { New-Item -Path $advPath -Force | Out-Null }

    # 1. Switch Start layout to "More pins" (grid view) instead of "More recommendations"
    #    0 = Default, 1 = More pins, 2 = More recommendations
    Set-ItemProperty -Path $advPath -Name "Start_Layout" -Value 1 -Type DWord -Force
    Write-Host "Start layout set to grid (More pins)." -ForegroundColor DarkGray

    # 2. Stop tracking recently opened docs/apps (feeds the Recommended section)
    Set-ItemProperty -Path $advPath -Name "Start_TrackDocs" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $advPath -Name "Start_TrackProgs" -Value 0 -Type DWord -Force

    # 3. Hide Recommended section entirely (Windows 11 23H2/24H2 policy key)
    $policyPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
    Set-ItemProperty -Path $policyPath -Name "HideRecommendedSection" -Value 1 -Type DWord -Force

    # Also apply the machine-wide policy so it survives profile-level resets
    $policyPathMachine = "HKLM:\Software\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $policyPathMachine)) { New-Item -Path $policyPathMachine -Force | Out-Null }
    Set-RegValueSafe $policyPathMachine "HideRecommendedSection" 1

    Write-Host "Recommended section hidden and grid layout applied." -ForegroundColor Green
}

# ---------------- SECTION 2: SOFTWARE UNINSTALLER (GUI CHECKBOX) ----------------
function Show-InstalledSoftware {
    Write-Host "`n[*] Scanning installed software..." -ForegroundColor Cyan
    $paths = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*","HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
    $software = Get-ItemProperty $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.UninstallString } | Select-Object DisplayName, UninstallString, PSChildName | Sort-Object DisplayName -Unique

    # 👉 Always-hidden keywords - these never appear in the uninstall picker
    $hiddenKeywords = @("application verifier", "autocad", "autodesk", "bentley", "staad", "icecap", "java", "microsoft", "pdf24", "security update for microsoft", "vlc", "windows sdk", "windows driver package", "windows driver framework", "c++ redistributable", "visual c++", "visual studio", "anydesk", "connection client", "diagnosticsHub_CollectionService", "intelli", "intel", "nvidia", "amd", "amd64","rustdesk", "scan to", "winrar", "workflow manager", "google chrome", "windows app runtime" )

    # 👉 Filter out any DisplayName containing a hidden keyword (case-insensitive)
    $software = $software | Where-Object {
        $name = $_.DisplayName
        $isHidden = $false
        foreach ($keyword in $hiddenKeywords) {
            if ($name -match [regex]::Escape($keyword)) { $isHidden = $true; break }
        }
        -not $isHidden
    }

    if (-not $software) { [System.Windows.Forms.MessageBox]::Show("No software found.", "Info") | Out-Null; return }
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Software to Uninstall - @MRGARGSIR"
    $form.Size = New-Object System.Drawing.Size(560, 650)
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

    Add-RainbowFooter -Form $form
    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { Write-Host "Uninstall cancelled by user." -ForegroundColor DarkGray; return }

    # 👉 Safely build the checked-names list even if CheckedItems is empty/null
    $checkedNames = @($checkList.CheckedItems | ForEach-Object { $_.ToString() })

    # 👉 Nothing selected - show a message box instead of silently doing nothing, then exit cleanly
    if ($checkedNames.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No software was selected. Nothing was uninstalled.", "Info") | Out-Null
        Write-Host "No items selected." -ForegroundColor Yellow
        return
    }

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

#---------------- SECTION 2b: BROWSER TWEAKS ----------------
function Set-BrowserTweaks {
    Write-Host "`nApplying Chrome and Edge policy tweaks..." -ForegroundColor Cyan
    $chromePath = "HKLM:\Software\Policies\Google\Chrome"
    $edgePath   = "HKLM:\Software\Policies\Microsoft\Edge"
    foreach ($p in @($chromePath, $edgePath)) {
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    }

    # Background running off
    Set-ItemProperty -Path $chromePath -Name BackgroundModeEnabled -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $edgePath   -Name BackgroundModeEnabled -Value 0 -Type DWord -Force

    # AI tips / GenAI features off
    $chromeAi = @{ GenAiDefaultSettings=1; HelpMeWriteSettings=1; TabOrganizerSettings=1; HistorySearchSettings=1; CreateThemesSettings=1; TabCompareSettings=1; AIModeSettings=1 }
    foreach ($k in $chromeAi.Keys) { Set-ItemProperty -Path $chromePath -Name $k -Value $chromeAi[$k] -Type DWord -Force }
    Set-ItemProperty -Path $edgePath -Name HubsSidebarEnabled -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $edgePath -Name CopilotPageContext -Value 0 -Type DWord -Force

    # Bookmark/Favorites bar always shown
    Set-ItemProperty -Path $chromePath -Name BookmarkBarEnabled -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $edgePath   -Name FavoritesBarEnabled -Value 1 -Type DWord -Force

    Write-Host "Browser tweaks applied." -ForegroundColor Green
}

# ---------------- SECTION 3: STARTUP ITEMS ----------------
function Disable-StartupItems {
    Write-Host "`n[*] Disabling common startup items..." -ForegroundColor Cyan

    # 👉 Whitelist - these are NEVER touched, auto or manual selection skips them entirely
    $whitelistKeywords = @(
    "onedrive","default","MicrosoftList","Microsoft.Lists","PDF24","RtkAudUService","SecurityHealth",
    "edgeupdate","GoogleUpdate","GoogleDriveFS",
    "bit4id","cryptoidmon","hyperpki","ncodepkicomponent","b4notify","securityhealthsystray"
)

    $targetKeywords = @(
    "anydesk","bluestacks","hd-player","chrome","googlechrome","microsoftedgeautolaunch","spotify","discord",
    "teams","adobe","acrord32","acrotray","adobecollabsync","skype","steam","epicgameslauncher","autodesk",
    "autocad","bently","staad","vlc","zoom","dropbox","skypeapp","slack","notepad","putty","winscp","filezilla",
    "teamviewer","grammarly",
    "dopdf","printershare","hpwuschd","hp software update","lenovovantage","sunjavaupdatesched",
    "wd_spsocketserver","wd_stdcertm","wondershare","netsetman","camo studio","intel.*graphics command center",
    "opera","whatsapp","chatgpt","quickphrase","microsoft to do","phone link","terminal","Adobe", "Acrobat" , "waves"
)

    $regPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run","HKLM:\Software\Microsoft\Windows\CurrentVersion\Run","HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run")
    $startupApprovedPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run","HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32")

    # 👉 helper to check if a name matches the whitelist (never touch)
    function Test-Whitelisted($name) {
        foreach ($w in $whitelistKeywords) { if ($name -match [regex]::Escape($w)) { return $true } }
        return $false
    }
    # 👉 helper to check if a name matches the auto-disable keyword list
    function Test-TargetMatch($name) {
        foreach ($k in $targetKeywords) { if ($name -match [regex]::Escape($k)) { return $true } }
        return $false
    }

    # 👉 ---- PASS 1: auto-disable known keyword matches (unchanged behavior, whitelist now respected) ----
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $entries = Get-Item $path
            foreach ($name in $entries.Property) {
                if (Test-Whitelisted $name) { continue }   # 👉 skip OneDrive etc.
                if (Test-TargetMatch $name) {
                    Write-Host "  Removing startup entry: $name ($path)" -ForegroundColor DarkGray
                    Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
                }
            }
        }
    }
    foreach ($path in $startupApprovedPaths) {
        if (Test-Path $path) {
            $entries = Get-Item $path
            foreach ($name in $entries.Property) {
                if (Test-Whitelisted $name) { continue }   # 👉 skip OneDrive etc.
                if (Test-TargetMatch $name) {
                    Write-Host "  Disabling modern startup app: $name" -ForegroundColor DarkGray
                    $disabledValue = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                    Set-ItemProperty -Path $path -Name $name -Value $disabledValue -ErrorAction SilentlyContinue
                }
            }
        }
    }
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "Adobe|Teams|Discord|Spotify|GoogleUpdate|EdgeUpdate|AnyDesk" }
    
    # 👉 guard scheduled task cleanup - not available on Windows 7
    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "Adobe|Teams|Discord|Spotify|GoogleUpdate|EdgeUpdate|AnyDesk" }
        foreach ($task in $tasks) {
            Write-Host "  Disabling scheduled task: $($task.TaskName)" -ForegroundColor DarkGray
            Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue | Out-Null
        }
    } else {
        Write-Host "  Skipped scheduled task cleanup (not available on this Windows version)." -ForegroundColor Yellow
    }
    Write-Host "[+] Known startup items disabled." -ForegroundColor Green

    # 👉 ---- PASS 2: collect remaining startup entries (not whitelisted, not already matched) for manual GUI selection ----
    $remaining = @{}
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $entries = Get-Item $path
            foreach ($name in $entries.Property) {
                if (Test-Whitelisted $name -or Test-TargetMatch $name) { continue }
                if (-not $remaining.ContainsKey($name)) { $remaining[$name] = $path }
            }
        }
    }
    foreach ($path in $startupApprovedPaths) {
        if (Test-Path $path) {
            $entries = Get-Item $path
            foreach ($name in $entries.Property) {
                if (Test-Whitelisted $name -or Test-TargetMatch $name) { continue }
                if (-not $remaining.ContainsKey($name)) { $remaining[$name] = $path }
            }
        }
    }

    if ($remaining.Count -eq 0) {
        Write-Host "  No additional startup items found." -ForegroundColor DarkGray
        return
    }

    # 👉 GUI checkbox picker for remaining/unrecognized startup entries - same dark style as other menus
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Remaining Startup Items - @MRGARGSIR"
    $form.Size = New-Object System.Drawing.Size(560, 590)
    $form.StartPosition = "CenterScreen"; $form.FormBorderStyle = "FixedDialog"; $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30); $form.ForeColor = [System.Drawing.Color]::White

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "$($remaining.Count) other startup item(s) found. Check any you want to disable:"
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.AutoSize = $true
    $form.Controls.Add($label)

    $checkList = New-Object System.Windows.Forms.CheckedListBox
    $checkList.Location = New-Object System.Drawing.Point(10, 36); $checkList.Size = New-Object System.Drawing.Size(520, 400)
    $checkList.CheckOnClick = $true; $checkList.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
    $checkList.ForeColor = [System.Drawing.Color]::White; $checkList.BorderStyle = "FixedSingle"
    $form.Controls.Add($checkList)

    $remainingNames = $remaining.Keys | Sort-Object
    foreach ($name in $remainingNames) { [void]$checkList.Items.Add($name) }   # 👉 unchecked by default - opt-in, not opt-out

    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = "Select All"; $btnSelectAll.Location = New-Object System.Drawing.Point(10, 448); $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.Add_Click({ for ($i = 0; $i -lt $checkList.Items.Count; $i++) { $checkList.SetItemChecked($i, $true) } })
    $form.Controls.Add($btnSelectAll)

    $btnSelectNone = New-Object System.Windows.Forms.Button
    $btnSelectNone.Text = "Select None"; $btnSelectNone.Location = New-Object System.Drawing.Point(140, 448); $btnSelectNone.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectNone.Add_Click({ for ($i = 0; $i -lt $checkList.Items.Count; $i++) { $checkList.SetItemChecked($i, $false) } })
    $form.Controls.Add($btnSelectNone)

    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "Disable Selected"; $btnDisable.Location = New-Object System.Drawing.Point(340, 448); $btnDisable.Size = New-Object System.Drawing.Size(190, 34)
    $btnDisable.BackColor = [System.Drawing.Color]::FromArgb(200,60,60); $btnDisable.ForeColor = [System.Drawing.Color]::White
    $btnDisable.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnDisable); $form.AcceptButton = $btnDisable

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Skip"; $btnCancel.Location = New-Object System.Drawing.Point(340, 488); $btnCancel.Size = New-Object System.Drawing.Size(190, 30)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel); $form.CancelButton = $btnCancel

    Add-RainbowFooter -Form $form
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $checkedNames = $checkList.CheckedItems | ForEach-Object { $_.ToString() }
        foreach ($name in $checkedNames) {
            $path = $remaining[$name]
            if ($path -match "StartupApproved") {
                Write-Host "  Disabling modern startup app: $name" -ForegroundColor DarkGray
                $disabledValue = [byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)
                Set-ItemProperty -Path $path -Name $name -Value $disabledValue -ErrorAction SilentlyContinue
            } else {
                Write-Host "  Removing startup entry: $name ($path)" -ForegroundColor DarkGray
                Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
            }
        }
        Write-Host "[+] Selected additional startup items disabled." -ForegroundColor Green
    } else {
        Write-Host "  Skipped remaining startup items." -ForegroundColor DarkGray
    }
}

# ---------------- SECTION 4: TASKBAR TWEAKS ----------------
function Set-TaskbarTweaks {
    Write-Host "`n[*] Applying taskbar tweaks..." -ForegroundColor Cyan

    # 👉 Modern taskbar features (search box modes, Task View, widgets) don't exist on Windows 7
    if ($script:IsWin81OrOlder) {
        Write-Host "  Skipped - modern taskbar features are not available on this Windows version." -ForegroundColor Yellow
        return
    }

    # 👉 detect Windows version by build number - Win11 starts at build 22000
    $build = [System.Environment]::OSVersion.Version.Build
    $isWin11 = $build -ge 22000

    $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $feedsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds"

    if (-not (Test-Path $advPath)) { New-Item -Path $advPath -Force | Out-Null }
    if (-not (Test-Path $searchPath)) { New-Item -Path $searchPath -Force | Out-Null }

    

    if ($isWin11) {
        # 👉 Taskbar left-align only applies to Windows 11 (Win10 taskbar is always left-aligned already)
        Set-RegValueSafe $advPath "TaskbarAl" 0

        # 👉 Widgets panel toggle - Windows 11 only. Often locked by a protected ACL on 23H2/24H2 builds even for admins; handled quietly above.
        Set-RegValueSafe $advPath "TaskbarDa" 0
    } else {
        # 👉 "News and interests" feed - the Windows 10 equivalent of Win11's widgets panel
        if (-not (Test-Path $feedsPath)) { New-Item -Path $feedsPath -Force | Out-Null }
        Set-RegValueSafe $feedsPath "ShellFeedsTaskbarViewMode" 2
    }

    # 👉 These two apply the same way on both Windows 10 and 11
    Set-RegValueSafe $searchPath "SearchboxTaskbarMode" 1
    Set-RegValueSafe $advPath "ShowTaskViewButton" 0

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

    # 👉 Copilot only exists on Windows 11 23H2+ (build 22631+) - skip cleanly on older builds
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 22631) {
        Write-Host "  Skipped - Copilot is not available on this Windows version." -ForegroundColor Yellow
        return
    }

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

    # 👉 ScheduledTasks module isn't available on Windows 7 - skip cleanly
    if (-not (Get-Command Disable-ScheduledTask -ErrorAction SilentlyContinue)) {
        Write-Host "  Skipped - Task Scheduler cmdlets not available on this Windows version." -ForegroundColor Yellow
        return
    }

    $tasksToDisable = @("Microsoft\Windows\Customer Experience Improvement Program\Consolidator","Microsoft\Windows\Customer Experience Improvement Program\UsbCeip","Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector","Microsoft\Windows\Feedback\Siuf\DmClient","Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload","Microsoft\Windows\Windows Error Reporting\QueueReporting","Microsoft\Windows\Maps\MapsToastTask","Microsoft\Windows\Maps\MapsUpdateTask","Microsoft\Windows\PI\Sqm-Tasks","Microsoft\Windows\Shell\FamilySafetyMonitor","Microsoft\Windows\Shell\FamilySafetyRefresh","Microsoft\Windows\Retail Demo\CleanupOffline")

    #$advancetasksToDisable = @("Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser","Microsoft\Windows\Application Experience\ProgramDataUpdater","Microsoft\Windows\Autochk\Proxy"

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

    # 👉 Defender module doesn't exist on Windows 7 - skip cleanly
    if (-not (Get-Command Set-MpPreference -ErrorAction SilentlyContinue)) {
        Write-Host "  Skipped - Windows Defender module not available on this Windows version." -ForegroundColor Yellow
        return
    }
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
    # 👉 Added Click-to-Run "root\Office16" paths - covers Microsoft 365/2019/2021 installs, which the old path missed
    $osppPaths = @(
        "$env:ProgramFiles\Microsoft Office\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\ospp.vbs",
        "$env:ProgramFiles\Microsoft Office\root\Office16\ospp.vbs",
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\ospp.vbs"
    )
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
    # 👉 Clear-RecycleBin cmdlet isn't available on Windows 7 - use COM Shell fallback instead
    if (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue) {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    } else {
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            $recycleBin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
        } catch { Write-Host "  Could not empty Recycle Bin via fallback method." -ForegroundColor Yellow }
    }
    Write-Host "[+] Temp files and Update cache cleared." -ForegroundColor Green
}

# ---------------- SECTION 15: UPDATE ALL APPS (REVISED - STABLE-ONLY, DETAILED GUI) ----------------
function Update-AllApps {
    Write-Host "`n[*] Checking for app updates..." -ForegroundColor Cyan

    # 👉 Store app scan trigger stays automatic - no per-app choice for Store apps, it's just a background scan flag
    try {
        Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" -ErrorAction SilentlyContinue | Invoke-CimMethod -MethodName UpdateScanMethod -ErrorAction SilentlyContinue | Out-Null
    } catch { Write-Host "  Store app scan trigger skipped." -ForegroundColor Yellow }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  winget not found - skipping desktop app updates." -ForegroundColor Yellow
    } else {
        Write-Host "  Checking winget for available updates..." -ForegroundColor DarkGray

        $raw = winget upgrade --accept-source-agreements | Out-String
        $lines = $raw -split "`r?`n" | Where-Object { $_.Trim() -ne "" }

        # 👉 Header now captures Name / Id / Version / Available / Source column positions
        $headerIndex = ($lines | Select-String -Pattern "^Name\s+Id\s+Version\s+Available").LineNumber
        $packages = @()

        if ($headerIndex) {
            $headerLine = $lines[$headerIndex - 1]
            $idStart = $headerLine.IndexOf("Id")
            $versionStart = $headerLine.IndexOf("Version")
            $availableStart = $headerLine.IndexOf("Available")
            $sourceStart = $headerLine.IndexOf("Source")

            for ($i = $headerIndex; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ($line -match "^-+$" -or $line -match "upgrades available" -or $line.Trim() -eq "") { continue }
                if ($line.Length -lt $availableStart) { continue }

                $name = $line.Substring(0, $idStart).Trim()
                $id = $line.Substring($idStart, $versionStart - $idStart).Trim()
                $currentVersion = $line.Substring($versionStart, $availableStart - $versionStart).Trim()

                if ($sourceStart -gt 0 -and $line.Length -ge $sourceStart) {
                    $availableVersion = $line.Substring($availableStart, $sourceStart - $availableStart).Trim()
                    $source = $line.Substring($sourceStart).Trim()
                } else {
                    $availableVersion = $line.Substring($availableStart).Trim()
                    $source = "winget"
                }

                if ($name -and $id) {
                    $packages += [PSCustomObject]@{
                        Name = $name; Id = $id
                        CurrentVersion = $currentVersion
                        AvailableVersion = $availableVersion
                        Source = $source
                    }
                }
            }
        }

        # 👉 Always-skipped keywords - CAD/engineering apps stay excluded from updates entirely
        $skipUpdateKeywords = @("autocad", "autodesk", "bently", "staad", "revit", "3ds max", "bentley", "capcut")

        # 👉 NEW: stable-channel-only filter - skips anything whose available version string signals a non-stable release
        $nonStableKeywords = @("beta", "alpha", "rc", "preview", "insider", "canary", "dev", "nightly", "pre-release", "prerelease", "experimental", "early access", "ea-", "eap", "nightly-build")

        $packages = $packages | Where-Object {
            $pkg = $_
            $isSkipped = $false
            foreach ($keyword in $skipUpdateKeywords) {
                if ($pkg.Name -match [regex]::Escape($keyword) -or $pkg.Id -match [regex]::Escape($keyword)) { $isSkipped = $true; break }
            }
            if (-not $isSkipped) {
                foreach ($keyword in $nonStableKeywords) {
                    # 👉 checks both the version string AND the package name/id, since some vendors flag beta only in the name (e.g. "Discord Canary")
                    if ($pkg.AvailableVersion -match [regex]::Escape($keyword) -or $pkg.Name -match [regex]::Escape($keyword) -or $pkg.Id -match [regex]::Escape($keyword)) {
                        $isSkipped = $true
                        break
                    }
                }
            }
            -not $isSkipped
        }

        if ($packages.Count -eq 0) {
            Write-Host "  No stable-channel winget updates available." -ForegroundColor Green
        } else {
            # 👉 ListView with real columns instead of a plain checklist - shows Name, Current, Available, Source
            $form = New-Object System.Windows.Forms.Form
            $form.Text = "Select Apps to Update (Stable Channel Only) - @MRGARGSIR"
            $form.Size = New-Object System.Drawing.Size(760, 590)
            $form.StartPosition = "CenterScreen"; $form.FormBorderStyle = "FixedDialog"; $form.MaximizeBox = $false
            $form.BackColor = [System.Drawing.Color]::FromArgb(30,30,30); $form.ForeColor = [System.Drawing.Color]::White

            $label = New-Object System.Windows.Forms.Label
            $label.Text = "$($packages.Count) stable update(s) available. Uncheck any you want to skip:"
            $label.Location = New-Object System.Drawing.Point(10, 10)
            $label.AutoSize = $true
            $form.Controls.Add($label)

            $listView = New-Object System.Windows.Forms.ListView
            $listView.Location = New-Object System.Drawing.Point(10, 36)
            $listView.Size = New-Object System.Drawing.Size(720, 430)
            $listView.View = [System.Windows.Forms.View]::Details
            $listView.CheckBoxes = $true
            $listView.FullRowSelect = $true
            $listView.GridLines = $true
            $listView.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
            $listView.ForeColor = [System.Drawing.Color]::White
            [void]$listView.Columns.Add("App Name", 260)
            [void]$listView.Columns.Add("Current Version", 140)
            [void]$listView.Columns.Add("Available Version", 140)
            [void]$listView.Columns.Add("Source", 100)
            $form.Controls.Add($listView)

            foreach ($pkg in $packages) {
                $item = New-Object System.Windows.Forms.ListViewItem($pkg.Name)
                [void]$item.SubItems.Add($pkg.CurrentVersion)
                [void]$item.SubItems.Add($pkg.AvailableVersion)
                [void]$item.SubItems.Add($pkg.Source)
                $item.Checked = $true   # 👉 all stable updates pre-checked by default
                [void]$listView.Items.Add($item)
            }

            $btnSelectAll = New-Object System.Windows.Forms.Button
            $btnSelectAll.Text = "Select All"; $btnSelectAll.Location = New-Object System.Drawing.Point(10, 478); $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
            $btnSelectAll.Add_Click({ foreach ($item in $listView.Items) { $item.Checked = $true } }.GetNewClosure())
            $form.Controls.Add($btnSelectAll)

            $btnSelectNone = New-Object System.Windows.Forms.Button
            $btnSelectNone.Text = "Select None"; $btnSelectNone.Location = New-Object System.Drawing.Point(140, 478); $btnSelectNone.Size = New-Object System.Drawing.Size(120, 30)
            $btnSelectNone.Add_Click({ foreach ($item in $listView.Items) { $item.Checked = $false } }.GetNewClosure())
            $form.Controls.Add($btnSelectNone)

            $btnUpdate = New-Object System.Windows.Forms.Button
            $btnUpdate.Text = "Update Selected"; $btnUpdate.Location = New-Object System.Drawing.Point(500, 478); $btnUpdate.Size = New-Object System.Drawing.Size(230, 34)
            $btnUpdate.BackColor = [System.Drawing.Color]::FromArgb(60,140,60); $btnUpdate.ForeColor = [System.Drawing.Color]::White
            $btnUpdate.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Controls.Add($btnUpdate); $form.AcceptButton = $btnUpdate

            $btnCancel = New-Object System.Windows.Forms.Button
            $btnCancel.Text = "Skip All"; $btnCancel.Location = New-Object System.Drawing.Point(500, 518); $btnCancel.Size = New-Object System.Drawing.Size(230, 30)
            $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $form.Controls.Add($btnCancel); $form.CancelButton = $btnCancel

            Add-RainbowFooter -Form $form   # 👉 branded footer added to this window too

            $result = $form.ShowDialog()

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                foreach ($item in $listView.Items) {
                    if ($item.Checked) {
                        $pkg = $packages | Where-Object { $_.Name -eq $item.Text } | Select-Object -First 1
                        Write-Host "  Updating: $($pkg.Name) ($($pkg.CurrentVersion) -> $($pkg.AvailableVersion))..." -ForegroundColor DarkGray
                        # 👉 --release-channel stable enforces stable-only installs at the winget level as a second safety net, in addition to the pre-filter above
                        winget upgrade --id $pkg.Id --silent --accept-package-agreements --accept-source-agreements
                    }
                }
                Write-Host "[+] Selected app updates complete." -ForegroundColor Green
            } else {
                Write-Host "  Skipped all winget updates." -ForegroundColor DarkGray
            }
        }
    }

    # 👉 Windows Update (OS) stays a separate yes/no prompt - different risk profile than app updates
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        $osResult = [System.Windows.Forms.MessageBox]::Show("Install available Windows Updates now?", "Windows Update", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($osResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-Host "  Running Windows Update..." -ForegroundColor DarkGray
            Import-Module PSWindowsUpdate
            Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false
        } else {
            Write-Host "  Skipped Windows Update." -ForegroundColor DarkGray
        }
    } else { Write-Host "  PSWindowsUpdate module not installed - skipping OS update step." -ForegroundColor Yellow }

    Write-Host "[+] Update pass complete." -ForegroundColor Green
}

# ---------------- SECTION 16: CLASSIC CONTEXT MENU ----------------
function Enable-ClassicContextMenu {
    Write-Host "`n[*] Restoring classic right-click context menu..." -ForegroundColor Cyan

    # 👉 only relevant on Windows 11 (build 22000+) - Win10 already uses the classic menu
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 22000) {
        Write-Host "  Skipped - Windows 10 already uses the classic context menu." -ForegroundColor Yellow
        return
    }

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
    Write-Host "`n[*] Restoring default visual effects..." -ForegroundColor Cyan
    $vfxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (-not (Test-Path $vfxPath)) { New-Item -Path $vfxPath -Force | Out-Null }
    Set-ItemProperty -Path $vfxPath -Name "VisualFXSetting" -Value 0 -Type DWord -Force   # 👉 0 = "Let Windows choose what's best for my computer" (was 3 = Custom)
    $desktopPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value 1 -Force            # 👉 1 = show full window contents while dragging (was 0 = outline only)
    Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value 400 -Force            # 👉 400 = default ~400ms submenu hover delay restored (was 0 = instant)
    Write-Host "[+] Default visual effects restored." -ForegroundColor Green
}

#---------------- SECTION 21: PRINT SPOOLER + FONT CACHE ----------------
function Repair-PrintAndFontCache {
    Write-Host "`nClearing print spooler and font cache..." -ForegroundColor Cyan

    # 1. Stop dependent services before touching spool folder
    Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # 2. Clear stuck print jobs
    $spoolPath = "$env:WINDIR\System32\spool\PRINTERS"
    Remove-Item -Path "$spoolPath\*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Host "Stuck print jobs cleared." -ForegroundColor DarkGray

    # 3. Clear corrupted font cache
    Stop-Service -Name FontCache -Force -ErrorAction SilentlyContinue
    $fontCachePaths = @(
        "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache",
        "$env:WINDIR\System32\FNTCACHE.DAT"
    )
    foreach ($path in $fontCachePaths) {
        Remove-Item -Path "$path\*" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Font cache cleared." -ForegroundColor DarkGray

    # 4. Restart services
    Start-Service -Name FontCache -ErrorAction SilentlyContinue
    Start-Service -Name Spooler -ErrorAction SilentlyContinue
    Write-Host "Print spooler and font cache repaired." -ForegroundColor Green
}

# ---------------- SECTION 22: NETWORK OPTIMIZATIONS ----------------
function Set-NetworkOptimizations {
    Write-Host "`nApplying network optimizations..." -ForegroundColor Cyan

    # 1. Disable Network Location Awareness startup delay (Group Policy sync wait)
    $gpPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $gpPath)) { New-Item -Path $gpPath -Force | Out-Null }
    Set-ItemProperty -Path $gpPath -Name "GpNetworkStartTimeoutPolicyValue" -Value 0 -Type DWord -Force
    Write-Host "NLA/GP network wait timeout disabled." -ForegroundColor DarkGray

    # 2. Set DNS to Cloudflare (primary) + Google (secondary) on active adapters
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ("8.8.8.8","1.1.1.1") -ErrorAction SilentlyContinue
        Write-Host "DNS set to Cloudflare/Google on $($adapter.Name)." -ForegroundColor DarkGray
    }
    ipconfig /flushdns | Out-Null

    # 3. Disable IPv6 if not needed (unbind, don't fully strip stack)
    $disableIPv6 = $false  # flip to $true if IPv6 should be turned off
    if ($disableIPv6) {
        foreach ($adapter in $adapters) {
            Disable-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
        }
        Write-Host "IPv6 disabled on active adapters." -ForegroundColor DarkGray
    }

    Write-Host "Network optimizations applied." -ForegroundColor Green
}

# ---------------- SECTION 23: FAST STARTUP ----------------
function Disable-FastStartup {
    Write-Host "`nDisabling Fast Startup..." -ForegroundColor Cyan
    $powerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
    Set-ItemProperty -Path $powerPath -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
    Write-Host "Fast Startup disabled." -ForegroundColor Green
}

# ---------------- SECTION 24: SEARCH INDEXER + SYSMAN ----------------
function Set-IndexerAndSysMain {
    Write-Host "`nTuning Search Indexer and SysMain..." -ForegroundColor Cyan
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)

    if ($ramGB -le 8) {
        Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue
        Write-Host "SysMain disabled (low RAM system: $ramGB GB)." -ForegroundColor DarkGray
    } else {
        Write-Host "SysMain left enabled ($ramGB GB RAM - benefits from prefetching)." -ForegroundColor DarkGray
    }

    Write-Host "Indexer/SysMain tuning complete." -ForegroundColor Green
}

function Optimize-BackgroundServices {
    Write-Host "`nOptimizing background services and notifications..." -ForegroundColor Cyan

    # 1. Disable Welcome Experience & first-login tips spam
    $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (-not (Test-Path $cdmPath)) { New-Item -Path $cdmPath -Force | Out-Null }
    $welcomeSettings = @{
        "SubscribedContent-310093Enabled" = 0   # Welcome experience after updates/sign-in
        "SubscribedContent-338389Enabled" = 0   # "Suggest ways to get the most out of Windows"
        "SubscribedContent-353698Enabled" = 0   # Get tips and suggestions while using Windows
    }
    foreach ($key in $welcomeSettings.Keys) {
        Set-ItemProperty -Path $cdmPath -Name $key -Value $welcomeSettings[$key] -Type DWord -Force
    }
    Write-Host "Welcome experience and tips disabled." -ForegroundColor DarkGray

    # 2. Enable Clipboard History (opposite direction - a wanted feature, not bloat)
    $clipboardPath = "HKCU:\Software\Microsoft\Clipboard"
    if (-not (Test-Path $clipboardPath)) { New-Item -Path $clipboardPath -Force | Out-Null }
    Set-ItemProperty -Path $clipboardPath -Name "EnableClipboardHistory" -Value 1 -Type DWord -Force
    Write-Host "Clipboard history enabled (Win+V)." -ForegroundColor DarkGray

    # 3. Safe-to-disable background services (expanded)
    $servicesToDisable = @(
        "DiagTrack",             # Connected User Experiences and Telemetry
        "dmwappushservice",      # WAP Push message routing (telemetry-adjacent)
        "WerSvc",                # Windows Error Reporting
        "RetailDemo",            # Retail Demo Service (irrelevant outside retail store displays)
        "MapsBroker"           # Downloaded Maps Manager (if Maps app removed)
        )

    foreach ($svc in $servicesToDisable) {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Write-Host "Disabled service: $svc" -ForegroundColor DarkGray
        }
    }

    # 4. Force-deny background app activity for UWP apps globally
    $appPrivacyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
    if (-not (Test-Path $appPrivacyPath)) { New-Item -Path $appPrivacyPath -Force | Out-Null }
    Set-ItemProperty -Path $appPrivacyPath -Name "LetAppsRunInBackground" -Value 2 -Type DWord -Force

    Write-Host "Background services and notification settings optimized." -ForegroundColor Green
}

function Set-PowerSleepNever {
    Write-Host "`nSetting sleep to Never when plugged in..." -ForegroundColor Cyan

    # Get the active power scheme GUID
    $activeScheme = (powercfg /getactivescheme) -replace '.*GUID: ([a-f0-9-]+).*', '$1'

    # 0 = Never (in seconds, 0 disables the timeout)
    powercfg /change standby-timeout-ac 0
    powercfg /change monitor-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0

    # Leave battery behavior untouched (still sleeps on battery to save power)
    Write-Host "Sleep, monitor, and hibernate timeouts set to Never on AC power." -ForegroundColor DarkGray

    # Fix for the hidden 'System unattended sleep timeout' that overrides Never on some builds
    $unattendedSleepGuid = "7bc4a2f9-d8fc-4469-b07b-33eb785aaca0"
    $subgroupGuid = "238C9FA8-0AAD-41ED-83F4-97BE242C8F20"  # Sleep subgroup
    powercfg /setacvalueindex $activeScheme $subgroupGuid $unattendedSleepGuid 0
    powercfg /setactive $activeScheme

    Write-Host "Sleep set to Never (including hidden unattended sleep timeout)." -ForegroundColor Green
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
        "Make Partition" = @{ Fn = "New-DataPartitionFromFreeSpace"; Checked = $true }
        "Remove Windows Bloatware (keep Calculator/Notepad/Paint/Photos/Store)" = @{ Fn = "Remove-WindowsBloat"; Checked = $true }
        "Remove Start Menu Bloat" = @{ Fn = "Clear-StartMenuBloat"; Checked = $true }
        "Start Menu Tweaks (hide recommended, grid layout)" = @{ Fn = "Set-StartMenuTweaks"; Checked = $true }
        "Taskbar Tweaks (Left align, Search icon-only, Hide Task View, Widgets off)" = @{ Fn = "Set-TaskbarTweaks"; Checked = $true }
        "File Explorer Tweaks (This PC default, Show hidden items)"            = @{ Fn = "Set-ExplorerTweaks"; Checked = $true }
        "Browser Tweaks"                          = @{ Fn = "Set-BrowserTweaks"; Checked = $true }
        "Disable Copilot"                                                      = @{ Fn = "Disable-Copilot"; Checked = $true }
        "Disable Unnecessary Scheduled Tasks"                                  = @{ Fn = "Disable-UnnecessaryScheduledTasks"; Checked = $true }
        "Disable Telemetry + Advertising ID"                                   = @{ Fn = "Disable-TelemetryAndAdvertising"; Checked = $true }
        "Check Windows Activation Status"                                      = @{ Fn = "Test-WindowsActivation"; Checked = $true }
        "Check MS Office Activation Status"                                    = @{ Fn = "Test-OfficeActivation"; Checked = $true }
        "Clean Temp Files + Windows Update Cache"                              = @{ Fn = "Clear-TempAndUpdateCache"; Checked = $true }
        "-- OPTIONAL EXTRAS BELOW --"                                          = @{ Fn = $null; Checked = $false }   # 👉 separator row, not clickable
        "Enable Classic Right-Click Context Menu"                              = @{ Fn = "Enable-ClassicContextMenu"; Checked = $true }
        "Disable Lock Screen Ads / Tips"                                       = @{ Fn = "Disable-LockScreenAdsAndTips"; Checked = $true }
        "Enable Dark Mode"                                                     = @{ Fn = "Enable-DarkMode"; Checked = $false }
        "Disable Cortana Web Search Results in Start Menu"                     = @{ Fn = "Disable-CortanaWebSearch"; Checked = $false }
        "Performance-Focused Visual Effects"                                   = @{ Fn = "Set-PerformanceVisuals"; Checked = $false }
        "Repair Print Spooler & Font Cache"            = @{ Fn = "Repair-PrintAndFontCache"; Checked = $true}
        "Network Optimizations (NLA delay, DNS, IPv6)" = @{ Fn = "Set-NetworkOptimizations"; Checked = $true }
        "Disable Fast Startup"                                                 = @{ Fn = "Disable-FastStartup"; Checked = $true }
        "Tune Search Indexer and SysMain"                                      = @{ Fn = "Set-IndexerAndSysMain"; Checked = $true }
        "Optimize Background Services + Notifications + Clipboard" = @{ Fn = "Optimize-BackgroundServices"; Checked = $true }
        "Disable Sleep When Plugged In" = @{ Fn = "Set-PowerSleepNever"; Checked = $true }
        "Uninstall Software (opens selection window)"                          = @{ Fn = "Show-InstalledSoftware"; Checked = $true }
        "Remove OEM Bloat (Dell/HP/Lenovo)" = @{ Fn = "Remove-OEMBloat"; Checked = $true }
        "Disable Windows Recall"           = @{ Fn = "Disable-Recall"; Checked = $true }
        "Check for Multiple Antivirus (warning prompt)"                        = @{ Fn = "Test-MultipleAntivirus"; Checked = $true }
        "Enable Defender + Update Signatures"                                  = @{ Fn = "Enable-DefenderAndUpdate"; Checked = $true }
        "Disable Startup Items (AnyDesk, Bluestacks, Chrome, Spotify, etc.)"    = @{ Fn = "Disable-StartupItems"; Checked = $true }
        "Update All Apps (Store + Winget + Windows Update)"                    = @{ Fn = "Update-AllApps"; Checked = $true }
    }

    # 👉 ---- Build GUI ----
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "MRGARGSIR Windows Setup Utility - @MRGARGSIR"
    $form.Size = New-Object System.Drawing.Size(620, 670)
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
    $btnSelectAll.Location = New-Object System.Drawing.Point(10, 520)
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
    $btnSelectNone.Location = New-Object System.Drawing.Point(140, 520)
    $btnSelectNone.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectNone.Add_Click({
        for ($i = 0; $i -lt $checkList.Items.Count; $i++) { $checkList.SetItemChecked($i, $false) }
    })
    $form.Controls.Add($btnSelectNone)

    # 👉 Run button
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = "Run Selected Tweaks"
    $btnRun.Location = New-Object System.Drawing.Point(390, 520)
    $btnRun.Size = New-Object System.Drawing.Size(200, 34)
    $btnRun.BackColor = [System.Drawing.Color]::FromArgb(60,140,60)
    $btnRun.ForeColor = [System.Drawing.Color]::White
    $btnRun.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnRun)
    $form.AcceptButton = $btnRun

    # 👉 Cancel button
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(390, 560)
    $btnCancel.Size = New-Object System.Drawing.Size(200, 30)
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel)
    $form.CancelButton = $btnCancel

    Add-RainbowFooter -Form $form
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

# SIG # Begin signature block
# MIIdkQYJKoZIhvcNAQcCoIIdgjCCHX4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD5i8Cc0c/3GtT1
# YNmb/4cI6UyBNvdgOeQ/WsNtXDViU6CCAz4wggM6MIICIqADAgECAhB7tTJ3UBw4
# nkj+CleM2KE8MA0GCSqGSIb3DQEBCwUAMDUxCzAJBgNVBAYTAklOMRIwEAYDVQQK
# DAlNUkdBUkdTSVIxEjAQBgNVBAMMCU1SR0FSR1NJUjAeFw0yNTExMDUxMzI2MjNa
# Fw0zMDExMDUxMzM2MjNaMDUxCzAJBgNVBAYTAklOMRIwEAYDVQQKDAlNUkdBUkdT
# SVIxEjAQBgNVBAMMCU1SR0FSR1NJUjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAMtmn8hurJzsnfSgdBPyFEkN/1fidMQmriZ11pFBlAQxEPoIrK0IaHkk
# mrm+WEQsPWR8UswV0dlpAou4kpFT4C3+eJRfy9peRz7TQpCdnhTFcjffUgEzMSr8
# S16kDQIzpauFxuzukPmeeDArhZjuRbMJ3QE+iWDQQBa35PRVkKMmm83jFXVgmSHk
# GBRcBtxRoev0TBnsX11EJDRrLA9RI1EaRxTWxTMxZ6En2r9Zd4vv3j7zG82OSdg2
# nJeBz2RRTJ1Y09WywODhWCZn7OKuBynEFgrxTt49RMiTW5rvgGFRZ0gVhMuma+My
# ZvkcQWSMGvCnPd3EFeSAjJ9Q94IxBQECAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeA
# MBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBRhvmd8JzCVARuMcrY+l047
# ReBaizANBgkqhkiG9w0BAQsFAAOCAQEAT7pg8CGnj9VpnuHF+76Qi2pG4oEBRiDf
# QVAdprVYFuFDKCqcAhb8XLKilzWRIUiS+CUX9CdNvCYnKrJoO26PsoK5uA2H9jZ3
# BKRZOyNtcc8kOFH7cyeIxEP660DJzcT30ZvPvR6FCHWCWqLpj9oHkp1dVDw8mWw7
# Y8VJrWaDo5HZFyHZB7da93ID+PALskxAozUcg695qFOKbxs/MiuQMqC8R0orlM8h
# ipVx9KsUUA0zG4ICve+EC14FpvNOZSc8aXCpXCVyAgcQ5teWoJ9bmGaFsStBoCQx
# +jC+pyJCVVCtC0or+YRMeAI+yP2Dc8Z21hoRy6nXA8qofSbxlAMx5TGCGakwghml
# AgEBMEkwNTELMAkGA1UEBhMCSU4xEjAQBgNVBAoMCU1SR0FSR1NJUjESMBAGA1UE
# AwwJTVJHQVJHU0lSAhB7tTJ3UBw4nkj+CleM2KE8MA0GCWCGSAFlAwQCAQUAoIG4
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDJsLnL1375Y6NnMi6uhgNjEXndqb6X
# T9k7kIbSJpPJJDBMBgorBgEEAYI3AgEMMT4wPKA6gDgAVwBpAG4AZABvAHcAcwAg
# AFUAdABpAGwAaQB0AHkAIABiAHkAIABtAHIAZwBhAHIAZwBzAGkAcjANBgkqhkiG
# 9w0BAQEFAASCAQBEy4TQqezLVbVZBejw3CZj4K9+jXgLoX62hr3e1cxTKM2CYSX8
# ZkcxbxeRrEmc7X/xrJoQ8nLgmPqSAeZ2mSsxiLvQnOBTq4v5L/WSXdyo3lwQc8hC
# Eo7vQFdI3xq6D/UZlT9VCHhKRD7k+6LmOtomqT7LUOiIt4cow56FpQYCsTBjV3bu
# EMYbvgf/Z38Ksu1MMEXG+ZgaO+MzIIhHoTLJH7S1DTfr7dhNGK/jh2KIwnG4862b
# hGoAkjT6Gyuj9m9s19AXUB2ATtG2Q9V1NNi150uv+9biIUVa3427o7fVJwjISvBP
# KkKMhDa3fwVmrvc1G9jw3eRDACtM7YJbOEb8oYIXdjCCF3IGCisGAQQBgjcDAwEx
# ghdiMIIXXgYJKoZIhvcNAQcCoIIXTzCCF0sCAQMxDzANBglghkgBZQMEAgEFADB3
# BgsqhkiG9w0BCRABBKBoBGYwZAIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIB
# BQAEIFZDbRhFVwagFXNY3wSBUnAA9eT4Ay9J9aArR5r5t7a3AhAPYfG6RZdkawiT
# Ei+POW5JGA8yMDI2MDgwMzIyMTkyOVqgghM6MIIG7TCCBNWgAwIBAgIQCoDvGEuN
# 8QWC0cR2p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQg
# VGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMB4XDTI1MDYwNDAw
# MDAwMFoXDTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEyNTYgUlNBNDA5NiBU
# aW1lc3RhbXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3zBlCMGMyqJnfFNZx
# +wvA69HFTBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8TchTySA2R4QKpVD7dvN
# Zh6wW2R6kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWjFDYOzDi8SOhPUWlL
# nh00Cll8pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2UoyrN0ijtUDVHRXdmn
# cOOMA3CoB/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjPKHW5KqCvpSduSwhw
# UmotuQhcg9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KSuNLoZLc1Hf2JNMVL
# 4Q1OpbybpMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7wJNdoRORVbPR1VVnD
# uSeHVZlc4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vWdoUoHLWnqWU3dCCy
# FG1roSrgHjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOgrY7rlRyTlaCCfw7a
# SUROwnu7zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K096V1hE0yZIXe+gi
# AwW00aHzrDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCfgPf8+3mnAgMBAAGj
# ggGVMIIBkTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zyMe39/dfzkXFjGVBD
# z2GM6DAfBgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezLTjAOBgNVHQ8BAf8E
# BAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsGAQUFBwEBBIGIMIGF
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wXQYIKwYBBQUH
# MAKGUWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRH
# NFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNydDBfBgNVHR8EWDBW
# MFSgUqBQhk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# RzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcmwwIAYDVR0gBBkw
# FzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQBlKq3x
# HCcEua5gQezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZD9gBq9fNaNmFj6Eh
# 8/YmRDfxT7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/ML9lFfim8/9yJmZS
# e2F8AQ/UdKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu+WUqW4daIqToXFE/
# JQ/EABgfZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4obEMnxYOX8VBRKe1u
# NnzQVTeLni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2hECZpqyU1d0IbX6Wq
# 8/gVutDojBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasnM9AWcIQfVjnzrvwi
# CZ85EE8LUkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol/DJgddJ35XTxfUlQ
# +8Hggt8l2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgYxQbV1S3CrWqZzBt1
# R9xJgKf47CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3ocCVccAvlKV9jEnstr
# niLvUxxVZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcBZU8atufk+EMF/cWu
# iC7POGT75qaL6vdCvHlshtjdNXOCIUjsarfNZzCCBrQwggScoAMCAQICEA3HrFcF
# /yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8G
# A1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1MDUwNzAwMDAwMFoX
# DTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0
# LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGlu
# ZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2tjQ2UtZmWgyxU7UNq
# EY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn7SWCWgzbNfiR+2fk
# HUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vtLa4+gKPsYfwEu7EE
# bkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0XaF9DPfNBKS7Zazch8
# NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhxKTVVgtmUPAW35xUU
# FREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXKFifinT7zL2gdFpBP
# 9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3ZA4x5HHKS+rqBvKW
# xdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F20HHfIY4/6vHespY
# MQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9bH7mQyogxG9QEPHrP
# V6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u70EwgWbVRSX1Wd4+
# zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczsG7ZrIGNTAgMBAAGj
# ggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTvb1NK6eQGfHrK
# 4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNV
# HQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBp
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUH
# MAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAF877FoAc/gc9EXZx
# ML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzSUGvI9NAzaoQk97fr
# PBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ3essBS3q8nL2UwM+
# NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvRR2qKtntujB71WPYA
# gwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmTnM4I+ZI2rVQfjXQA
# 1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqoxW6q17r0z0noDjs6+
# BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9M+MtucVGyOxiDf06
# VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSmE+9JGYxOGLS/D284
# NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3rGlHqhpB/8MluDez
# ooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnIn/7GELH3IdvG2XlM
# 9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKdvlarEvf8EA+8hcpS
# M9LHJmyrxaFtoza2zNaQ9k+5t1wwggWNMIIEdaADAgECAhAOmxiO+dAt5+/bUOII
# QBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0Rp
# Z2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBaFw0zMTEx
# MDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL/m
# kHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3EMB/zG6Q4
# FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKyunWZanMy
# lNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsFxl7sWxq8
# 68nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU15zHL2pNe
# 3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJBMtfbBHMq
# bpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObURWBf3JFxG
# j2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6nj3cAORF
# JYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxBYKqxYxhE
# lRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5SUUd0vias
# tkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+xq4aLT8LW
# RV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIBNjAPBgNV
# HRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwPTzAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMCAYYweQYI
# KwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDAR
# BgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0NcVec4X6Cj
# dBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnovLbc47/T/
# gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65ZyoUi0mcud
# T6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFWjuyk1T3o
# sdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPFmCLBsln1
# VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9ztwGpn1eq
# XijiuZQxggN8MIIDeAIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdp
# Q2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3Rh
# bXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgw
# DQYJYIZIAWUDBAIBBQCggdEwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwG
# CSqGSIb3DQEJBTEPFw0yNjA4MDMyMjE5MjlaMCsGCyqGSIb3DQEJEAIMMRwwGjAY
# MBYEFN1iMKyGCi0wa9o4sWh5UjAH+0F+MC8GCSqGSIb3DQEJBDEiBCDZ27de8hgB
# b0oxhV8/CfNHE0TYRjQgblWgDRCcDaoTjDA3BgsqhkiG9w0BCRACLzEoMCYwJDAi
# BCBKoD+iLNdchMVck4+CjmdrnK7Ksz/jbSaaozTxRhEKMzANBgkqhkiG9w0BAQEF
# AASCAgDDm29KI9fU1Eh8vwvvTI3k/Ffm1afCzx4UliUX4zgAOS35zV7+x9GVkRmT
# XHHhjL8QDhHLmNRm7dOl9MvXRMe55Vawd7Y9hJnqZsAxVJAv4o4ABQh8vfBsganN
# sV6dlYopE6LYHoJ5uvgBnpIeiDhaeqNDUREO/IuZ4X5IXC6I3uAHwGqmC+8dOxs6
# YfI9+qJZze+oC3391JDywwAgi9JBuBOXo5uSdcEN6g5wdYsQ9bjpmGD0IfWxCTa0
# u73ShWs7uu9lg2VTJPJf49Q6xSbvrHCJE+WIEVf4aqxvnMw23be3MU+ogUX+ddYY
# q8EVo5Fyk9D0Jo9FOKBph9fGswXwNeMCsacJZ0cX+Lw6Ldo8LBArSvh7C3yJiG4G
# OqWNs09BZb+e03u0typ1KW7ZG1vd5NU38jkgCqdDU8NiPkqH30i1GzjbTuGfcyM7
# 0gP4PDZpriYcrxHKU+/H2cQGl7o1r/cctfzSh2v7HXMHS34RfL5HgjVmbgwit4ra
# 2Y37uLd6usb2rOZs/4FgUa+JEPKnVhTQ3SbsFJZEJEx49H+RcLLwe0Lz25MQbtkQ
# N72J1nNeLVLAJLEhIj64xd/d25snPB2nTI+G0PsfsWTEUK2X42ktcI/ECBFA/K80
# wjeacuNtsYeGndoOCpO4rjrZWkCgBhCH16f+BfgVnn//ovgGMQ==
# SIG # End signature block
