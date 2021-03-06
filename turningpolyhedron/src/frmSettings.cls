VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "frmSettings"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

Private m_nAdapterModeCount As Long
Private m_tAdapterModes() As D3DDISPLAYMODE '0-based

Private m_nFSAAMode As Long

'control index
Private m_idx(127) As Long

Private Enum enumSettingsDialogControls
 IDC_Main = 0
 IDC_Resolution
 IDC_Fullscreen
 IDC_VSync
 IDC_MaxFPSEnabled
 IDC_MaxFPS
 IDC_Antialiasing
 IDC_PostProcess
 IDC_HDRBlurQuality
 IDC_ShadowMap
 IDC_Fog
 IDC_VolumetricFog
 IDC_DepthOfField
 IDC_RadialBlur
 IDC_ShowFPS
 IDC_ShaderEnabled
End Enum

'config file name
Private m_sFileName As String

Implements IFakeDXUIEvent

Friend Property Get FileName() As String
FileName = m_sFileName
End Property

Friend Property Let FileName(ByVal s As String)
m_sFileName = s
End Property

'TODO:other
Friend Sub LoadFile()
On Error Resume Next
Dim b As Boolean
Dim obj As New clsTreeStorageNode
'///
With New clsXMLSerializer
 .LoadNodeFromFile m_sFileName, obj
End With
'///
With obj.GetSubNodeObjectByName("GraphicsConfig", True)
 d3dpp.BackBufferWidth = Val(.GetSubNodeValueAsStringByName("Width", 640))
 d3dpp.BackBufferHeight = Val(.GetSubNodeValueAsStringByName("Height", 480))
 m_nRefreshRate = Val(.GetSubNodeValueAsStringByName("RefreshRate", 0))
 d3dpp.MultiSampleType = Val(.GetSubNodeValueAsStringByName("Antialiasing", 0))
 '///
 b = False
 b = CBool(.GetSubNodeValueAsStringByName("Fullscreen", False))
 d3dpp.Windowed = (b And 1&) Xor 1&
 If b Then d3dpp.FullScreen_RefreshRateInHz = m_nRefreshRate
 '///
 b = True
 b = CBool(.GetSubNodeValueAsStringByName("VSync", True))
 If b Then d3dpp.PresentationInterval = D3DPRESENT_INTERVAL_ONE _
 Else d3dpp.PresentationInterval = D3DPRESENT_INTERVAL_IMMEDIATE
 '///
 m_bShowFPS = CBool(.GetSubNodeValueAsStringByName("ShowFPS", True))
 m_bMaxFPSEnabled = CBool(.GetSubNodeValueAsStringByName("MaxFPSEnabled", True))
 m_nMaxFPS = Val(.GetSubNodeValueAsStringByName("MaxFPS", 30))
 If m_bMaxFPSEnabled And m_nMaxFPS > 0 Then objTiming.MinPeriod = 1000 / m_nMaxFPS _
 Else objTiming.MinPeriod = 0
 '///
 FakeDXAppShaderEnabled = CBool(.GetSubNodeValueAsStringByName("ShaderEnabled", True))
 FakeDXAppShaderEnabled_New = FakeDXAppShaderEnabled
 '///
 objRenderTest.PostProcessEnabled = CBool(.GetSubNodeValueAsStringByName("PostProcessEnabled", False))
 objRenderTest.HDRBlurQuality = Val(.GetSubNodeValueAsStringByName("HDRBlurQuality", 0))
 objRenderTest.ShadowEnabled = CBool(.GetSubNodeValueAsStringByName("ShadowMapEnabled", False))
 objRenderTest.FogEnabled = CBool(.GetSubNodeValueAsStringByName("FogEnabled", False))
 objRenderTest.VolumetricFogEnabled = CBool(.GetSubNodeValueAsStringByName("VolumetricFogEnabled", False))
 objRenderTest.DepthOfFieldType = Val(.GetSubNodeValueAsStringByName("DepthOfField"))
 objRenderTest.RadialBlurEnabled = CBool(.GetSubNodeValueAsStringByName("RadialBlurEnabled", False))
End With
'///
End Sub

