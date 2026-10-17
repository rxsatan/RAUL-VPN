# RAUL VPN - PowerShell panel with system-tray icon + WireGuard service control
# Config files expected in: %USERPROFILE%\RAUL-VPN\
# Run elevated to install/start/stop WireGuard tunnel services.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$wgExe = Join-Path $env:ProgramFiles "WireGuard\wireguard.exe"
$countryConfigs = [ordered]@{
    "1" = @{ Name = "Brasil"; Config = Join-Path $HOME "RAUL-VPN\brasil.conf"; Tunnel = "raul-brazil" }
    "2" = @{ Name = "Canadá"; Config = Join-Path $HOME "RAUL-VPN\canada.conf"; Tunnel = "raul-canada" }
    "3" = @{ Name = "Estados Unidos"; Config = Join-Path $HOME "RAUL-VPN\eua.conf"; Tunnel = "raul-usa" }
    "4" = @{ Name = "Argentina"; Config = Join-Path $HOME "RAUL-VPN\argentina.conf"; Tunnel = "raul-argentina" }
}
$script:trayExit = $false
$script:tray = $null
$script:form = $null

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-ServiceName([string]$tunnel) { return "WireGuardTunnel`$$tunnel" }
function Add-Log([string]$message, [string]$color = "White") {
    if ($script:logBox -and -not $script:logBox.IsDisposed) {
        $script:logBox.SelectionColor = [System.Drawing.Color]::$color
        $script:logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $message`r`n")
        $script:logBox.SelectionStart = $script:logBox.TextLength
        $script:logBox.ScrollToCaret()
    }
}
function Test-WireGuard {
    if (Test-Path $wgExe) { return $true }
    $result = [System.Windows.Forms.MessageBox]::Show(
        "WireGuard não foi encontrado. Deseja abrir o instalador oficial?",
        "RAUL VPN", [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process "https://www.wireguard.com/install/"
    }
    return $false
}
function Update-Status {
    foreach ($key in $countryConfigs.Keys) {
        $country = $countryConfigs[$key]
        $serviceName = Get-ServiceName $country.Tunnel
        $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        $state = if ($svc) { $svc.Status.ToString() } else { "Não instalado" }
        if ($script:statusLabels.ContainsKey($key)) { $script:statusLabels[$key].Text = "$($country.Name): $state" }
    }
}
function Start-Country([string]$key) {
    $country = $countryConfigs[$key]
    if (-not (Test-Path $country.Config)) {
        Add-Log "Configuração não encontrada: $($country.Config)" "Gold"
        Add-Log "Coloque um .conf válido nessa pasta; o painel não cria servidores nem chaves." "Gold"
        return
    }
    if (-not (Test-Admin)) {
        Add-Log "Abra a RAUL VPN como administrador para iniciar o túnel." "Gold"
        return
    }
    $serviceName = Get-ServiceName $country.Tunnel
    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $svc) {
        & $wgExe /installtunnelservice $country.Config
        if ($LASTEXITCODE -ne 0) {
            Add-Log "Falha ao instalar túnel. Confira o arquivo .conf." "Tomato"
            return
        }
    }
    try {
        Start-Service -Name $serviceName
        Add-Log "Túnel $($country.Name) iniciado em segundo plano." "LightGreen"
    } catch {
        Add-Log "Não foi possível iniciar o túnel: $($_.Exception.Message)" "Tomato"
    }
    Update-Status
}
function Stop-Country([string]$key) {
    $country = $countryConfigs[$key]
    if (-not (Test-Admin)) {
        Add-Log "Abra a RAUL VPN como administrador para parar o túnel." "Gold"
        return
    }
    $serviceName = Get-ServiceName $country.Tunnel
    $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $svc) { Add-Log "Túnel $($country.Name) não está instalado." "Gold"; return }
    try {
        Stop-Service -Name $serviceName -Force
        Add-Log "Túnel $($country.Name) parado." "LightGreen"
    } catch { Add-Log "Erro ao parar túnel: $($_.Exception.Message)" "Tomato" }
    Update-Status
}
function Show-ConfigFolder {
    $folder = Join-Path $HOME "RAUL-VPN"
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    Start-Process explorer.exe $folder
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "RAUL VPN"
$form.Size = New-Object System.Drawing.Size(620, 570)
$form.MinimumSize = New-Object System.Drawing.Size(620, 570)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(14, 18, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.ShowInTaskbar = $true

$title = New-Object System.Windows.Forms.Label
$title.Text = "RAUL VPN"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 25, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::DeepSkyBlue
$title.Location = New-Object System.Drawing.Point(22, 15)
$title.Size = New-Object System.Drawing.Size(550, 45)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Made by: rxsatan"
$subtitle.ForeColor = [System.Drawing.Color]::LightSteelBlue
$subtitle.Location = New-Object System.Drawing.Point(26, 61)
$subtitle.Size = New-Object System.Drawing.Size(550, 24)
$form.Controls.Add($subtitle)

$startLabel = New-Object System.Windows.Forms.Label
$startLabel.Text = "Ativar VPN — escolha um país:"
$startLabel.Location = New-Object System.Drawing.Point(26, 98)
$startLabel.Size = New-Object System.Drawing.Size(300, 24)
$form.Controls.Add($startLabel)

$script:statusLabels = @{}
$y = 128
foreach ($key in $countryConfigs.Keys) {
    $country = $countryConfigs[$key]
    $button = New-Object System.Windows.Forms.Button
    $button.Text = "$($country.Name)"
    $button.Location = New-Object System.Drawing.Point(28, $y)
    $button.Size = New-Object System.Drawing.Size(165, 34)
    $button.FlatStyle = "Flat"
    $button.BackColor = [System.Drawing.Color]::FromArgb(28, 45, 72)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Add_Click({ Start-Country $this.Tag }.GetNewClosure())
    $button.Tag = $key
    $form.Controls.Add($button)
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "$($country.Name): ..."
    $label.Location = New-Object System.Drawing.Point(210, ($y + 7))
    $label.Size = New-Object System.Drawing.Size(360, 24)
    $form.Controls.Add($label)
    $script:statusLabels[$key] = $label
    $y += 42
}
$stopLabel = New-Object System.Windows.Forms.Label
$stopLabel.Text = "Desativar VPN:"
$stopLabel.Location = New-Object System.Drawing.Point(26, 305)
$stopLabel.Size = New-Object System.Drawing.Size(250, 24)
$form.Controls.Add($stopLabel)

$y = 334
foreach ($key in $countryConfigs.Keys) {
    $country = $countryConfigs[$key]
    $button = New-Object System.Windows.Forms.Button
    $button.Text = "Parar $($country.Name)"
    $button.Location = New-Object System.Drawing.Point(28, $y)
    $button.Size = New-Object System.Drawing.Size(165, 30)
    $button.FlatStyle = "Flat"
    $button.BackColor = [System.Drawing.Color]::FromArgb(48, 38, 48)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Tag = $key
    $button.Add_Click({ Stop-Country $this.Tag }.GetNewClosure())
    $form.Controls.Add($button)
    $y += 34
}
$logTitle = New-Object System.Windows.Forms.Label
$logTitle.Text = "Log:"
$logTitle.Location = New-Object System.Drawing.Point(210, 305)
$logTitle.Size = New-Object System.Drawing.Size(100, 24)
$form.Controls.Add($logTitle)
$script:logBox = New-Object System.Windows.Forms.RichTextBox
$script:logBox.Location = New-Object System.Drawing.Point(210, 332)
$script:logBox.Size = New-Object System.Drawing.Size(365, 145)
$script:logBox.ReadOnly = $true
$script:logBox.BackColor = [System.Drawing.Color]::FromArgb(8, 11, 18)
$script:logBox.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($script:logBox)

$folderButton = New-Object System.Windows.Forms.Button
$folderButton.Text = "Abrir pasta de configurações"
$folderButton.Location = New-Object System.Drawing.Point(28, 478)
$folderButton.Size = New-Object System.Drawing.Size(240, 32)
$folderButton.FlatStyle = "Flat"
$folderButton.BackColor = [System.Drawing.Color]::FromArgb(28, 45, 72)
$folderButton.ForeColor = [System.Drawing.Color]::White
$folderButton.Add_Click({ Show-ConfigFolder })
$form.Controls.Add($folderButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Sair"
$exitButton.Location = New-Object System.Drawing.Point(475, 478)
$exitButton.Size = New-Object System.Drawing.Size(100, 32)
$exitButton.FlatStyle = "Flat"
$exitButton.BackColor = [System.Drawing.Color]::FromArgb(65, 35, 42)
$exitButton.ForeColor = [System.Drawing.Color]::White
$exitButton.Add_Click({
    $script:trayExit = $true
    if ($script:tray) { $script:tray.Visible = $false; $script:tray.Dispose() }
    $form.Close()
})
$form.Controls.Add($exitButton)

$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$showItem = $trayMenu.Items.Add("Abrir RAUL VPN")
$showItem.Add_Click({ $form.Show(); $form.WindowState = "Normal"; $form.Activate() })
$exitItem = $trayMenu.Items.Add("Sair")
$exitItem.Add_Click({
    $script:trayExit = $true
    if ($script:tray) { $script:tray.Visible = $false; $script:tray.Dispose() }
    $form.Close()
})
$script:tray = New-Object System.Windows.Forms.NotifyIcon
$script:tray.Text = "RAUL VPN"
$script:tray.Icon = [System.Drawing.SystemIcons]::Shield
$script:tray.ContextMenuStrip = $trayMenu
$script:tray.Visible = $true
$script:tray.Add_DoubleClick({ $form.Show(); $form.WindowState = "Normal"; $form.Activate() })

$form.Add_Resize({
    if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        $form.Hide()
        $script:tray.ShowBalloonTip(1500, "RAUL VPN", "Painel minimizado para a bandeja do sistema.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})
$form.Add_FormClosing({
    if (-not $script:trayExit) {
        $_.Cancel = $true
        $form.Hide()
        $script:tray.ShowBalloonTip(1500, "RAUL VPN", "RAUL VPN continua na bandeja. Use o menu do ícone para sair.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
})
$form.Add_Shown({
    Update-Status
    Add-Log "Painel iniciado. Minimize/feche a janela para enviá-la à bandeja." "LightBlue"
    Add-Log "Configs esperadas em: $(Join-Path $HOME 'RAUL-VPN')" "LightBlue"
    if (-not (Test-Path $wgExe)) { Add-Log "WireGuard não encontrado. Instale pelo site oficial." "Gold" }
})
try {
    [void]$form.ShowDialog()
} finally {
    if ($script:tray) { $script:tray.Visible = $false; $script:tray.Dispose() }
}
