<#
.SYNOPSIS
Add/Remove AD Users from an AD Group.
.DESCRIPTION
Add or remove Active Directory Users from an Active Directory Group.
.EXAMPLE
.\Manage-ADGroup.ps1 -ADGroupName <NameOfADGroup>
.NOTES

### Authors

* **Aslak Tangen** - [aslak.tangen@gmail.com](mailto:aslak.tangen@gmail.com)

### Requires

* PowerShell version 5

#>

param(
    [Parameter(Mandatory=$true)]
    [String]$ADGroupName
)

#Load Assembly and Library
Add-Type -AssemblyName PresentationFramework
Add-Type -Path "$PSScriptRoot\wpf\MaterialDesignColors.dll"
Add-Type -Path "$PSScriptRoot\wpf\MaterialDesignThemes.wpf.dll"

switch ((Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize).AppsUseLightTheme) {
    0 {
        $Theme = "Dark"
    }
    1 {
        $Theme = "Light"
    }
    default {
        $Theme = "Light"
    }
}
$PrimaryColor = "Indigo"
$AccentColor = "Teal"

# Process XAML
$inputXML = ""
foreach ($line in [System.IO.File]::ReadLines("$PSScriptRoot\wpf\ManageADGroup.xaml")) {
    if ("<!-- INSERT RESOURCES IN CODE HERE -->" -eq $line) {
        $inputXML += '<ResourceDictionary Source="pack://application:,,,/MaterialDesignThemes.Wpf;component/Themes/MaterialDesignTheme.' + $Theme + '.xaml" />' + "`n"
        $inputXML += '<ResourceDictionary Source="pack://application:,,,/MaterialDesignColors;component/Themes/Recommended/Primary/MaterialDesignColor.' + $PrimaryColor + '.xaml" />' + "`n"
        $inputXML += '<ResourceDictionary Source="pack://application:,,,/MaterialDesignColors;component/Themes/Recommended/Accent/MaterialDesignColor.' + $AccentColor + '.xaml" />' + "`n"
        $inputXML += '<ResourceDictionary Source="pack://application:,,,/MaterialDesignThemes.Wpf;component/Themes/MaterialDesignTheme.Defaults.xaml" />' + "`n"
        $inputXML += '<ResourceDictionary Source="pack://application:,,,/MaterialDesignThemes.Wpf;component/Themes/MaterialDesignTheme.Shadows.xaml" />' + "`n"
        $inputXML += '<ResourceDictionary Source="pack://application:,,,/MaterialDesignThemes.Wpf;component/Themes/MaterialDesignTheme.Shadows.xaml" />' + "`n"
    }
    else {
        $inputXML += $line + "`n"
    }
}
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:Na",'Na'  -replace '^<Win.*', '<Window'

$syncHash = [hashtable]::Synchronized(@{})
[xml]$XAML = $inputXML
$reader = New-Object System.Xml.XmlNodeReader $XAML
Try
{
    $syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
}
Catch
{
    Throw $_
}
ForEach ($node in $xaml.SelectNodes("//*[@Name]")) {
    $syncHash.($node.Name) = $syncHash.Window.FindName($node.Name)
}

# Initialize
$syncHash.PrimaryColor = $PrimaryColor
$syncHash.AccentColor = $AccentColor
$syncHash.Theme = $Theme
$syncHash.ADGroupName = $ADGroupName
$syncHash.ADGroup = Get-ADGroup $ADGroupName
$syncHash.lblGroup.Content = "Members of $ADGroupName`:"
$syncHash.dgUsers.ItemsSource = Get-ADGroup $ADGroupName | Get-ADGroupMember | Get-AdUser -Properties SamAccountName, EmailAddress | Select-Object SamAccountName, EmailAddress

# Dialog Functions
Function New-DialogButton {
    param(
        [hashtable]$syncHash,
        [string]$text,
        [ScriptBlock]$Action
    )
    $WPF_Button = [System.Windows.Controls.Button]::new()
    $WPF_Button.Content = $text
    $WPF_Button.Style = $syncHash.Window.FindResource("MaterialDesignRaisedButton")
    $WPF_Button.Margin = 10
    $WPF_Button.Add_Click($Action)
    return $WPF_Button
}

