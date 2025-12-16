Option Explicit

Const MSG_HOST_GAME = 1, HOST = 1
Const MSG_JOIN_GAME = 2, CLIENT = 2
Const MSG_HOST_DISCONNECTED = 3
Const MSG_CLIENT_DISCONNECTED = 4
Const MSG_ERROR = 5
Const MSG_CLOSE = 6
Const GXS_WS_URL = "ws://localhost:8080/"
Const GXS_URL = "http://localhost:8080/v0"
'Const GXS_WS_URL = "wss://gxapi.boxgaming.co/"
'Const GXS_URL = "https://gxapi.boxgaming.co/v0"
Const LB_URL = GXS_URL + "/lb"

' library exports
Export MSG_HOST_GAME As HOST_GAME, MSG_JOIN_GAME As JOIN_GAME
Export MSG_CLIENT_DISCONNECTED As CLIENT_DISCONNECTED, MSG_HOST_DISCONNECTED As HOST_DISCONNECTED
Export MSG_ERROR As ERROR, MSG_CLOSE As CLOSE
Export HostGame, JoinGame, LeaveGame, SendMessage, SendHostMessage, RegisterEvent, IsHost, SessionId, ClientId
Export LBGet As LeaderboardGet, LBAdd As LeaderboardUpdate, LBCreate As LeaderboardCreate, LBRestrict As LeaderboardRestrict

Dim Shared websocket As Object
Dim Shared As String sid, cid
Dim Shared As Integer mode
Dim Shared eventMap()

Sub HostGame
    Connect MSG_HOST_GAME
End Sub

Sub JoinGame (ssid As String, pname As String)
    sid = ssid
    Connect MSG_JOIN_GAME
End Sub

Sub SendHostMessage (mtype As Integer, msg As Object)
    SendMessage mtype, msg, "HOST"
End Sub

Sub SendMessage (mtype As Integer, msg As Object, toCid As String)
    Dim m As Object
    m.type = mtype
    m.sid = sid
    m.cid = cid
    m.data = msg
    m.to = toCid
    Send m
End Sub

Sub OnOpen 
    Dim msg As Object
    msg.type = mode
    msg.sid = sid
    Send msg
End Sub

Sub OnClose (e As Object)
    If eventMap(MSG_CLOSE) Then
        Dim callback As Sub
        callback = eventMap(MSG_ERROR)
        callback e
    End If
End Sub

Sub OnError (e As Object)
    If eventMap(MSG_ERROR) Then
        Dim callback As Sub
        callback = eventMap(MSG_ERROR)
        callback e
    End If
End Sub

Sub OnMessage (msg As Object)
    If msg.type = MSG_HOST_GAME Then
        sid = msg.sid
        cid = msg.cid

    ElseIf msg.type = MSG_JOIN_GAME Then
        If mode <> MSG_HOST_GAME Then cid = msg.cid

    ElseIf msg.type = MSG_HOST_DISCONNECTED Then
        If cid = msg.hid Then
            mode = HOST
        Else
            mode = CLIENT
        End If
    End If
    If eventMap(msg.type) Then
        Dim callback As Sub
        callback = eventMap(msg.type)
        callback msg
    End If
End Sub

Sub Send (msg As Object)
$If Javascript Then
    websocket.send(JSON.stringify(msg));
$End If
End Sub

Sub LeaveGame (code, reason)
$If Javascript Then
    websocket.close(code, reason);
$End If
End Sub

Sub Connect (cmode As Integer)
    mode = cmode
    
    Dim As Sub o, e, m, c
    o = @OnOpen
    e = @OnError
    m = @OnMessage
    c = @OnClose
    
$If Javascript Then
    websocket = new WebSocket(GXS_WS_URL);
    websocket.addEventListener("open", o);
    websocket.addEventListener("close", c);
    websocket.addEventListener("error", e);
    websocket.addEventListener("message", function(e) {
        m(JSON.parse(e.data)); 
    });
$End If
End Sub

Sub RegisterEvent (etype As Integer, callback As Sub)
    eventMap(etype) = callback    
End Sub

Function IsHost
    If mode = HOST Then
        IsHost = -1
    Else
        IsHost = 0
    End If
End Function

Function SessionId
    SessionId = sid
End Function

Function ClientId
    ClientId = cid
End Function


' -------------------------------------------------------------------------
' Leaderboard methods
' -------------------------------------------------------------------------

Function LBCreate 
    Dim res As Object
    res = Fetch(LB_URL + "/register")
    LBCreate = res.text
End Function

Function LBRestrict (did As String, gid As String, restrict As String)
    Dim As Object r
$If Javascript Then
    r = await fetch(LB_URL + "/restrict", {
        method: "GET",
        headers: { 
            "X-DID": did,
            "X-GID": gid,
            "X-Restrict-To": restrict
        }});
$End If
    LBRestrict = r.status
End Function


Function LBGet (id As String, results() As Object)
    Dim As Object r, scores, s
    Dim As Integer i
$If Javascript Then
    r = await fetch(LB_URL, {
        method: "GET",
        headers: { 
            "Content-Type": "application/json",
            "X-GID": id
        }});
    if (r.status == 200) {
        scores = await r.json();
$End If
        ReDim results(scores.length) As Object
$If Javascript Then
        for (i=0; i < scores.length; i++) {
            s = scores[i];
            var d = new Date(s.ts);
            s.date = d.toLocaleDateString();
            s.time = d.toLocaleTimeString();
$End If
            results(i+1) = s
$If Javascript Then
        }
    }    
$End If
    LBGet = r.status
End Sub

Function LBAdd (id As String, score As Integer, pname As String)
    Dim s As Object
    s.score = score
    s.name = pname
$If Javascript Then
    r = await fetch(LB_URL, {
        method: "POST",
        headers: { 
            "Content-Type": "application/json",
            "X-GID": id
        },
        body: JSON.stringify(s)});
$End If
    LBAdd = r.status
End Function