Import Dom From "lib/web/dom.bas"
Import GXS From "https://gxapi.boxgaming.co/v0/gxs.bas"
Import String From "lib/lang/string.bas"
Option Explicit

Const MSG_CHAT = 500
Const MODE_HOST = 1, MODE_JOIN = 2
Const MB_OK = 1, MB_OKCANCEL = 2, MB_YESNO = 3
Const EVENT_HOST_GAME = 1, EVENT_JOIN_GAME = 2
Const UI_HEIGHT = 200, UI_WIDTH = 400
Const DOCK_BOTTOM = 0, DOCK_RIGHT = 1
Const CHAT_ENABLED = 0, CHAT_DISABLED = 1, RESIZE_ENABLED = 0, RESIZE_DISABLED = -1
Export MSG_CHAT, MB_OK, MB_OKCANCEL, MB_YESNO
Export EVENT_HOST_GAME, EVENT_JOIN_GAME
Export DOCK_BOTTOM, DOCK_RIGHT, CHAT_ENABLED, CHAT_DISABLED, RESIZE_ENABLED, RESIZE_DISABLED
Export FocusChat, ShowInviteDialog, ShowHostGameDialog, ShowGameListDialog
Export ShowMessageBox, PutMessage, PutChat As PutChatMessage, RegisterEvent
Export InitUI As Init, SetDockMode

Dim Shared As Object lblLog, txtChat, btnDock, dlgInvite, txtGameId
Dim Shared As Object dlgMsgBox, lblMsgBox, btnMsgBoxOk, btnMsgBoxCancel
Dim Shared As Object dlgStartGame, txtJoinGameId, txtPlayerName, gameIdPanel
Dim Shared As Object dlgGameList, grpGameList, grpGameDesc, txtGameDesc
Dim Shared As Integer dockMode, startGameMode, chatting, disableResize
Dim Shared As Sub fnMsgBoxOk, fnMsgBoxCancel
Dim Shared eventMap()

Sub RegisterEvent (eventId As Integer, fnCallback As Sub)
    eventMap(eventId) = fnCallback
End Sub

Sub ShowInviteDialog
    txtGameId.value = GXS.SessionId
    Dom.Focus txtGameId
    Dom.SelectAll txtGameId
    Dom.DialogShowModal dlgInvite
End Sub

Function IsChatting
    IsChatting = chatting
End Function
    
Sub FocusChat
    Dom.Focus txtChat
    chatting = GX_TRUE
End Sub

Sub OnClickClose
    Dom.DialogClose dlgInvite
End Sub

Sub OnClickChat
    GXS.SendMessage MSG_CHAT, txtChat.value
    txtChat.value = ""
    Dom.Focus Dom.GetImage(0)
    chatting = GX_FALSE
End Sub

Sub OnKeydownChat (e As Object)
    Dom.StopPropagation e
    If e.key = "Enter" Then OnClickChat
End Sub

Sub OnLoseFocusChat (e As Object)
    chatting = GX_FALSE
End Sub

Sub OnKeydown (e As Object)
    Dom.StopPropagation e
End Sub

Sub OnKeydownStartGame (e As Object)
    Dom.StopPropagation e
    If e.key = "Enter" Then OnStartGameOk
End Sub

Sub PutMessage (text As String)
    Dim As Object ctext
    ctext = Dom.Create("div", lblLog)
    ctext.innerHTML = text
    lblLog.scrollTop = lblLog.scrollHeight 
End Sub

Sub PutChat (sender As String, text As String)
    PutMessage "<span class='sender'>" + sender + "</span>: " + Sanitize(text)
End Sub

Function Sanitize (text As String)
    text = String.Replace(text, "<", "&lt;")
    Sanitize = String.Replace(text, ">", "&gt;")
End Function

Sub OnMsgBoxOk
    Dom.DialogClose dlgMsgBox
    If fnMsgBoxOk Then fnMsgBoxOk
End Sub

Sub OnMsgBoxCancel
    Dom.DialogClose dlgMsgBox
    If fnMsgBoxCancel Then fnMsgBoxCancel
