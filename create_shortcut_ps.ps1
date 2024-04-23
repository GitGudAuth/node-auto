# Change this to any other path you like
try{
    $SourceFilePath = Read-Host "Enter the path of source file "
    $ShortcutPath = Read-Host "Enter the path you want to create shortcut "
    $WScriptObj = New-Object -ComObject ("WScript.Shell")
    $shortcut = $WScriptObj.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $SourceFilePath
    $shortcut.Save()
    Write-Host "Create shortcut successfully"
}
catch{
    "Something wrong with your path"
    "The path should be C:\ABC without the `""
}
# This may be the final version