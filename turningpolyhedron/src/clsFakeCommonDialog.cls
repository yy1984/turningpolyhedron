VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsFakeCommonDialog"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

Private Declare Function GetLogicalDrives Lib "kernel32.dll" () As Long
Private Declare Function GetDriveType Lib "kernel32.dll" Alias "GetDriveTypeA" (ByVal nDrive As String) As Long
Private Declare Function GetVolumeInformation Lib "kernel32.dll" Alias "GetVolumeInformationA" (ByVal lpRootPathName As String, ByVal lpVolumeNameBuffer As String, ByVal nVolumeNameSize As Long, ByRef lpVolumeSerialNumber As Long, ByRef lpMaximumComponentLength As Long, ByRef lpFileSystemFlags As Long, ByVal lpFileSystemNameBuffer As String, ByVal nFileSystemNameSize As Long) As Long

Private Declare Function PathCombine Lib "shlwapi.dll" Alias "PathCombineA" (ByVal szDest As String, ByVal lpszDir As String, ByVal lpszFile As String) As Long

Private Declare Function SHGetSpecialFolderPath Lib "shell32.dll" Alias "SHGetSpecialFolderPathA" (ByVal hwnd As Long, ByVal pszPath As String, ByVal csidl As Long, ByVal fCreate As Long) As Long
Private Declare Function MakeSureDirectoryPathExists Lib "imagehlp.dll" (ByVal DirPath As String) As Long

Private Const CSIDL_PERSONAL As Long = &H5
Private Const CSIDL_DESKTOP As Long = &H0
Private Const CSIDL_DESKTOPDIRECTORY As Long = &H10

'////////unused :-3

Private Declare Function FindFirstFile Lib "kernel32.dll" Alias "FindFirstFileA" (ByVal lpFileName As String, ByRef lpFindFileData As WIN32_FIND_DATA) As Long
Private Declare Function FindFirstFileEx Lib "kernel32.dll" Alias "FindFirstFileExA" (ByVal lpFileName As String, ByVal fInfoLevelId As Long, ByRef lpFindFileData As WIN32_FIND_DATA, ByVal fSearchOp As Long, ByRef lpSearchFilter As Any, ByVal dwAdditionalFlags As Long) As Long
Private Declare Function FindNextFile Lib "kernel32.dll" Alias "FindNextFileA" (ByVal hFindFile As Long, ByRef lpFindFileData As WIN32_FIND_DATA) As Long
Private Declare Function FindClose Lib "kernel32.dll" (ByVal hFindFile As Long) As Long
Private Type WIN32_FIND_DATA
    dwFileAttributes As Long
    ftCreationTime As Currency
    ftLastAccessTime As Currency
    ftLastWriteTime As Currency
    nFileSizeHigh As Long
    nFileSizeLow As Long
    dwReserved0 As Long
    dwReserved1 As Long
    cFileName(259) As Byte
    cAlternate(13) As Byte
End Type

Private Const ERROR_NO_MORE_FILES As Long = 18&

Private Declare Function FileTimeToLocalFileTime Lib "kernel32.dll" (ByRef lpFileTime As Currency, ByRef lpLocalFileTime As Currency) As Long
Private Declare Function FileTimeToSystemTime Lib "kernel32.dll" (ByRef lpFileTime As Currency, ByRef lpSystemTime As Any) As Long
Private Declare Function SystemTimeToVariantTime Lib "oleaut32.dll" (ByRef lpSystemTime As Any, ByRef pvtime As Double) As Long

Private Const FindExSearchNameMatch As Long = 0
Private Const FindExSearchLimitToDirectories As Long = 1
Private Const FindExSearchLimitToDevices As Long = 2

'////////

Private m_nType As Long
'0-unused
'1-open
'2-save
'3-choose folder

Private m_bCancel As Boolean
Private m_bUnload As Boolean
Private m_bDiscardEvent As Boolean

Private m_sValue As String
Private m_nFilterIndex As Long

'control index
Private m_idx(127) As Long

Private Enum enumCommonDialogControls
 IDC_Main = 0
 IDC_FileName
 IDC_Filter
 IDC_ListView
 IDC_Container
End Enum

Private Type typeFileFilter
 sName As String
 nCount As Long
 sValue() As String
