Import GXS From "https://gxapi.boxgaming.co/v0/gxs.bas"

ReDim results(0) As Object
GXS.FindGames "GX Laser Tag", results

Print "Game", "Players", "Start Date", "Start Time", "Description"
Dim i As Object
For i = 1 To UBound(results)
    Dim r As Object
    r = results(i)
    Print r.name, r.clients, r.sdate, r.stime, r.desc
Next i