End Sub

Sub ShowHostGameDialog
    startGameMode = MODE_HOST
    gameIdPanel.style.display = "none"
    grpGameDesc.style.display = "block"
    Dom.DialogShowModal dlgStartGame
End Sub

Sub ShowJoinGameDialog
    startGameMode = MODE_JOIN
    gameIdPanel.style.display = "block"
    grpGameDesc.style.display = "none"
    Dom.DialogShowModal dlgStartGame
End Sub

Sub ShowGameListDialog (gameName As String)
    Dim i As Integer
    Dim games(0) As Object
    GXS.FindGames gameName, games()
    grpGameList.innerHTML = ""
    For i = 1 To UBound(games)
        Dim row As Object
        row = Dom.Create("div", grpGameList)
        row.className = "gl-row"
        row.sid = games(i).sid
        Dom.Event row, "click", @OnClickGLRow
        
        Dim cell As Object
        Dom.Create "div", row, games(i).name
        Dom.Create "div", row, games(i).desc
        cell = Dom.Create("div", row, games(i).clients)
        cell.className = "gl-cell-players"
        Dom.Create "div", row, games(i).sdate + " " + games(i).stime 
    Next i
    Dom.DialogShowModal dlgGameList
End Sub

Sub OnClickGLRow (event As Object)
    Dim sid As String
    sid = event.target.parentNode.sid
    txtJoinGameId.value = sid
    Dom.DialogClose dlgGameList
    ShowJoinGameDialog
    Dom.Focus txtPlayerName
End Sub

Sub OnGameListCancel
    Dom.DialogClose dlgGameList
End Sub

Sub OnJoinPrivate
    Dom.DialogClose dlgGameList
    txtJoinGameId.value = ""
    ShowJoinGameDialog
End Sub

Sub OnStartGameOk
    Dim As String gameId, playerName
    playerName = Trim$(txtPlayerName.value)
    gameId = Trim$(txtJoinGameId.value)
    
    If startGameMode = MODE_JOIN Then
        If gameId = "" Or playerName = "" Then
            ShowMessageBox "Game ID and player name are required."
        Else
            If eventMap(EVENT_JOIN_GAME) Then
                Dim callback As Sub
                callback = eventMap(EVENT_JOIN_GAME)
                callback playerName, gameId
            End If
            Dom.DialogClose dlgStartGame
        End If
    Else
        If playerName = "" Then
            ShowMessageBox "Please enter a player name."
        Else
            If eventMap(EVENT_HOST_GAME) Then
                Dim callback As Sub
                callback = eventMap(EVENT_HOST_GAME)
                callback playerName, Trim$(txtGameDesc.value)
            End If
            Dom.DialogClose dlgStartGame
        End If
    End If
End Sub

Sub OnStartGameCancel
    Dom.DialogClose dlgStartGame
End Sub

Sub ShowMessageBox (text As String, mbStyle, fnCallbackOk As Sub, fnCallbackCancel As Sub)
    If mbStyle = undefined Then mbStyle = MB_OK
    
    lblMsgBox.innerHTML = text
    
    If mbStyle = MB_OK Then
        btnMsgBoxOk.innerText = "OK"
        btnMsgBoxCancel.style.display = "none"
        
    ElseIf mbStyle = MB_OKCANCEL Then
        btnMsgBoxOk.innerText = "OK"
        btnMsgBoxCancel.display = "inline"
        btnMsgBoxCancel.innerText = "Cancel"
    
    ElseIf mbStyle = MB_YESNO Then
        btnMsgBoxOk.innerText = "Yes"
        btnMsgBoxCancel.display = "inline"
        btnMsgBoxCancel.innerText = "No"
        
    End If
    fnMsgBoxOk = fnCallbackOk
    fnMsgBoxCancel = fnCallbackCancel
    Dom.DialogShowModal dlgMsgBox
End Sub

Sub OnClickCanvas (e As Object)
    Dom.Focus e.target
End Sub