End Type

Private m_tFilter() As typeFileFilter
Private m_nFilterCount As Long

Private Type typeFileData
 sName As String
 sExtension As String
 nTime As Double
 nSize As Double '<0:directory
End Type

Private Type typeFileCollection
 sPath As String 'must end with "\"
 nCount As Long
 nMax As Long
 tData() As typeFileData
End Type

Private m_tFolders() As typeFileCollection
Private m_nFolderCount As Long
Private m_nFolderMax As Long

Private m_nSelectedFolder As Long

Implements IFakeDXUIEvent

'sPath must end with "\"
Friend Function pEnumerateFiles(ByVal sPath As String, ByRef ret As typeFileCollection, Optional ByVal fSearchOp As Long) As Long
On Error Resume Next
Dim h As Long
Dim t As WIN32_FIND_DATA
Dim s As String, i As Long
Dim f As Double
Dim tmp(7) As Currency
'///
With ret
 .sPath = sPath
 .nCount = 0
 .nMax = 0
 Erase .tData
End With
'///
h = FindFirstFileEx(sPath + "*", 0, t, fSearchOp, ByVal 0, 0)
'///
If h = 0 Or h = -1 Then
 If Err.LastDllError <> ERROR_NO_MORE_FILES Then pEnumerateFiles = -1
 Exit Function
End If
'///
Do
 s = StrConv(t.cFileName, vbUnicode)
 i = InStr(1, s, vbNullChar)
 If i > 0 Then s = Left(s, i - 1)
 If s <> "." And s <> ".." Then
  ret.nCount = ret.nCount + 1
  If ret.nCount > ret.nMax Then
   ret.nMax = ret.nMax + 256&
   ReDim Preserve ret.tData(1 To ret.nMax)
  End If
  With ret.tData(ret.nCount)
   .sName = s
   i = InStrRev(s, ".")
   If i > 0 Then .sExtension = LCase(Mid(s, i + 1))
   If t.dwFileAttributes And vbDirectory Then
    .nSize = -1
   Else
    f = t.nFileSizeHigh
    If f < 0 Then f = f + 4294967296#
    .nSize = f * 4294967296#
    f = t.nFileSizeLow
    If f < 0 Then f = f + 4294967296#
    .nSize = .nSize + f
   End If
   'get time
   FileTimeToLocalFileTime t.ftLastWriteTime, tmp(0)
   FileTimeToSystemTime tmp(0), tmp(1)
   SystemTimeToVariantTime tmp(1), f
   .nTime = f
  End With
 End If
Loop While FindNextFile(h, t)
'///
FindClose h
pEnumerateFiles = ret.nCount
End Function

