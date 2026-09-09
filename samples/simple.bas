Import GXS From "https://gxapi.boxgaming.co/v0/gxs.bas"
Import Console From "lib/web/console.bas"
Import Dom From "lib/web/dom.bas"
Import JSArray From "lib/lang/array.bas"
Import Sys From "lib/lang/system.bas"
Import Gfx From "lib/graphics/2d.bas"

Const PLAYER_SPEED = 100
' IDs 1-1000 are reserved for the engine, so use values greater than 1000
' for game specific message ids
Const MSG_CTRL_STATE = 1001, MSG_UPDATE_PLAYERS = 1002

Type ControlState
    As Integer w,a,s,d
End Type

Type Player
    As String cid
    As Integer eid, x, y, vx, vy, active
    cstate As ControlState
End Type

Dim Shared connecting As Integer
Dim Shared players(5) As Player
Dim Shared pmap() As Player

' Register methods to handle game events
GXS.RegisterEvent GXS.HOST_GAME, @OnHostGame
GXS.RegisterEvent GXS.JOIN_GAME, @OnJoinGame
GXS.RegisterEvent GXS.ERROR, @OnError
GXS.RegisterEvent GXS.CLIENT_DISCONNECTED, @OnClientDisconnected 
GXS.RegisterEvent GXS.HOST_DISCONNECTED, @OnHostDisconnected 
GXS.RegisterEvent MSG_CTRL_STATE, @OnCtrlState

GXSceneCreate 640, 480

InitPlayers
StartGame

Sub StartGame
    Dim opt As String
    While Not connecting
       Input "New Game - Would you like to (H)ost or (J)oin)? ", opt
       opt = Trim$(UCase$(opt))
       If opt = "H" Or "HOST" Then
           GXS.HostGame "Sample Game"
           connecting = GX_TRUE
       ElseIf opt = "J" or "JOIN" Then
           Dim sid As String
           sid = Dom.Prompt("Enter the game session id: ")
           GXS.JoinGame sid
           connecting = GX_TRUE
       End If
    Wend
End Sub

' Called when a new game is started by the host
Sub OnHostGame (msg As Object)
    Console.Echo "Game started with id: " + GXS.SessionId 
    connecting = GX_FALSE
    AddPlayer GXS.ClientId
    Sys.SetTimeout @SendPlayerUpdates, 16
    GXSceneStart
End Sub

' Called when a player joins a game
Sub OnJoinGame (msg As Object)
   If GXS.IsHost Then
        Console.Echo "New player joined with client id: " + msg.cid 
        AddPlayer msg.cid
    Else
        connecting = GX_FALSE
        Console.Echo "Joined game with client id: " + msg.cid
        GXS.RegisterEvent MSG_UPDATE_PLAYERS, @OnUpdatePlayers
        GXSceneStart
    End If
End Sub

' Called when a communication error occurs
Sub OnError (msg As Object)
    If connecting Then
        Console.Echo "An error occurred while attempting to connect to the game server."
        connecting = GX_FALSE
        StartGame
    Else
        Console.Echo "An unknown error occurred."
    End If 
End Sub

' Called when any client disconnects from the server
Sub OnClientDisconnected (msg As Object)
    Console.Echo "Client disconnected: " + msg.cid
    Dim p As Player
    p = pmap(msg.cid)
    p.active = GX_FALSE
End SUb

' Called when the game host disconnects from the server
Sub OnHostDisconnected (msg As Object)
    Console.Echo "Host has disconnected"
    GXSceneStop
    System
End Sub

' This method is called on the game host when player control input
' state has been sent from a client.
Sub OnCtrlState (msg As Object)
    Dim p As Player
    p = pmap(msg.cid)
    If p <> undefined Then
        p.cstate = msg.data
    End If
End Sub

Sub OnUpdatePlayers (msg As Object)
    Dim a: a = msg.data.players
    For i = 1 To JSArray.Length(a)
        Dim As Player p0, p1
        p1 = JSArray.Item(a, i-1)  
        p0 = pmap(p1.cid)  ' lookup the player by the client id
        If p1.cid <> "" AndAlso p0.eid = 0 Then        
            ' If the player is not in our list, add it
            AddPlayer p1.cid
            p0 = pmap(p1.cid)
        End If
        p0.active = p1.active
        If Not p0.active Then
            If p0.eid Then
                GXEntityVisible p0.eid, GX_FALSE
                GXEntityVX p0.eid, 0
                GXEntityVY p0.eid, 0
            End If
        Else 
            GXEntityPos p0.eid, p1.x, p1.y
            GXEntityVisible p0.eid, GX_TRUE
            GXEntityVX p0.eid, p1.vx
            GXEntityVY p0.eid, p1.vy
        End If     
    Next i
End Sub

' Handle regular GX game events
Sub GXOnGameEvent (e As GXEvent)
    Select Case e.event
        Case GXEVENT_UPDATE: OnUpdate e
        Case GXEVENT_COLLISION_ENTITY: OnEntityCollision e
    End Select
End Sub

Sub OnEntityCollision (e As GXEvent)
    If GXEntityVisible(e.collisionEntity) Then e.collisionResult = GX_TRUE
End Sub