Function GetCSS
    Open "https://boxgaming.github.io/gx-server/lib/ui/ui.css" For Binary As #1
    Dim css As String
    css = Space(LOF(1))
    Get #1, , css
    GetCSS = css
End Function

Sub InitUI (dmode, chatMode, resizeMode)
    If dmode <> undefined Then dockMode = dmode
    If resizeMode <> undefined Then disableResize = resizeMode
    
    Dim As Object parent, panel, lblChat, btnSend, canvas, style, container
    style = Dom.Create("style", window.document.head)
    style.innerText = GetCSS
    canvas = Dom.GetImage(0)
    canvas.tabIndex = 1
    Dom.Event canvas, "click", @OnClickCanvas
    If disableResize Then
        Dim As Object wrapper
        wrapper = Dom.Create("div")
        wrapper.style.overflow = "auto"
        Dom.Add canvas, wrapper
    End If
    
    container = Dom.Container()
    container.style.display = "grid"
    If dockMode = DOCK_RIGHT Then
        container.style.gridTemplateColumns = "auto " + UI_WIDTH + "px"
        container.style.gridTemplateRows = ""
    Else
        container.style.gridTemplateRows = "auto " + UI_HEIGHT + "px"
        container.style.gridTemplateColumns = ""
    End If
    container.style.overflow = "hidden"
    
    parent = Dom.Create("div")
    panel = Dom.Create("div", parent)
    If chatMode = CHAT_DISABLED Then
        ' leave this panel empty
    Else
        panel.id = "chat-input-panel"
        lblChat = Dom.Create("span", panel, "Chat:")
        txtChat = Dom.Create("input", panel)
        btnSend = Dom.Create("button", panel, "Send")
        btnDock = Dom.Create("a", panel, " ")
        Dom.Event btnDock, "click", @OnChangeDock
        Dom.Event txtChat, "keydown", @OnKeydownChat
        Dom.Event txtChat, "blur", @OnLoseFocusChat
        Dom.Event btnSend, "click", @OnClickChat
    End If
    parent.id = "game-ui"
    If dockMode = DOCK_RIGHT Then
        parent.className = "dock-right"
        btnDock.className = "dock-bottom"
    Else
        btnDock.className = "dock-right"
    End If
    
    lblLog = Dom.Create("div", parent)
    lblLog.id = "log"
    
    Dim As Object dpanel, btnClose
    dlgInvite = Dom.Create("dialog")
    dlgInvite.id = "dlg-invite"
    Dom.Create "span", dlgInvite, "Share the following game id to invite others to join:"
    dpanel = Dom.Create("div", dlgInvite)
    dpanel.className = "grp-panel"
    txtGameId = Dom.Create("input", dpanel)
    txtGameId.readOnly = true
    btnClose = Dom.Create("button", dlgInvite, "Close")
    Dom.Event txtGameId, "keydown", @OnKeydown 
    Dom.Event btnClose, "keydown", @OnKeydown 
    Dom.Event btnClose, "click", @OnClickClose
    
    Dim As Object btnOk, btnCancel
    dlgMsgBox = Dom.Create("dialog")
    dlgMsgBox.id = "dlg-message-box"
    lblMsgBox = Dom.Create("div", dlgMsgBox)
    btnMsgBoxOk = Dom.Create("button", dlgMsgBox)
    btnMsgBoxCancel = Dom.Create("button", dlgMsgBox)
    btnMsgBoxCancel.className = "btn-cancel"
    Dom.Event btnMsgBoxOk, "keydown", @OnKeydown 
    Dom.Event btnMsgBoxCancel, "keydown", @OnKeydown 
    Dom.Event btnMsgBoxOk, "click", @OnMsgBoxOk
    Dom.Event btnMsgBoxCancel, "click", @OnMsgBoxCancel
    
    Dim As Object btnStartGameOk, btnStartGameCancel
    dlgStartGame = Dom.Create("dialog")
    dlgStartGame.id = "dlg-start-game"
    gameIdPanel = Dom.Create("div", dlgStartGame)
    gameIdPanel.className = "grp-panel"
    Dom.Create "div", gameIdPanel, "Enter the game id:"
    txtJoinGameId = Dom.Create("input", gameIdPanel)
    dpanel = Dom.Create("div", dlgStartGame)
    dpanel.style.marginBottom = "10px"
    Dom.Create "div", dpanel, "Enter your player name:"
    txtPlayerName = Dom.Create("input", dpanel)
    grpGameDesc = Dom.Create("div", dlgStartGame)
    grpGameDesc.className = "grp-panel"
    Dom.Create "div", grpGameDesc, "Enter game description (optional):"
    txtGameDesc = Dom.Create("input", grpGameDesc) 
    btnStartGameOk = Dom.Create("button", dlgStartGame, "OK")
    btnStartGameCancel = Dom.Create("button", dlgStartGame, "Cancel")
    btnStartGameCancel.className = "btn-cancel"
    Dom.Event txtJoinGameId, "keydown", @OnKeydownStartGame 
    Dom.Event txtPlayerName, "keydown", @OnKeydownStartGame 
    Dom.Event txtGameDesc, "keydown", @OnKeydownStartGame 
    Dom.Event btnStartGameOk, "keydown", @OnKeydown 
    Dom.Event btnStartGameCancel, "keydown", @OnKeydown 
    Dom.Event btnStartGameOk, "click", @OnStartGameOk
    Dom.Event btnStartGameCancel, "click", @OnStartGameCancel
    
    Dim As Object thead, btnCancel, btnJoinPrivate
    dlgGameList = Dom.Create("dialog")
    Dom.Create "div", dlgGameList, "Select a game to join:"
    thead = Dom.Create("div", dlgGameList)
    thead.className = "gl-head"
    Dom.Create "div", thead, "Game"
    Dom.Create "div", thead, "Description"
    Dom.Create "div", thead, "Players"
    Dom.Create "div", thead, "Start Time"
    grpGameList = Dom.Create("div", dlgGameList)
    grpGameList.id = "game-list-panel"
    btnJoinPrivate = Dom.Create("button", dlgGameList, "Join Private Game")
    btnCancel = Dom.Create("button", dlgGameList, "Cancel")
    btnCancel.className = "btn-cancel"
    Dom.Event btnJoinPrivate, "keydown", @OnKeydown 
    Dom.Event btnJoinPrivate, "click", @OnJoinPrivate
    Dom.Event btnCancel, "keydown", @OnKeydown 
    Dom.Event btnCancel, "click", @OnGameListCancel
    
    Dim win As Object
    $If Javascript Then
        win = window
    $End If
    Dom.Event win, "resize", @OnResize
    OnResize