Friend Sub pCreateFolderButtons(ByVal InitDir As String, Optional ByVal fSearchOp As Long)
On Error Resume Next
'///
Dim v As Variant
Dim i As Long, ii As Long
Dim j As Long, jj As Long
Dim k As Long, kk As Long
Dim m As Long
Dim x As Single, w As Single
Dim s As String, s1 As String
Dim bChanged As Boolean
'///
Dim objComboBox As clsFakeDXUI
Dim objButton As clsFakeDXUI
'///
jj = AscW(Left(InitDir, 1)) And 31&
v = Split(InitDir, "\")
InitDir = ""
'///
With FakeDXUIControls(m_idx(IDC_Container))
 m = .ChildrenCount \ 2
 For i = 0 To UBound(v)
  s = Trim(v(i))
  If s = "" Or s = "." Or s = ".." Then
   Exit For 'end of file or error
  Else
   '///
   InitDir = InitDir + s + "\"
   bChanged = True
   If ii >= 0 And ii < m_nFolderCount Then
    bChanged = LCase(InitDir) <> LCase(m_tFolders(ii + 1).sPath)
   End If
   '///combobox
   If ii < m Then Set objComboBox = FakeDXUIControls(.Children(ii + ii + 1)) _
   Else Set objComboBox = .AddNewChildren(FakeCtl_ComboBox, x, 0, x + 128, 24, FCS_CanGetFocus Or FCBS_FixedText, , , , , , "cmbFolder")
   If bChanged Or ii >= m Then
    With objComboBox
     With .ListViewObject
      .FullRowSelect = True
      .ClearAll
      .AddColumn ""
      If i = 0 Then
       'drive
       .AddItem objText.GetText("Desktop"), , -1
       .AddItem objText.GetText("My Documents"), , -2
       kk = GetLogicalDrives
       k = 1
       For j = 1 To 26
        If kk And k Then
         'TODO:volume label
         .AddItem "(" + ChrW(64 + j) + ":)", , j
        End If
        k = k + k
       Next j
      Else
       'folder
       For j = 1 To m_tFolders(ii).nCount
        If m_tFolders(ii).tData(j).nSize < 0 Then
         s1 = m_tFolders(ii).tData(j).sName
         .AddItem s1, , j
         If LCase(s) = LCase(s1) Then .SelectedRow = .RowCount
        End If
       Next j
      End If
     End With
    End With
   End If
   '///enumerate files
   If bChanged Then
    m_nFolderCount = ii + 1
    If m_nFolderCount > m_nFolderMax Then
     m_nFolderMax = m_nFolderCount + 16&
     ReDim Preserve m_tFolders(1 To m_nFolderMax)
    End If
    j = pEnumerateFiles(InitDir, m_tFolders(m_nFolderCount), fSearchOp)
   End If
   '///add button
   FakeDXGDIDrawText FakeDXUIDefaultFont, s, 0, 0, 128, 24, 0.5, DT_SINGLELINE Or DT_CALCRECT, 0, , , , , , , , w
   w = w + 8
   If ii < m Then Set objButton = FakeDXUIControls(.Children(ii + ii + 2)) _
   Else Set objButton = .AddNewChildren(FakeCtl_Button, x, 0, x + w, 24, _
   FCS_TabStop Or FCS_CanGetFocus Or FBS_Graphical Or FBS_OptionButton, , , , s, , "optFolder")
   With objButton
    .Visible = True
    .Caption = s
    .SetLeftEx x, 0
    .SetRightEx x + w, 0
   End With
   w = w + 16
   With objComboBox
    .Visible = True
    .SetLeftEx x, 0
    .SetRightEx x + w, 0
    .ComboBoxDropdownWidth = (w < 256) And 256&
   End With
   x = x + w
   ii = ii + 1
   '///
   If j < 0 Then Exit For
  End If
 Next i
 m_nFolderCount = ii
 '///
 ii = ii + ii
 For i = ii + 1 To .ChildrenCount
  FakeDXUIControls(.Children(i)).Visible = False
 Next i
 '///over
 .SetRightEx .LeftEx.a + x + 4, 0
 i = .ChildrenCount
 If ii > 0 And ii <= i Then FakeDXUIControls(.Children(ii)).Value = 1
 If i >= 1 Then
  With FakeDXUIControls(.Children(1)).ListViewObject
   For k = 1 To .RowCount
    If .ItemData(k, 1) = jj Then
     .SelectedRow = k
     Exit For
    End If
   Next k
  End With
 End If
 m_nSelectedFolder = m_nFolderCount
 pShowFile
 '///
End With
End Sub

Friend Sub pShowFile(Optional ByVal nIndex As Long = -1)
On Error Resume Next
Dim obj As clsFakeDXUIListView
Dim i As Long, j As Long
Dim b As Boolean
Dim s As String
If nIndex < 0 Then nIndex = m_nSelectedFolder
If nIndex > 0 And nIndex <= m_nFolderCount Then
 Set obj = FakeDXUIControls(m_idx(IDC_ListView)).ListViewObject
 obj.Clear
 With m_tFolders(nIndex)
  For i = 1 To .nCount
   With .tData(i)
    If .nSize < 0 Then
     'directory
     obj.AddItem vbTab + .sName, , i, Array(Array("", -1), vbTab + objText.GetText("Folder"), vbTab + Format(.nTime, "yyyy-mm-dd hh:mm:ss"))
    Else
     'file
     If m_nFilterIndex <= 0 Or m_nFilterIndex > m_nFilterCount Then
      b = True
     Else
      b = False
      For j = 1 To m_tFilter(m_nFilterIndex).nCount
       If .sName Like m_tFilter(m_nFilterIndex).sValue(j) Then
        b = True
        Exit For
       End If
      Next j
     End If
     If b Then
      If .nSize > 2147483647# Then j = &H7FFFFFFF _
      Else j = .nSize
      If j < 1000 Then
       s = CStr(j) + " " + objText.GetText("Bytes")
      Else
       s = Format(.nSize / 1024#, "#,0") + " KB"
      End If
      obj.AddItem .sName, , i, Array(Array(s, j), vbLf + .sExtension, Format(.nTime, "yyyy-mm-dd hh:mm:ss"))
     End If
    End If
   End With
  Next i
 End With
 obj.Sort
End If
End Sub

Friend Function VBGetOpenFileName(ByRef FileName As String, _
                           Optional ByRef FileTitle As String, _
                           Optional ByVal FileMustExist As Boolean = True, _
                           Optional ByVal MultiSelect As Boolean = False, _
                           Optional ByVal Filter As String, _
                           Optional ByRef FilterIndex As Long = 1, _
                           Optional ByVal InitDir As String, _
                           Optional ByVal DlgTitle As String, _
                           Optional ByVal DefaultExt As String) As Boolean
'////////////////////////////////////////////////////////////////
On Error Resume Next
Dim i As Long, j As Long, m As Long
Dim s As String, s1 As String
Dim v As Variant, v2 As Variant
'///
If m_idx(0) <> 0 Or m_nType <> 0 Then Exit Function
m_bUnload = False
m_bCancel = True
m_sValue = vbNullString
m_nFilterIndex = 0
Erase m_tFilter
m_nFilterCount = 0
Erase m_tFolders
m_nFolderCount = 0
m_nFolderMax = 0
m_nSelectedFolder = 0
'///init filter
v = Split(Filter, "|")
m_nFilterCount = (UBound(v) + 1) \ 2
If m_nFilterCount > 0 Then
 ReDim m_tFilter(1 To m_nFilterCount)
 For i = 1 To m_nFilterCount
  m_tFilter(i).sName = Trim(v(i + i - 2))
  v2 = Split(Trim(v(i + i - 1)), ";")
  m = UBound(v2) + 1
  If m > 0 Then
   m_tFilter(i).nCount = m
   ReDim m_tFilter(i).sValue(1 To m)
   For j = 1 To m
    s = Trim(v2(j - 1))
    If s = "*.*" Then s = "*"
    m_tFilter(i).sValue(j) = s
   Next j
  End If
 Next i
End If
If FilterIndex > 0 And FilterIndex <= m_nFilterCount Then m_nFilterIndex = FilterIndex
'///init title
If DlgTitle = "" Then DlgTitle = objText.GetText("Open")
'///init filename
FileName = Trim(Replace(FileName, "/", "\"))
j = Len(FileName)
If j > 0 Then
 Do
  i = j
  FileName = Replace(FileName, "\\", "\")
  j = Len(FileName)
 Loop Until i = j
End If
'///init directory
InitDir = Trim(Replace(InitDir, "/", "\"))
j = Len(InitDir)
If j > 0 Then
 Do
  i = j
  InitDir = Replace(InitDir, "\\", "\")
  j = Len(InitDir)
 Loop Until i = j
 If Right(InitDir, 1) <> "\" Then InitDir = InitDir + "\"
End If
'///
s1 = CurDir
s = Space(Len(InitDir) + Len(s1) + 1024)
PathCombine s, s1, InitDir
i = InStr(1, s, vbNullChar)
If i > 0 Then s = Left(s, i - 1)
'///
s = Replace(s, "/", "\")
j = Len(s)
Do
 i = j
 s = Replace(s, "\\", "\")
 j = Len(s)
Loop Until i = j
If Right(s, 1) <> "\" Then s = s + "\"
InitDir = s
'///
With FakeDXUIControls(1).AddNewChildren(FakeCtl_Form, -300, -200, 300, 200, _
FFS_CloseButton Or FFS_MaxButton Or FFS_Moveable Or FFS_Sizable Or FFS_TitleBar, , False, , DlgTitle, , , 0.5, 0.5, 0.5, 0.5)
 m_idx(0) = .Index
 Set .EventObject = Me
 '///
 'TODO:
 With .AddNewChildren(FakeCtl_TextBox, 88, -64, -72, -40, FCS_TabStop Or FCS_CanGetFocus Or FTS_AutoSelect, , , , , FileName, "txtFileName", , 1, 1, 1)
  m_idx(IDC_FileName) = .Index
 End With
 With .AddNewChildren(FakeCtl_ComboBox, 88, -32, -72, -8, FCS_TabStop Or FCS_CanGetFocus, , , , , , "cmbFilter", , 1, 1, 1)
  m_idx(IDC_Filter) = .Index
  With .ListViewObject
   .FullRowSelect = True
   .AddColumn ""
   If m_nFilterCount > 0 Then
    For i = 1 To m_nFilterCount
     .AddItem m_tFilter(i).sName
    Next i
    If m_nFilterIndex > 0 Then .SelectedRow = m_nFilterIndex
   End If
  End With
 End With
 .AddNewChildren FakeCtl_Label, 8, -64, 80, -40, , , , , objText.GetText("File name"), , , , 1, , 1
 .AddNewChildren FakeCtl_Label, 8, -32, 80, -8, , , , , objText.GetText("File type"), , , , 1, , 1
 .AddNewChildren FakeCtl_Button, -64, -64, -8, -40, FCS_TabStop Or FCS_CanGetFocus Or FBS_Default, , , , objText.GetText("Open"), , "cmdOK", 1, 1, 1, 1
 .AddNewChildren FakeCtl_Button, -64, -32, -8, -8, FCS_TabStop Or FCS_CanGetFocus Or FBS_Cancel, , , , objText.GetText("Cancel"), , "cmdCancel", 1, 1, 1, 1
 With .AddNewChildren(FakeCtl_ListView, 8, 56, -8, -72, FCS_TabStop Or FCS_CanGetFocus, , , , , , "lstFile", , , 1, 1)
  m_idx(IDC_ListView) = .Index
  With .ListViewObject
   .FullRowSelect = True
   .ColumnHeader = True
   .MultiSelect = MultiSelect
   .AddColumn objText.GetText("File name"), , efctStringCaseInsensitive, efcfSizable Or efcfSortable, 256
   .AddColumn objText.GetText("File size"), , , efcfSizable Or efcfSortable Or efcfSortWithItemData Or efcfAlignRight, 128
   .AddColumn objText.GetText("Extension"), , , efcfSizable Or efcfSortable, 128
   .AddColumn objText.GetText("Modification time"), , , efcfSizable Or efcfSortable, 128
  End With
 End With
 With .AddNewChildren(FakeCtl_None, 8, 8, -96, 52, FCS_TabStop Or FCS_CanGetFocus Or FCS_AutoScroll, , , , , , , , , 1)
  With .AddNewChildren(FakeCtl_None, 0, 0, 128, 26)
   m_idx(IDC_Container) = .Index
  End With
 End With
 pCreateFolderButtons InitDir
 .AddNewChildren FakeCtl_Button, -88, 8, -8, 32, FCS_TabStop Or FCS_CanGetFocus, , , , objText.GetText("New folder"), , "cmdNewFolder", 1, , 1
 '///
 .Show 1
End With
'///
m_bDiscardEvent = True
FakeDXAppMainLoop VarPtr(1&)
m_bDiscardEvent = False
'///wait for single object
FakeDXAppMainLoop VarPtr(m_bUnload)
'///
i = m_idx(0)
If i > 0 And i <= FakeDXUIControlCount Then
 FakeDXUIControls(i).Unload
End If
'///over TODO:
Erase m_idx
'////////////////////////////////////////////////////////////////
End Function

Friend Function VBGetSaveFileName(ByRef FileName As String, _
                           Optional ByRef FileTitle As String, _
                           Optional ByVal PathMustExist As Boolean = True, _
                           Optional ByVal OverWritePrompt As Boolean = True, _
                           Optional ByVal Filter As String = "All (*.*)| *.*", _
                           Optional ByRef FilterIndex As Long = 1, _
                           Optional ByVal InitDir As String, _
                           Optional ByVal DlgTitle As String, _
                           Optional ByVal DefaultExt As String) As Boolean
'////////////////////////////////////////////////////////////////
If m_idx(0) <> 0 Or m_nType <> 0 Then Exit Function
'////////////////////////////////////////////////////////////////
End Function

Friend Function VBChooseFolder(ByRef FileName As String, _
                           Optional ByVal PathMustExist As Boolean = True, _
                           Optional ByVal MultiSelect As Boolean = False, _
                           Optional ByVal InitDir As String, _
                           Optional ByVal DlgTitle As String) As Boolean
'////////////////////////////////////////////////////////////////
If m_idx(0) <> 0 Or m_nType <> 0 Then Exit Function
'////////////////////////////////////////////////////////////////
End Function

Private Sub IFakeDXUIEvent_Change(ByVal obj As clsFakeDXUI)
'
End Sub

Private Sub IFakeDXUIEvent_Click(ByVal obj As clsFakeDXUI)
On Error Resume Next
Dim i As Long, j As Long
Dim s As String
'///
If m_bDiscardEvent Then Exit Sub
Select Case obj.Name
Case "cmdOK"
 m_bUnload = True
 m_bCancel = False
 i = m_idx(IDC_FileName)
 If i > 0 And i <= FakeDXUIControlCount Then
  m_sValue = FakeDXUIControls(i).Text
 End If
 i = m_idx(IDC_Filter)
 If i > 0 And i <= FakeDXUIControlCount Then
  m_nFilterIndex = FakeDXUIControls(i).ListViewObject.SelectedRow
 End If
 'TODO:validate
Case "cmdCancel"
 m_bUnload = True
Case "optFolder"
 m_nSelectedFolder = obj.ChildIndex \ 2
 pShowFile
Case "cmbFolder"
 i = obj.ChildIndex \ 2
 If i = 0 Then
  j = obj.ListViewObject.SelectedRow
  If j > 0 Then j = obj.ListViewObject.ItemData(j, 1)
  Select Case j
  Case -1
   s = Space(1024)
   SHGetSpecialFolderPath 0, s, CSIDL_DESKTOPDIRECTORY, 1
  Case -2
   s = Space(1024)
   SHGetSpecialFolderPath 0, s, CSIDL_PERSONAL, 1
  Case 1 To 26
   s = ChrW(64 + j) + ":\"
  End Select
  i = InStr(1, s, vbNullChar)
  If i > 0 Then s = Left(s, i - 1)
  If Right(s, 1) <> "\" Then s = s + "\"
  '///
  pCreateFolderButtons s
 ElseIf i <= m_nFolderCount Then
  j = obj.ListViewObject.SelectedRow
  If j > 0 Then j = obj.ListViewObject.ItemData(j, 1)
  If j > 0 And j <= m_tFolders(i).nCount Then
   pCreateFolderButtons m_tFolders(i).sPath + m_tFolders(i).tData(j).sName + "\"
  End If
 End If
 '///???
 m_bDiscardEvent = True
 FakeDXAppMainLoop VarPtr(1&)
 m_bDiscardEvent = False
 '///
Case "cmdNewFolder"
 'TODO:
Case "lstFile"
 'TODO:
 If m_nSelectedFolder > 0 And m_nSelectedFolder <= m_nFolderCount Then
 End If
Case "cmbFilter"
 m_nFilterIndex = obj.ListViewObject.SelectedRow
 pShowFile
End Select
End Sub

Private Sub IFakeDXUIEvent_DblClick(ByVal obj As clsFakeDXUI)
On Error Resume Next
Dim i As Long
'///
If m_bDiscardEvent Then Exit Sub
Select Case obj.Name
Case "lstFile"
 'TODO:
 If m_nSelectedFolder > 0 And m_nSelectedFolder <= m_nFolderCount Then
  i = obj.ListViewObject.SelectedRow
  If i > 0 Then i = obj.ListViewObject.ItemData(i, 1)
  If i > 0 And i <= m_tFolders(m_nSelectedFolder).nCount Then
   If m_tFolders(m_nSelectedFolder).tData(i).nSize < 0 Then
    pCreateFolderButtons m_tFolders(m_nSelectedFolder).sPath + m_tFolders(m_nSelectedFolder).tData(i).sName + "\"
   Else
    'TODO:selected this
   End If
  End If
 End If
End Select
End Sub

Private Sub IFakeDXUIEvent_Unload(ByVal obj As clsFakeDXUI, Cancel As Boolean)
m_bUnload = True
End Sub
