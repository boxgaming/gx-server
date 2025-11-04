Const LB_URL = "http://localhost:8080/v0/lb"
Dim sid As String
sid = "a0d878ff-80ce-413a-a762-9942d4256882"

'Dim res As Object
'res = Fetch(LB_URL + "/register")
'Print res.text
'sid = res.text

'res.firstName = "ted"
Print Add(sid, 6202, "grymm")

LGet sid

Sub LGet (id As String)
    Dim r As Object
    Dim text As Object
$If Javascript Then
    //'r = await fetch("http://localhost:8080/v0/lb", {
    r = await fetch(LB_URL, {
        method: "GET",
        headers: { 
            "Content-Type": "application/json",
            "X-GID": id
        }});
    text = await r.text();
$End If
    Print r.status
    Print text
End Sub

Function Add (id As String, score As Integer, pname As String)
    Dim s As Object
    s.score = score
    s.name = pname
    ' do some checks on the pname
$If Javascript Then
    //'r = await fetch("http://localhost:8080/v0/lb", {
    r = await fetch(LB_URL, {
        method: "POST",
        headers: { 
            "Content-Type": "application/json",
            "X-GID": id
        },
        body: JSON.stringify(s)});
$End If
    Add = r.status
End Function