'TODO:other
Friend Sub SaveFile()
Dim obj As New clsTreeStorageNode
'///
obj.SetNameFromString "Config"
With obj.GetSubNodeObjectByName("GraphicsConfig", True)
 .AddSubNode , , "Width", CStr(d3dpp.BackBufferWidth)
 .AddSubNode , , "Height", CStr(d3dpp.BackBufferHeight)
 .AddSubNode , , "RefreshRate", CStr(m_nRefreshRate)
 .AddSubNode , , "Fullscreen", CStr(d3dpp.Windowed = 0)
 .AddSubNode , , "VSync", CStr(d3dpp.PresentationInterval <> D3DPRESENT_INTERVAL_IMMEDIATE)
 .AddSubNode , , "ShowFPS", CStr(m_bShowFPS)
 .AddSubNode , , "MaxFPSEnabled", CStr(m_bMaxFPSEnabled)
 .AddSubNode , , "MaxFPS", CStr(m_nMaxFPS)
 .AddSubNode , , "Antialiasing", CStr(d3dpp.MultiSampleType)
 '///
 .AddSubNode , , "ShaderEnabled", CStr(FakeDXAppShaderEnabled_New)
 .AddSubNode , , "PostProcessEnabled", CStr(objRenderTest.PostProcessEnabled)
 .AddSubNode , , "HDRBlurQuality", CStr(objRenderTest.HDRBlurQuality)
 .AddSubNode , , "ShadowMapEnabled", CStr(objRenderTest.ShadowEnabled)
 .AddSubNode , , "FogEnabled", CStr(objRenderTest.FogEnabled)
 .AddSubNode , , "VolumetricFogEnabled", CStr(objRenderTest.VolumetricFogEnabled)
 .AddSubNode , , "DepthOfField", CStr(objRenderTest.DepthOfFieldType)
 .AddSubNode , , "RadialBlurEnabled", CStr(objRenderTest.RadialBlurEnabled)
End With
'///
With New clsXMLSerializer
 .SaveNodeToFile m_sFileName, obj
End With
End Sub

Friend Sub GetDXModes()
On Error Resume Next
Dim i As Long, j As Long
'///adapter modes
m_nAdapterModeCount = d3d9.GetAdapterModeCount(0, D3DFMT_X8R8G8B8)
If m_nAdapterModeCount > 0 Then
 ReDim m_tAdapterModes(m_nAdapterModeCount - 1)
 For i = 0 To m_nAdapterModeCount - 1
  d3d9.EnumAdapterModes 0, D3DFMT_X8R8G8B8, i, m_tAdapterModes(i)
 Next i
End If
'///FSAA modes
m_nFSAAMode = 0
j = 1
For i = 2 To 30
 Err.Clear
 '///
 d3d9.CheckDeviceMultiSampleType 0, D3DDEVTYPE_HAL, d3dpp.BackBufferFormat, 0, i
 d3d9.CheckDeviceMultiSampleType 0, D3DDEVTYPE_HAL, d3dpp.BackBufferFormat, 1, i
 '///
 d3d9.CheckDeviceMultiSampleType 0, D3DDEVTYPE_HAL, d3dpp.AutoDepthStencilFormat, 0, i
 d3d9.CheckDeviceMultiSampleType 0, D3DDEVTYPE_HAL, d3dpp.AutoDepthStencilFormat, 1, i
 '///
 If Err.Number = 0 Then m_nFSAAMode = m_nFSAAMode Or j
 '///
 j = j + j
Next i
End Sub

