AddCSLuaFile()
AddCSLuaFile("gmperf/ELProfiler.lua")

GMperf = {} -- global
GMperf.ELProfiler = include("gmperf/ELProfiler.lua")
GMperf.ELProfiler.setClock(SysTime)

if SERVER then
  -- net strings
  util.AddNetworkString("gmperf_opencodegui")
  util.AddNetworkString("gmperf_runcode")
  util.AddNetworkString("gmperf_runcode_error")
  util.AddNetworkString("gmperf_sendconsole")
  -- Send message to player console (net limit).
  function GMperf.SendConsole(player, msg)
    net.Start("gmperf_sendconsole")
      net.WriteString(msg)
    net.Send(player)
  end
  local function runcode_error(player, err)
    net.Start("gmperf_runcode_error")
      net.WriteString(err)
    net.Send(player)
  end
  local function runcode(code, player)
    if IsValid(player) and player:IsPlayer() then
      code = "local runner = ...; "..code
      local f = CompileString(code, "gmperf_runcode/server", false)
      if type(f) == "function" then
        local ok, err = pcall(f, player)
        if not ok then runcode_error(player, err) end
      else runcode_error(player, f) end
    end
  end
  -- runcode handler
  net.Receive("gmperf_runcode",function(len, player)
    if player:IsSuperAdmin() then -- permission
      local code = net.ReadString()
      -- server-side
      runcode(code, player)
      -- client-side
      net.Start("gmperf_runcode")
        net.WriteString(code)
      net.Send(player)
    end
  end)
  -- command
  concommand.Add("gmperf", function(player, cmd, args)
    if player:IsSuperAdmin() then
      if args[1] == "codegui" then
        net.Start("gmperf_opencodegui")
          net.WriteBool(args[2] == "reset")
        net.Send(player)
      else
        player:PrintMessage(HUD_PRINTCONSOLE, [[usage:
  gmperf codegui [reset]
        ]])
      end
    end
  end)
elseif CLIENT then
  local function runcode_error(err)
    print(err)
    notification.AddLegacy("GMperf runcode error(s), see console.", NOTIFY_ERROR, 5)
  end
  local function runcode(code)
    code = "local runner = ...; "..code
    local f = CompileString(code, "gmperf_runcode/client", false)
    if type(f) == "function" then
      local ok, err = pcall(f, LocalPlayer())
      if not ok then runcode_error(err) end
    else runcode_error(f) end
  end
  -- client vgui
  local function open_codeGUI(reset)
    -- reset
    if reset and GMperf.codegui then
      GMperf.codegui_html:Remove()
      GMperf.codegui_run:Remove()
      GMperf.codegui:Remove()
      GMperf.codegui = nil
    end
    -- build
    if not GMperf.codegui then
      GMperf.codegui = vgui.Create("DFrame")
      GMperf.codegui_html = vgui.Create("DHTML", GMperf.codegui)
      GMperf.codegui_html:Dock(FILL)
      GMperf.codegui_html:AddFunction("gmperf", "runcode", function(code) 
        -- send code to server
        net.Start("gmperf_runcode")
          net.WriteString(code)
        net.SendToServer()
        -- save code for the client
        LocalPlayer():SetPData("gmperf_runcode_save", code)
      end)
      GMperf.codegui_html:AddFunction("gmperf", "getsave", function() 
        -- return saved code
        return LocalPlayer():GetPData("gmperf_runcode_save","")
      end)
      -- window
      GMperf.codegui:SetSize(600, 450)
      GMperf.codegui:SetTitle("GMperf runcode")
      GMperf.codegui:SetVisible(true)
      GMperf.codegui:SetDraggable(true)
      GMperf.codegui:SetSizable(true)
      GMperf.codegui:SetDeleteOnClose(false)
      GMperf.codegui:Center()
      -- button
      GMperf.codegui_run = vgui.Create("DButton")
      GMperf.codegui_run:SetPos(100, 5)
      GMperf.codegui_run:SetParent(GMperf.codegui)
      GMperf.codegui_run:SetText("run")
      GMperf.codegui_run:SetSize(30,15)
      function GMperf.codegui_run.DoClick()
        GMperf.codegui_html:Call("onruncode()")
      end
      GMperf.codegui_html:SetHTML([[
<!DOCTYPE html>
<html lang="en">
<head>
<title>GMperf runcode</title>
<style type="text/css" media="screen">
    #editor { 
        position: absolute;
        top: 0;
        right: 0;
        bottom: 0;
        left: 0;
    }
</style>
</head>
<body>

<div id="editor">
if SERVER then
  runner:ChatPrint("server-side")
elseif CLIENT then
  runner:ChatPrint("client-side")
end
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.2.5/ace.js" type="text/javascript" charset="utf-8"></script>
<script>
    editor = ace.edit("editor");
    editor.setTheme("ace/theme/monokai");
    editor.getSession().setMode("ace/mode/lua");

    function onruncode(){ gmperf.runcode(editor.getValue()); }

    var save = gmperf.getsave();
    if(save.length > 0)
      editor.setValue(save);
</script>

</body>
</html>
      ]])
    end
    GMperf.codegui:MakePopup()
    GMperf.codegui:SetVisible(true)
  end
  -- runcode handlers
  net.Receive("gmperf_opencodegui", function(len, player)
    open_codeGUI(net.ReadBool())
  end)
  net.Receive("gmperf_runcode", function(len, player)
    runcode(net.ReadString())
  end)
  net.Receive("gmperf_runcode_error", function(len, player)
    runcode_error(net.ReadString())
  end)
  net.Receive("gmperf_sendconsole", function(len, player)
    print(net.ReadString())
  end)
end