Function New-Dialog {
    Param(
        [hashtable]$syncHash,
        [string]$Title,
        [string]$Message,
        [ValidateSet("Info", "Warning", "Critical", "Question")]
        [string]$Type,
        [ScriptBlock]$Action
    )

    <# DialogPanel #>
    $WPF_StackPanel = [System.Windows.Controls.StackPanel]::new()
    $WPF_StackPanel.Margin = 50
    $WPF_StackPanel.MaxWidth = ($syncHash.Window.Width / 2)

    <# Header #>
    $WPF_Type = [MaterialDesignThemes.Wpf.PackIcon]::new()
    $WPF_Type.Width = 42.0
    $WPF_Type.Height = 42.0
    $WPF_Type.Margin = 10
    Switch ($Type) {
        "Warning" {
            $WPF_Type.Kind = "AlertDecagramOutline"
            $WPF_Type.Foreground = "#fbc02d"
        }
        "Critical" {
            $WPF_Type.Kind = "CloseOctagonOutline"
            $WPF_Type.Foreground = "#bf360c"
        }
        "Question" {
            $WPF_Type.Kind = "HelpCircleOutline"
            $WPF_Type.Foreground = "#fbc02d"
        }
        Default {
            $WPF_Type.Kind = "InformationOutline"
            $WPF_Type.Foreground = $syncHash.Window.FindResource("SecondaryAccentBrush")
        }
    }

    $WPF_Title = [System.Windows.Controls.TextBlock]::new()
    $WPF_Title.Style = $syncHash.Window.FindResource("MaterialDesignHeadline5TextBlock")
    $WPF_Title.Margin = 10
    $WPF_Title.VerticalAlignment = "Center"
    $WPF_Title.Text = $Title
    
    $WPF_HeaderStackPanel = [System.Windows.Controls.StackPanel]::new()
    $WPF_HeaderStackPanel.Orientation = "Horizontal"
    $WPF_HeaderStackPanel.Children.Add($WPF_Type)
    $WPF_HeaderStackPanel.Children.Add($WPF_Title)

    $WPF_StackPanel.Children.Add($WPF_HeaderStackPanel)

    <# Message #>
    $WPF_Message = [System.Windows.Controls.TextBlock]::new()
    $WPF_Message.Style = $syncHash.Window.FindResource("MaterialDesignBody1TextBlock")
    $WPF_Message.Margin = 10
    $WPF_Message.TextWrapping = "Wrap"
    $WPF_Message.Text = $Message

    $WPF_StackPanel.Children.Add($WPF_Message)

    <# Buttons #>
    $WPF_ButtonStackPanel = [System.Windows.Controls.StackPanel]::new()
    $WPF_ButtonStackPanel.Orientation = "Horizontal"

    $WPF_ButtonStackPanel.Children.Add((New-DialogButton $syncHash "Yes" $Action))
    $WPF_ButtonStackPanel.Children.Add((New-DialogButton $syncHash "Cancel" {[MaterialDesignThemes.Wpf.DialogHost]::CloseDialogCommand.Execute($null,$null)}))

    $WPF_StackPanel.Children.Add($WPF_ButtonStackPanel)

    [MaterialDesignThemes.Wpf.DialogHost]::Show($WPF_StackPanel);
}

# Title Bar Handlers
$syncHash.header.Add_MouseDown({ $syncHash.Window.DragMove() })
$syncHash.header.Add_MouseDoubleClick({
    if ($syncHash.Window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $syncHash.Window.WindowState = [System.Windows.WindowState]::Normal
    }
    else {
        $syncHash.Window.WindowState = [System.Windows.WindowState]::Maximized
    }
})
$syncHash.window_close.Add_Click({ $syncHash.Window.Close();Exit })

# User Action Handlers
$syncHash.tbSearch.Add_KeyDown({
    if ($_.Key -eq "Return") {
        $peer = [System.Windows.Automation.Peers.ButtonAutomationPeer]($syncHash.btnSearch)
        $invokeProv = $peer.GetPattern([System.Windows.Automation.Peers.PatternInterface]::Invoke)
        $invokeProv.Invoke()
    }
})