Friend Sub Create()
Dim i As Long, j As Long
Dim y As Long
Const Left As Long = 140
Const Right As Long = 328
Const Height As Long = 22
Const HeightStep As Long = 24
'///
If m_idx(0) Then Exit Sub
'///
GetDXModes
'///
'TODO:
'///
With FakeDXUIControls(1).AddNewChildren(FakeCtl_Form, 0, 0, _
400, 400, FFS_CloseButton Or FFS_Moveable Or FFS_TitleBar, , False, , objText.GetText("Options"))
 Set .EventObject = Me
 m_idx(IDC_Main) = .Index
 '///tab control
 With .AddNewChildren(FakeCtl_TabStrip, 8, 8, -8, -40, &H3003000, , , , , , , , , 1, 1)
  '///graphics
  y = 10
  With .AddNewChildren(FakeCtl_None, 0, 0, 340, 400, , , False)
   'resolution
   .AddNewChildren FakeCtl_Label, 10, y, 198, y + Height, , , , , objText.GetText("Resolution")
   With .AddNewChildren(FakeCtl_ComboBox, Left, y, Right, y + Height, FCS_CanGetFocus Or FCS_TabStop, _
   , , , , , , , , , , , , objText.GetText("Change the screen resolution."))
    m_idx(IDC_Resolution) = .Index
    With .ListViewObject
     .FullRowSelect = True
     .AddColumn ""
     For i = 0 To m_nAdapterModeCount - 1
      .AddItem CStr(m_tAdapterModes(i).Width) + "x" + CStr(m_tAdapterModes(i).Height) + "," + CStr(m_tAdapterModes(i).RefreshRate) + "Hz"
     Next i
    End With
   End With
   y = y + HeightStep
   'fullscreen?
   With .AddNewChildren(FakeCtl_Button, 10, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, , , , _
   objText.GetText("Fullscreen"), , , , , , , , , objText.GetText("Determines whether the program should run in full screen mode."))
    m_idx(IDC_Fullscreen) = .Index
   End With
   y = y + HeightStep
   'VSync?
   With .AddNewChildren(FakeCtl_Button, 10, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, , , , _
   objText.GetText("Vertical synchronization"), , , , , , , , , objText.GetText("Enables vertical synchronization."))
    m_idx(IDC_VSync) = .Index
   End With
   y = y + HeightStep
   'show FPS?
   With .AddNewChildren(FakeCtl_Button, 10, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, , , , _
   objText.GetText("Show statistics"), , , , , , , , , objText.GetText("Show statistics about graphics, for example FPS, etc.") + " (F11)")
    m_idx(IDC_ShowFPS) = .Index
   End With
   y = y + HeightStep
   'max FPS?
   With .AddNewChildren(FakeCtl_Button, 10, y, Left - 2, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, , , , _
   objText.GetText("Max FPS"), , , , , , , , , objText.GetText("Enables the restriction of max FPS."))
    m_idx(IDC_MaxFPSEnabled) = .Index
   End With
   With .AddNewChildren(FakeCtl_TextBox, Left, y, Right, y + Height, FTS_NumberOnly Or FTS_UpDown Or FCS_CanGetFocus Or FCS_TabStop, _
   , , , , , , , , , , , , objText.GetText("Max FPS"))
    m_idx(IDC_MaxFPS) = .Index
    .SmallChange = 1
   End With
   y = y + HeightStep
   'antialiasing?
   .AddNewChildren FakeCtl_Label, 10, y, 198, y + Height, , , , , objText.GetText("Antialiasing")
   With .AddNewChildren(FakeCtl_ComboBox, Left, y, Right, y + Height, FCS_CanGetFocus Or FCS_TabStop, _
   , , , , , , , , , , , , objText.GetText("Change the antialiasing settings."))
    m_idx(IDC_Antialiasing) = .Index
    With .ListViewObject
     .FullRowSelect = True
     .AddColumn ""
     .AddItem objText.GetText("Off")
     j = 1
     For i = 2 To 30
      If m_nFSAAMode And j Then
       .AddItem CStr(i) + "x", , i
      End If
      j = j + j
     Next i
    End With
   End With
   y = y + HeightStep
   'shader?
   With .AddNewChildren(FakeCtl_Button, 10, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, FakeDXAppShaderAvaliable, , , _
   objText.GetText("Use shader (require restart)"), , , , , , , , , objText.GetText("Use shader support of video card to perform advanced grapical effects. You need to restart the game to apply changes."))
    m_idx(IDC_ShaderEnabled) = .Index
   End With
   y = y + HeightStep
   'shadow map?
   With .AddNewChildren(FakeCtl_Button, 10, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, False, , , _
   objText.GetText("Shadow"), , , , , , , , , objText.GetText("Enables shadow effect."))
    m_idx(IDC_ShadowMap) = .Index
   End With
   y = y + HeightStep
   'post process?
   With .AddNewChildren(FakeCtl_Button, 10, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, FakeDXAppShaderEnabled, , , _
   objText.GetText("Post process"), , , , , , , , , objText.GetText("Enables post process effects."))
    m_idx(IDC_PostProcess) = .Index
   End With
   y = y + HeightStep
   'HDR blur quality
   .AddNewChildren FakeCtl_Label, 20, y, 198, y + Height, , , , , objText.GetText("HDR quality")
   With .AddNewChildren(FakeCtl_ComboBox, Left, y, Right, y + Height, FCS_CanGetFocus Or FCS_TabStop, _
   FakeDXAppShaderEnabled, , , , , , , , , , , , objText.GetText("Set the quality of HDR blur."))
    m_idx(IDC_HDRBlurQuality) = .Index
    With .ListViewObject
     .FullRowSelect = True
     .AddColumn ""
     .AddItem objText.GetText("Low")
     .AddItem objText.GetText("Medium")
     .AddItem objText.GetText("High")
    End With
   End With
   y = y + HeightStep
   'fog?
   With .AddNewChildren(FakeCtl_Button, 20, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, FakeDXAppShaderEnabled, , , _
   objText.GetText("Fog"), , , , , , , , , objText.GetText("Enables fog effect."))
    m_idx(IDC_Fog) = .Index
   End With
   y = y + HeightStep
   'volumetric fog?
   With .AddNewChildren(FakeCtl_Button, 30, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, FakeDXAppShaderEnabled, , , _
   objText.GetText("Volumetric fog"), , , , , , , , , objText.GetText("Enables volumetric fog effect."))
    m_idx(IDC_VolumetricFog) = .Index
   End With
   y = y + HeightStep
   'DOF?
   .AddNewChildren FakeCtl_Label, 20, y, 198, y + Height, , , , , objText.GetText("Depth of field")
   With .AddNewChildren(FakeCtl_ComboBox, Left, y, Right, y + Height, FCS_CanGetFocus Or FCS_TabStop, _
   FakeDXAppShaderEnabled, , , , , , , , , , , , objText.GetText("Enables depth of field effect."))
    m_idx(IDC_DepthOfField) = .Index
    With .ListViewObject
     .FullRowSelect = True
     .AddColumn ""
     .AddItem objText.GetText("Off")
     .AddItem objText.GetText("Approximate algorithm")
     .AddItem objText.GetText("Accurate algorithm")
    End With
   End With
   y = y + HeightStep
   'radial blur?
   With .AddNewChildren(FakeCtl_Button, 20, y, 198, y + Height, FBS_CheckBox Or FCS_CanGetFocus Or FCS_TabStop, FakeDXAppShaderEnabled, , , _
   objText.GetText("Radial blur"), , , , , , , , , objText.GetText("Enables radial blur effect."))
    m_idx(IDC_RadialBlur) = .Index
   End With
   y = y + HeightStep
   '///new:video capture options
   If FakeDXAppVideoCaptureEnabled Then
    .AddNewChildren FakeCtl_Button, 10, y, -10, y + Height, FCS_CanGetFocus Or FCS_TabStop, , , , _
    objText.GetText("Video capture options"), , "cmdVideoCapture", , , 1, , , , _
    objText.GetText("Change the video capture options.") + " (Ctrl+F9)"
   End If
   y = y + HeightStep
   '///over
   .SetBottomEx y + 8, 0
  End With
  '///game
  y = 10
  With .AddNewChildren(FakeCtl_None, 0, 0, 340, 100, , , False)
   .AddNewChildren FakeCtl_Label, 20, 20, 100, 40, , , , , "TODO:"
  End With
  '///
  With .TabObject
   .AddTab objText.GetText("Graphics"), , , , , objText.GetText("Change the graphics settings.")
   .AddTab objText.GetText("Game"), , , , , objText.GetText("Change the game settings.")
   .SelectedTab = 1
  End With
 End With
 '///buttons
 .AddNewChildren FakeCtl_Button, -192, -32, -136, -8, FBS_Default Or &H3000000, , , , _
 objText.GetText("OK"), , "cmdOK", 1, 1, 1, 1, , , objText.GetText("Apply changes and close dialog.")
 .AddNewChildren FakeCtl_Button, -128, -32, -72, -8, FBS_Cancel Or &H3000000, , , , _
 objText.GetText("Cancel"), , "cmdCancel", 1, 1, 1, 1, , , objText.GetText("Discard changes and close dialog.")
 .AddNewChildren FakeCtl_Button, -64, -32, -8, -8, &H3000000, , , , _
 objText.GetText("Apply"), , "cmdApply", 1, 1, 1, 1, , , objText.GetText("Apply changes immediately.")
