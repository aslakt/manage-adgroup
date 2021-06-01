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

#XAML form designed using Vistual Studio
# Read XAML and handle parameter inputs
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
$syncHash.PrimaryColor = $PrimaryColor
$syncHash.AccentColor = $AccentColor
$syncHash.Theme = $Theme
#$syncHash.ADGroup = Get-ADGroup $ADGroupName
#$syncHash.dgUsers.ItemsSource = Get-ADGroup $ADGroupName | Get-ADGroupMember | Get-AdUser -Properties SamAccountName, EmailAddress | Select-Object SamAccountName, EmailAddress

$syncHash.btnSearch.Add_Click({
    try {
        $user = Get-ADUser -Filter "EmailAddress -like `"$($syncHash.tbSearch.Text)`"" -Properties EmailAddress
    }
    catch {
        $syncHash.btnAddUser.IsEnabled = $false
    }
    if ($user.count -lt 1) {
        $syncHash.lblHint.Content = "Email not found in AD"
        $syncHash.btnAddUser.IsEnabled = $false
    }
    elseif ($user.count -gt 1) {
        $syncHash.lblHint.Content = "More than one email matches your search, please specify"
        $syncHash.btnAddUser.IsEnabled = $false
    }
    else {
        $syncHash.lblHint.Content = "Found user: $($user.EmailAddress), click to add"
        $syncHash.btnAddUser.IsEnabled = $true
    }
})

$syncHash.btnAddUser.Add_Click({

    try {
        $user = Get-ADUser -Filter "EmailAddress -like `"$($syncHash.tbSearch.Text)`"" -Properties EmailAddress
    }
    catch {
        $syncHash.btnAddUser.IsEnabled = $false
    }
    if ($user.count -lt 1) {
        $syncHash.lblHint.Content = "Email not found in AD"
        $syncHash.btnAddUser.IsEnabled = $false
    }
    elseif ($user.count -gt 1) {
        $syncHash.lblHint.Content = "More than one email matches your search, please specify"
        $syncHash.btnAddUser.IsEnabled = $false
    }
    else {
        $syncHash.tbSearch.Text = ""
        $syncHash.lblHint.Content = ""
        $syncHash.btnAddUser.IsEnabled = $false
        #Write-Host "Adding $($user.EmailAddress)"
        Add-ADGroupMember -Identity $syncHash.ADGroup -Members $user
        $syncHash.dgUsers.ItemsSource = Get-ADGroup $ADGroupName | Get-ADGroupMember | Get-AdUser -Properties SamAccountName, EmailAddress | Select-Object SamAccountName, EmailAddress
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
    if ([System.Windows.MessageBox]::Show("Are you sure you want to remove`n$($user.EmailAddress)`nfrom the AD group?", "Remove User", "YesNo", "Question") -eq "Yes") {
        # Write-Host "Removing $($user.EmailAddress)"
        Remove-ADGroupMember -Identity $syncHash.ADGroup -Members $syncHash.dgUsers.SelectedItem -Confirm:$false
        $syncHash.dgUsers.ItemsSource = Get-ADGroup $ADGroupName | Get-ADGroupMember | Get-AdUser -Properties SamAccountName, EmailAddress | Select-Object SamAccountName, EmailAddress
    }

})

#Show XMLform
$syncHash.Window.ShowDialog()