$syncHash.btnSearch.Add_Click({
    try {
        $user = Get-ADUser -Filter "EmailAddress -like `"$($syncHash.tbSearch.Text)`"" -Properties EmailAddress, SamAccountName
    }
    catch {
        $syncHash.btnAddUser.IsEnabled = $false
    }
    if ($user.count -lt 1) {
        $syncHash.tbHint.Text = "Email not found in AD"
        $syncHash.btnAddUser.IsEnabled = $false
    }
    elseif ($user.count -gt 1) {
        $syncHash.tbHint.Text = "More than one email matches your search, please specify"
        $syncHash.btnAddUser.IsEnabled = $false
    }
    else {
        if ($null -ne (Get-ADGroupMember $ADGroupName | Where-Object -Property SamAccountName -eq $user.SamAccountName)) {
            $syncHash.tbHint.Text = "That user is already a member of the group."
            $syncHash.btnAddUser.IsEnabled = $false
        }
        else {
            $syncHash.tbHint.Text = "Found user:`n`n $($user.SamAccountName)`n $($user.EmailAddress)"
            $syncHash.btnAddUser.IsEnabled = $true
        }
    }
})

$syncHash.btnAddUser.Add_Click({

    try {
        $user = Get-ADUser -Filter "EmailAddress -like `"$($syncHash.tbSearch.Text)`"" -Properties EmailAddress, SamAccountName
    }
    catch {
        $syncHash.btnAddUser.IsEnabled = $false
    }
    if ($user.count -lt 1) {
        $syncHash.tbHint.Text = "Email not found in AD"
        $syncHash.btnAddUser.IsEnabled = $false
    }
    elseif ($user.count -gt 1) {
        $syncHash.tbHint.Text = "More than one email matches your search, please specify"
        $syncHash.btnAddUser.IsEnabled = $false
    }
    else {
        if ($null -ne (Get-ADGroupMember $ADGroupName | Where-Object -Property SamAccountName -eq $user.SamAccountName)) {
            $syncHash.tbHint.Text = "That user is already a member of the group."
            $syncHash.btnAddUser.IsEnabled = $false
        }
        else {
            $syncHash.user = $user
            New-Dialog -syncHash $syncHash -Title "Add User" -Message "Are you sure you want to add`n`n $($user.EmailAddress)`n`nto $($syncHash.ADGroupName)?" -Type "Question" -Action {
                $syncHash.tbSearch.Text = ""
                $syncHash.tbHint.Text = ""
                $syncHash.btnAddUser.IsEnabled = $false
                Add-ADGroupMember -Identity $syncHash.ADGroup -Members $syncHash.user
                $syncHash.user = $null
                $syncHash.dgUsers.ItemsSource = Get-ADGroup $ADGroupName | Get-ADGroupMember | Get-AdUser -Properties SamAccountName, EmailAddress | Select-Object SamAccountName, EmailAddress
                [MaterialDesignThemes.Wpf.DialogHost]::CloseDialogCommand.Execute($null,$null)
            }
        }
    }
})

$syncHash.dgUsers.Add_SelectionChanged({
    if ($null -ne $syncHash.dgUsers.SelectedItem.EmailAddress -and "" -ne $syncHash.dgUsers.SelectedItem.EmailAddress) {
        $syncHash.btnRemoveUser.IsEnabled = $true
    }
    else {
        $syncHash.btnRemoveUser.IsEnabled = $false
    }
})

$syncHash.btnRemoveUser.Add_Click({
    $user = $syncHash.dgUsers.SelectedItem
    New-Dialog -syncHash $syncHash -Title "Remove User" -Message "Are you sure you want to remove`n`n $($user.EmailAddress)`n`nfrom $($syncHash.ADGroupName)?" -Type "Question" -Action {
        Remove-ADGroupMember -Identity $syncHash.ADGroup -Members $syncHash.dgUsers.SelectedItem -Confirm:$false
        $syncHash.dgUsers.ItemsSource = Get-ADGroup $ADGroupName | Get-ADGroupMember | Get-AdUser -Properties SamAccountName, EmailAddress | Select-Object SamAccountName, EmailAddress
        [MaterialDesignThemes.Wpf.DialogHost]::CloseDialogCommand.Execute($null,$null)
    }

})

#Show XMLform
$syncHash.Window.ShowDialog()