End Sub

Sub OnChangeDock
    If dockMode = DOCK_RIGHT Then 
        SetDockMode DOCK_BOTTOM 
    Else 
        SetDockMode DOCK_RIGHT
    End If
End Sub

Sub SetDockMode (mode As Integer)
    Dim As Object container, parent
    container = Dom.Container
    parent = Dom.Get("game-ui")
    dockMode = mode
    If dockMode = DOCK_RIGHT Then
        container.style.gridTemplateColumns = "auto " + UI_WIDTH + "px"
        container.style.gridTemplateRows = ""
        parent.className = "dock-right"
        btnDock.className = "dock-bottom"
        btnDock.title = "Move to Bottom"
    Else
        container.style.gridTemplateRows = "auto " + UI_HEIGHT + "px"
        container.style.gridTemplateColumns = ""
        parent.className = "dock-bottom"
        btnDock.className = "dock-right"
        btnDock.title = "Move to Right"
    End If
    OnResize
End Sub

Sub OnResize
    If dockMode = DOCK_RIGHT Then
        If Not disableResize Then GXSceneWindowSize ResizeWidth - UI_WIDTH, ResizeHeight
        lblLog.style.height = (ResizeHeight - 36) + "px"
    Else
        If Not disableResize Then GXSceneWindowSize ResizeWidth, ResizeHeight - UI_HEIGHT
        lblLog.style.height = (UI_HEIGHT - 36) + "px"
    End If
End Sub