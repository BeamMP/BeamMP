del /f BeamMP.zip
"C:\Program Files\7-Zip\7z.exe" -r a BeamMP.zip . -xr!*.git* -xr!*.github* -xr!*.idea* -xr!*3rd_party_licenses* -xr!*Deploy-BeamMP.bat* || pause && exit

del /f C:\Users\dpres\AppData\Local\BeamNG.drive\0.34\mods\multiplayer\BeamMP.zip || pause && exit
echo F | xcopy /Y /S BeamMP.zip C:\Users\dpres\AppData\Local\BeamNG.drive\0.34\mods\multiplayer\BeamMP.zip || pause && exit