<#
    Fichier original Get-RSATTools.ps1
    Fonctionalit� : Interface de gestion des outils RSAT pour l'administration Windows
    Mise en forme GUI
    Traduction en Fran�ais
    Git : https://github.com/ludovicferra
#> 

#Masquer la console powershell
function HidePOWSHConsole {
    Add-Type -Name Window -Namespace Console -MemberDefinition '[DllImport("Kernel32.dll")]public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'
    [Console.Window]::ShowWindow($([Console.Window]::GetConsoleWindow()), 0)
}
HidePOWSHConsole | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework
[System.Windows.Forms.Application]::EnableVisualStyles()
#Main
$Main                            = New-Object system.Windows.Forms.Form
$Main.ClientSize                 = '600,400'
$Main.text                       = "Get-RSATTester"
$Main.BackColor                  = "#f5a623"
$Main.TopMost                    = $false
$Main.FormBorderStyle            = 'Fixed3D'
$Main.MaximizeBox                = $false
$Main.icon = [Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)
#Boite de r�sultats
$TextBoxResult                   = New-Object system.Windows.Forms.TextBox
$TextBoxResult.multiline         = $true
$TextBoxResult.ReadOnly         = $true
$TextBoxResult.width             = 590
$TextBoxResult.height            = 323
$TextBoxResult.location          = New-Object System.Drawing.Point(5,30)
$TextBoxResult.Font              = 'Microsoft Sans Serif,8'
$TextBoxResult.Scrollbars        = "Vertical"
#Texte de boite
$Label1                          = New-Object system.Windows.Forms.Label
$Label1.text                     = "Gestion des outils RSAT sur cette machine :"
$Label1.AutoSize                 = $false
$Label1.width                    = 372
$Label1.height                   = 11
$Label1.location                 = New-Object System.Drawing.Point(10,10)
$Label1.Font                     = 'Microsoft Sans Serif,8'
#Bouton d'installation
$ButtonInstall                   = New-Object system.Windows.Forms.Button
$ButtonInstall.text              = "Installer tous les RSAT"
$ButtonInstall.width             = 285
$ButtonInstall.height            = 30
$ButtonInstall.visible           = $false
$ButtonInstall.location          = New-Object System.Drawing.Point(5,361)
$ButtonInstall.Font              = 'Microsoft Sans Serif,9'
#Bouton de d�sinstallation
$ButtonUnInstall                   = New-Object system.Windows.Forms.Button
$ButtonUnInstall.text              = "D�sinstaller tous les RSAT"
$ButtonUnInstall.width             = 285
$ButtonUnInstall.height            = 30
$ButtonUnInstall.visible           = $false
$ButtonUnInstall.location          = New-Object System.Drawing.Point(310,361)
$ButtonUnInstall.Font              = 'Microsoft Sans Serif,9'
#Concat�nation de l'UI
$Main.controls.AddRange(@($TextBoxResult,$Label1,$ButtonInstall,$ButtonUnInstall))
#Valide que le programme soit lanc� en tant qu'administrateur
if (-NOT([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $message = "Cet outil necessite une �l�vation"
    [System.Windows.MessageBox]::Show($message,'�l�vation','Ok','Error') | Out-Null
    break
}
#R�cup�re les outils RSAT non install�s
$NonInstalledRSAT = Get-WindowsCapability -Name RSAT* -Online | Where-Object State -ne "Installed" #Remonte uniquement les RSAT non install�s 
if ($NonInstalledRSAT.length -gt 0 ) { 
    $TextBoxResult.text = "Les outils RSAT Suivants ne sont pas install�s :`r`n"
    $TextBoxResult.text += $NonInstalledRSAT | Select-Object state,Displayname | ForEach-Object { Write-Output "$($_.state) : $($_.Displayname)`r`n"}
    $ButtonInstall.Visible = $true
    $ButtonUnInstall.visible = $true
}
else { 
    $TextBoxResult.text = "L'ensemble des RSAT disponibles online sont install�s`r`n"
    $ButtonUnInstall.visible = $true
}

$ButtonInstall.Add_Click({
    $ButtonInstall.text = "Installation en cours, Patienter..."
    $ButtonInstall.enabled = $false
    $TextBoxResult.text += InstallRSAT -All
    $ButtonInstall.text = "Installation termin�e"
})
$ButtonUnInstall.Add_Click({
    $ButtonUnInstall.text = "D�sinstallation en cours, Patienter..."
    $ButtonUnInstall.enabled = $false
    $TextBoxResult.text += InstallRSAT -Uninstall | Out-String
    $ButtonUnInstall.text = "D�sinstallation termin�e"
})
function InstallRSAT {
<#
    From code of Martin Bengtsson
    Git : https://github.com/imabdk/Powershell
    Blog: www.imab.dk
    Twitter: @mwbengtsson
#> 
[CmdletBinding()]
param(
    [parameter(Mandatory=$false)] [ValidateNotNullOrEmpty()] [switch]$All,
    [parameter(Mandatory=$false)] [ValidateNotNullOrEmpty()] [switch]$Uninstall
)
    #Cr�ation d'un retour de logs :
    $logs = @()
    #R�cup�re l'�tat de red�marrage en attente par le registre
    $CBSRebootKey = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction Ignore
    $WURebootKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction Ignore
    if ($CBSRebootKey -OR $WURebootKey) { $TestPendingRebootRegistry = $true }
    else { $TestPendingRebootRegistry = $false }
    #R�cup�ration de la version de Built Windows
    [int]$minimalbuild = 17763
    $WindowsBuild = (Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue).BuildNumber
    #R�cup�ration de l'existaance de serveur WSUS
    $WUServer = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name WUServer -ErrorAction Ignore).WUServer
    if ($WindowsBuild -gt $minimalbuild) {
        $message = "La version Build de Windows 10 est correcte pour installer les ouilts RSAT.`r`nVersion de build actuelle : $WindowsBuild`r`n"
        $message += "***********************************************************"
        $logs += Write-Output $message
        if ($WUServer) {
            $message = "Un serveur WSUS local a �t� trouv� configur� par la strat�gie de groupe : $WUServer`r`n"
            $message += "(Vous devrez peut-�tre configurer des param�tres suppl�mentaires par GPO si les choses ne fonctionnent pas)`r`n`r`n"
            $message += "L'objet de strat�gie de groupe � voir est le suivant:`r`n'Sp�cifiez les param�tres d'installation et de r�paration de composants facultatifs'`r`n"
            $message += "V�rifiez qu'il soit actif :`r`n'T�l�chargez le contenu de r�paration et les fonctionnalit�s optionnelles directement � partir de Windows Update...'`r`n"
            $message += "***********************************************************"
            $logs += Write-Output $message
            [System.Windows.MessageBox]::Show($message,'WUServer','Ok','Information') | Out-Null
        }
        if ($TestPendingRebootRegistry) {
            $message = "Un red�marrage est en attente.`r`nLe script continuera, mais les RSAT risquent de ne pas �tre install�s / d�sinstall�s correctement`r`n"
            $message += "***********************************************************`r`n"
            $logs += Write-Output $message
            $message += "On continue tout de m�me ?"
            $choicereboot = [System.Windows.MessageBox]::Show($message,'Redemarrage en attente','YesNo','Warning')
        }
        else { $choicereboot = 'Yes' }
        if ($choicereboot -eq 'Yes') {
            if ($PSBoundParameters["All"]) {
                #Installation tous les outils RSAT disponibles
                $logs += Write-Output "Installation tous les outils RSAT disponibles"
                $Install = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "NotPresent"}
                if ($Install) {
                    foreach ($Item in $Install) {
                        $RsatItem = $Item.Name
                        $message = "Installation de :`r`n$($RsatItem | Out-String)"
                        $logs += Write-Output $message
                        [System.Windows.MessageBox]::Show($message,'Installation','Ok','Information') | Out-Null
                        try { Add-WindowsCapability -Online -Name $RsatItem }
                        catch [System.Exception] {
                            $message = "Erreur � l'installation de :`r`n$RsatItem`r`n"
                            $message += "Erreur :`r`n$($_.Exception.Message)"
                            $logs += Write-Output $message
                            [System.Windows.MessageBox]::Show($message,'Erreur installation','Ok','Error') | Out-Null
                        }
                    }
                }
                else {
                    $message = "Toutes les fonctionnalit�s RSAT semblent d�j� install�es"
                    $logs += Write-Output $message
                    [System.Windows.MessageBox]::Show($message,'D�j� install�es','Ok','Information')  | Out-Null
                }
            }
            #D�sinstallation de tous les outils RSTAT
            if ($PSBoundParameters["Uninstall"]) {
                #R�cup�ration des tous les outils RSAT install�s
                $Installedoriginal = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "Installed"}
                $message = Write-Output "Produits d�couverts � d�sinstaller :`r`n"
                $message += $Installedoriginal.Name | Format-Table -HideTableHeaders | Out-String
                $logs += Write-Output $message
                $message += Write-Output "`r`nProc�der � la d�sinstallation ?"
                $choiceuninstall = [System.Windows.MessageBox]::Show($message,'D�sinstallation','YesNo','Information')
                if ($choiceuninstall -eq 'Yes') {
                    #Premi�re requ�te pour les fonctionnalit�s RSAT install�es
                    $Installed = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "Installed" -AND $_.Name -notlike "Rsat.ServerManager*" -AND $_.Name -notlike "Rsat.GroupPolicy*" -AND $_.Name -notlike "Rsat.ActiveDirectory*"} 
                    if ($Installed) {
                        # D�sinstallation de la premi�re s�rie de fonctionnalit�s RSAT - certaines fonctionnalit�s semblent �tre verrouill�es jusqu'� ce que d'autres soient d�sinstall�es en premier
                        $logs += Write-Output "D�sinstallation de la premi�re s�rie de fonctionnalit�s RSAT`r`n"
                        foreach ($Item in $Installed) {
                            $RsatItem = $Item.Name
                            $logs += Write-Output "D�sinstallation de la fonctionnalit� RSAT :`r`n$RsatItem"
                            try { Remove-WindowsCapability -Name $RsatItem -Online }
                            catch [System.Exception] { 
                                $logs += Write-Output "Erreur � la d�sinstallation de : $RsatItem`r`n"
                                $logs += Write-Output "Avec l'erreur :`r`n$($_.Exception.Message)"
                                $logs += Write-Output $message
                            }
                        }   
                    }
                    #Interrogation des fonctionnalit�s RSAT install�es pour finir la d�sinstallation
                    $Installed = Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat*" -AND $_.State -eq "Installed"}
                    if ($Installed) { 
                        $logs += Write-Output "D�sinstallation de la seconde s�rie de fonctionnalit�s RSAT"
                        foreach ($Item in $Installed) {
                            $RsatItem = $Item.Name
                            $logs += Write-Output "D�sinstallation de $RsatItem"
                            try { Remove-WindowsCapability -Name $RsatItem -Online }
                            catch [System.Exception] {
                                $logs += Write-Output "Erreur � la d�sinstallation de :`r`n$RsatItem`r`n"
                                $logs += Write-Output= "Avec l'erreur :`r`n$($_.Exception.Message)"
                            }
                        } 
                    }
                    else {
                        $message = "Toutes les fonctionnalit�s RSAT semblent d�j� d�sinstall�es"
                        [System.Windows.MessageBox]::Show($message,'D�j� install�es','Ok','Information')  | Out-Null
                    }
                }
                else { $logs += Write-Output "`r`nD�sinstallation annul�e`r`n" }
            }
        }
    }
    else {
        $message = "La version Build de Windows 10 ne correspond pas pour installer les ouilts RSAT � la demande.`r`nVersion de build actuelle : $WindowsBuild`r`n(N�c�ssite une version $minimalbuild ou sup�rieure)"
        $logs = Write-Output "Cette version de windows n'est pas support�e"
        [System.Windows.MessageBox]::Show($message,'Mauvaise Build','Ok','Warning') | Out-Null
    }
Return $logs
}
[void]$Main.ShowDialog()