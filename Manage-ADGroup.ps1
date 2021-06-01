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

#XAML form designed using Vistual Studio
[xml]$inputXML = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="AD Group Manager" Height="500" Width="445" ResizeMode="NoResize">
    <Grid>
        <StackPanel>
            <Label Name="lblGroup" Content="Active Directory Group Members" HorizontalAlignment="Left" Margin="10,10,10,0" VerticalAlignment="Top" Width="Auto"/>
            <DataGrid Name="dgUsers" HorizontalAlignment="Left" Margin="20,10,10,0" VerticalAlignment="Top" MinWidth="380" IsReadOnly="true"/>
            <Button Name="btnRemoveUser" Content="Remove" HorizontalAlignment="Left" Margin="20,10,10,10" VerticalAlignment="Top" Width="80" Height="28" IsEnabled="false"/>
            <Label Name="lblSearch" Content="Search by email address" HorizontalAlignment="Left" Margin="10,10,10,0" VerticalAlignment="Top" Width="Auto"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Left" Margin="10,0,10,0" VerticalAlignment="Top">
                <TextBox Name="tbSearch" HorizontalAlignment="Left" Height="28" Margin="10,10,10,0" TextWrapping="Wrap" VerticalAlignment="Top" VerticalContentAlignment="Center" Padding="5,0,0,0" Width="201" ToolTip="Search by email address" AutomationProperties.HelpText="Search by email address"/>
                <Button Name="btnSearch" Content="Search" HorizontalAlignment="Left" Margin="0,10,10,0" VerticalAlignment="Top" Width="80" Height="28" />
            </StackPanel>
            <Button Name="btnAddUser" Content="Add" HorizontalAlignment="Left" Margin="20,10,0,10" VerticalAlignment="Top" Width="80" Height="28" IsEnabled="false"/>
            <Label Name="lblHint" Content="" HorizontalAlignment="Left" Margin="10,10,10,0" VerticalAlignment="Top" Width="Auto" />
        </StackPanel>
    </Grid>
</Window>
"@

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

$syncHash.ADGroup = Get-ADGroup $ADGroupName
$syncHash.dgUsers.ItemsSource = Get-ADGroup $ADGroupName | Get-ADGroupMember | Get-AdUser -Properties SamAccountName, EmailAddress | Select-Object SamAccountName, EmailAddress

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