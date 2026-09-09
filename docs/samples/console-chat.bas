Import GXS From "https://gxapi.boxgaming.co/v0/gxs.bas"
Import Console From "lib/web/console.bas"
Import Dom From "lib/web/dom.bas"

' IDs 1-1000 are reserved for the engine, so use values greater than 1000
' for game specific message ids
Const MSG_CHAT = 1001

Type ChatMessage
    name As String
    text As String
End Type

Dim Shared connecting As Integer

' Register methods to handle game events
GXS.RegisterEvent GXS.HOST_GAME, @OnHostGame
GXS.RegisterEvent GXS.JOIN_GAME, @OnJoinGame
GXS.RegisterEvent GXS.ERROR, @OnError
GXS.RegisterEvent GXS.CLIENT_DISCONNECTED, @OnClientDisconnected 
GXS.RegisterEvent GXS.HOST_DISCONNECTED, @OnHostDisconnected 
GXS.RegisterEvent MSG_CHAT, @OnChat

Dim chatMsg As ChatMessage
Input "What is your chat name? ", chatMsg.name
StartGame

Do
    Cls
    Locate 3, 2
    Input "CHAT: ", chatMsg.text
    chatMsg.text = Trim(chatMsg.text)
    If chatMsg.text <> "" Then 
        ' Any custom type or object can be used for user-defined messages
        GXS.SendMessage MSG_CHAT, chatMsg
    End If
Loop

Sub StartGame
    Dim opt As String
    While Not connecting
       Input "New Game - Would you like to (H)ost or (J)oin)? ", opt
       opt = Trim$(UCase$(opt))
       If opt = "H" Or "HOST" Then
           GXS.HostGame "Console Chat"
           connecting = GX_TRUE
       ElseIf opt = "J" or "JOIN" Then
           Dim sid As String
           sid = Dom.Prompt("Enter the game session id: ")
           GXS.JoinGame sid
           connecting = GX_TRUE
       End If
    Wend
End Sub

' Called when a chat message has been received from the server
Sub OnChat (msg As Object)
    ' The msg.data will contain the same user-defined type that was sent in the GXS.SendMessage call
    Dim chatMsg As ChatMessage
    chatMsg = msg.data
    Console.Echo chatMsg.name + ": " + chatMsg.text
End Sub

' Called when a new game is started by the host
Sub OnHostGame (msg As Object)
    Console.Echo "Game started with id: " + GXS.SessionId 
    result = Dom.Prompt("Game started. Copy the id to share with other players:", GXS.SessionId)
    connecting = GX_FALSE
End Sub

' Called when a player joins a game
Sub OnJoinGame (msg As Object)
   If GXS.IsHost Then
        Console.Echo "New player joined with client id: " + msg.cid 
    Else
        connecting = GX_FALSE
        Console.Echo "Joined game with client id: " + msg.cid
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
End SUb

' Called when the game host disconnects from the server
Sub OnHostDisconnected (msg As Object)
    Console.Echo "Host has disconnected"
    System
End Sub