End With
'///
'TODO:
End Sub

'TODO:read other settings
Friend Sub Show()
Dim idx As Long
Dim i As Long
'///
Create
'///
idx = m_idx(0)
If idx = 0 Then Exit Sub
'///graphics
'screen resolution
For i = 0 To m_nAdapterModeCount - 1
 If d3dpp.BackBufferWidth = m_tAdapterModes(i).Width And d3dpp.BackBufferHeight = m_tAdapterModes(i).Height Then
  If m_nRefreshRate = 0 Or m_nRefreshRate = m_tAdapterModes(i).RefreshRate Then
   FakeDXUIControls(m_idx(IDC_Resolution)).ListViewObject.SelectedRow = i + 1
   Exit For
  End If
 End If
Next i
'antialiasing
With FakeDXUIControls(m_idx(IDC_Antialiasing)).ListViewObject
 .SelectedRow = 0
 For i = 1 To .RowCount
  If d3dpp.MultiSampleType = .ItemData(i, 1) Then
   .SelectedRow = i
   Exit For
  End If
 Next i
End With
'fullscreen, etc.
FakeDXUIControls(m_idx(IDC_Fullscreen)).Value = (d3dpp.Windowed = 0) And 1&
FakeDXUIControls(m_idx(IDC_ShowFPS)).Value = m_bShowFPS And 1&
FakeDXUIControls(m_idx(IDC_MaxFPSEnabled)).Value = m_bMaxFPSEnabled And 1&
FakeDXUIControls(m_idx(IDC_MaxFPS)).Text = CStr(m_nMaxFPS)
FakeDXUIControls(m_idx(IDC_VSync)).Value = (d3dpp.PresentationInterval <> D3DPRESENT_INTERVAL_IMMEDIATE) And 1&
'///other
FakeDXUIControls(m_idx(IDC_ShaderEnabled)).Value = FakeDXAppShaderEnabled_New And 1&
FakeDXUIControls(m_idx(IDC_PostProcess)).Value = objRenderTest.PostProcessEnabled And 1&
FakeDXUIControls(m_idx(IDC_HDRBlurQuality)).ListViewObject.SelectedRow = objRenderTest.HDRBlurQuality + 1
'///
FakeDXUIControls(m_idx(IDC_ShadowMap)).Value = objRenderTest.ShadowEnabled And 1&
FakeDXUIControls(m_idx(IDC_Fog)).Value = objRenderTest.FogEnabled And 1&
FakeDXUIControls(m_idx(IDC_VolumetricFog)).Value = objRenderTest.VolumetricFogEnabled And 1&
FakeDXUIControls(m_idx(IDC_DepthOfField)).ListViewObject.SelectedRow = objRenderTest.DepthOfFieldType + 1
FakeDXUIControls(m_idx(IDC_RadialBlur)).Value = objRenderTest.RadialBlurEnabled And 1&
'///over
With FakeDXUIControls(idx)
 .MoveToCenter
 .Show 1