Sub OnUpdate (e As GXEvent)
    If GXKeyDown(GXKEY_ESC) Then 
        GXS.LeaveGame
        Console.Echo "You've left the game"
        System
    End If
    
    ' Get the current state of the AWSD keys
    Dim cstate As ControlState
    cstate.a = GXKeyDown(GXKEY_A)
    cstate.s = GXKeyDown(GXKEY_S)
    cstate.w = GXKeyDown(GXKEY_W)
    cstate.d = GXKeyDown(GXKEY_D)
    ' If they've changed since the last frame, send a message to the host
    Dim player As Player
    player = pmap(GXS.ClientId)
    If PlayerInputChanged(player.cstate, cstate) Then
        GXS.SendHostMessage MSG_CTRL_STATE, cstate
        player.cstate = cstate
    End If
    
    If Not GXS.IsHost Then Exit Sub
    
    ' Handle player movement
    Dim i As Integer
    For i = 1 To UBound(players)
        Dim p As Player
        p = players(i)
        
        If Not p.active Then Continue
        
        ' If direction keys are pressed, move the player in the specified direction 
        If p.cstate.a Then
            GXEntityVX p.eid, -PLAYER_SPEED
        ElseIf p.cstate.d Then
            GXEntityVX p.eid, PLAYER_SPEED
        Else
            GXEntityVX p.eid, 0
        End If
        If p.cstate.w Then
            GXEntityVY p.eid, -PLAYER_SPEED
        ElseIf p.cstate.s Then
            GXEntityVY p.eid, PLAYER_SPEED
        Else
            GXEntityVY p.eid, 0
        End If
        
        ' Prevent the player from leaving the screen
        If GXEntityX(p.eid) < 0 Then GXEntityPos p.eid, 0, GXEntityY(p.eid)
        If GXEntityY(p.eid) < 0 Then GXEntityPos p.eid, GXEntityX(p.eid), 0
        If GXEntityX(p.eid) + GXEntityWidth(p.eid) > GXSceneWidth Then GXEntityPos p.eid, GXSceneWidth - GXEntityWidth(p.eid), GXEntityY(p.eid)
        If GXEntityY(p.eid) + GXEntityHeight(p.eid) > GXSceneHeight Then GXEntityPos p.eid, GXEntityX(p.eid), GXSceneHeight - GXEntityHeight(p.eid)
    Next i
End Sub

' Test to see whether any player inputs have changed from the previous state
Function PlayerInputChanged(cs1, cs2)
    Dim As Integer changed 
    If cs1 = undefined Then: changed = GX_TRUE
    ElseIf cs1.a <> cs2.a Then: changed = GX_TRUE 
    ElseIf cs1.s <> cs2.s Then: changed = GX_TRUE 
    ElseIf cs1.w <> cs2.w Then: changed = GX_TRUE 
    ElseIf cs1.d <> cs2.d Then: changed = GX_TRUE 
    End If
    PlayerInputChanged = changed
End Function

' This method sends game updates out to all clients on a timer.
Sub SendPlayerUpdates
    ' Create a parent object to use as the update message
    Dim msg As Object
    
    ' Get the server timestamp to use for client timing synchronization
    msg.ts = Sys.TimeInMillis
     
    ' Add the state of all players
     msg.players = JSArray.Create
     Dim i As Integer
     For i = 1 To UBound(players)
         Dim p As Player
         p.active = players(i).active
         p.cid = players(i).cid
         If players(i).active Then
             p.x = GXEntityX(players(i).eid)
             p.y = GXEntityY(players(i).eid)
             p.vx = GXEntityVX(players(i).eid)
             p.vy = GXEntityVY(players(i).eid)
             p.cstate = players(i).cstate
         End If
         JSArray.Push msg.players, p
     Next i
        
     ' Sent the message to the server, which will in turn send it 
     ' out to each game client
     GXS.SendMessage MSG_UPDATE_PLAYERS, msg
        
    If Sys.IsRunning Then
        Sys.SetTimeout @SendPlayerUpdates, 16
    Else
        GXS.LeaveGame
        Console.Echo "You have left the game."
    End If
End Sub

Sub AddPlayer (clientId)
    Dim i As Integer
    For i = 1 To UBound(players)
        If Not players(i).active Then
            players(i).active = GX_TRUE
            players(i).cid = clientId
            ' Place the new player in a random location on the screen
            GXEntityPos players(i).eid, Rnd*GXSceneWidth, Rnd* GXSceneHeight
            GXEntityVisible players(i).eid, GX_TRUE
            ' Add entries to the player map so we can look them up
            ' by either the client id or entity id
            pmap(clientId) = players(i)
            pmap(players(i).eid) = players(i)
            Exit Sub
        End If
    Next i
End Sub

Sub InitPlayers
    ' Rather than importing any game art assets, we'll just draw some rounded
    ' rectangles to use as our player sprites
    Dim As Integer clr, i, img
    clr = 15
    img = NewImage(32, 32, 32)
    Dest img
    For i = 1 To UBound(players)
        Cls , RGBA(255, 255, 255, 0)
        Gfx.FillRoundRect 1, 1, 30, 30, 5, clr
        Gfx.SaveImage img, "player.png"
        clr = clr - 1
        players(i).eid = GXEntityCreate("player.png", 32, 32, 1)
        GXEntityVisible players(i).eid, GX_FALSE
    Next i
    Kill "player.png"
    Dest 0
End Sub