End With
End Sub

'TODO:
Friend Sub Hide()
Dim idx As Long
idx = m_idx(0)
If idx = 0 Then Exit Sub
'///
With FakeDXUIControls(idx)
 .Hide
End With
End Sub

'TODO:
Friend Sub Apply()
Dim i As Long
Dim w As Long, h As Long, r As Long
Dim nFull As Long
Dim nMultiSample As Long
Dim b As Boolean
'///
If m_idx(0) = 0 Then Exit Sub
'///graphics
'resolution
With FakeDXUIControls(m_idx(IDC_Resolution)).ListViewObject
 i = .SelectedRow
 If i > 0 And i <= m_nAdapterModeCount Then
  With m_tAdapterModes(i - 1)
   w = .Width
   h = .Height
   r = .RefreshRate
  End With
 End If
End With
'post processing
b = FakeDXUIControls(m_idx(IDC_PostProcess)).Value
'antialiasing
With FakeDXUIControls(m_idx(IDC_Antialiasing)).ListViewObject
 i = .SelectedRow
 If i > 0 And i <= .RowCount Then
  nMultiSample = .ItemData(i, 1)
  i = i - 1
 Else
  nMultiSample = d3dpp.MultiSampleType
  For i = .RowCount To 1 Step -1
   If .ItemData(i, 1) < nMultiSample Then Exit For
  Next i
 End If
 '///check if it is compatible with post processing
 On Error Resume Next
 If nMultiSample > 0 And i > 0 And b Then
  Do
   Err.Clear
   d3d9.CheckDeviceMultiSampleType 0, D3DDEVTYPE_HAL, D3DFMT_A32B32G32R32F, 0, nMultiSample
   d3d9.CheckDeviceMultiSampleType 0, D3DDEVTYPE_HAL, D3DFMT_A32B32G32R32F, 1, nMultiSample
   If Err.Number = 0 Then Exit Do
   .SelectedRow = i
   If i > 1 Then
    nMultiSample = .ItemData(i, 1)
    i = i - 1
   Else
    nMultiSample = 0
    Exit Do
   End If
  Loop
 End If
 On Error GoTo 0
 '///
End With
'fullscreen, etc.
nFull = FakeDXUIControls(m_idx(IDC_Fullscreen)).Value
If FakeDXUIControls(m_idx(IDC_VSync)).Value Then i = D3DPRESENT_INTERVAL_ONE _
Else i = D3DPRESENT_INTERVAL_IMMEDIATE
'apply
If w > 0 And h > 0 Then
 FakeDXAppChangeResolution w, h, nFull, r, nMultiSample, i
End If
'///other
m_bShowFPS = FakeDXUIControls(m_idx(IDC_ShowFPS)).Value
m_bMaxFPSEnabled = FakeDXUIControls(m_idx(IDC_MaxFPSEnabled)).Value
m_nMaxFPS = Val(FakeDXUIControls(m_idx(IDC_MaxFPS)).Text)
If m_bMaxFPSEnabled And m_nMaxFPS > 0 Then objTiming.MinPeriod = 1000 / m_nMaxFPS _
Else objTiming.MinPeriod = 0
'///
FakeDXAppShaderEnabled_New = FakeDXUIControls(m_idx(IDC_ShaderEnabled)).Value
objRenderTest.PostProcessEnabled = b
objRenderTest.HDRBlurQuality = FakeDXUIControls(m_idx(IDC_HDRBlurQuality)).ListViewObject.SelectedRow - 1
objRenderTest.ShadowEnabled = FakeDXUIControls(m_idx(IDC_ShadowMap)).Value
objRenderTest.FogEnabled = FakeDXUIControls(m_idx(IDC_Fog)).Value
objRenderTest.VolumetricFogEnabled = FakeDXUIControls(m_idx(IDC_VolumetricFog)).Value
objRenderTest.DepthOfFieldType = FakeDXUIControls(m_idx(IDC_DepthOfField)).ListViewObject.SelectedRow - 1
objRenderTest.RadialBlurEnabled = FakeDXUIControls(m_idx(IDC_RadialBlur)).Value
End Sub

Private Function IFakeDXUIEvent_OnEvent(ByVal obj As clsFakeDXUI, ByVal nType As Long, ByVal nParam1 As Long, ByVal nParam2 As Long, ByVal nParam3 As Long) As Long
Select Case nType
Case FakeCtl_Event_Click
 Select Case obj.Name
 Case "cmdApply"
  Apply
  SaveFile
 Case "cmdOK"
  Apply
  SaveFile
  Hide
 Case "cmdCancel"
  Hide
 Case "cmdVideoCapture"
  FakeDXAppShowVideoCaptureOptions
 End Select
Case FakeCtl_Event_Unload
 obj.Hide
 IFakeDXUIEvent_OnEvent = 1
End Select
End Function

Friend Sub ResetAndSaveFile()
d3dpp.BackBufferWidth = 640
d3dpp.BackBufferHeight = 480
d3dpp.Windowed = 1
d3dpp.MultiSampleType = 0
d3dpp.PresentationInterval = D3DPRESENT_INTERVAL_ONE
m_bMaxFPSEnabled = True
m_nMaxFPS = 30
m_nRefreshRate = 0
objRenderTest.PostProcessEnabled = False
'///
SaveFile
End Sub
