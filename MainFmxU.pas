unit MainFmxU;
interface
uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,system.IOUtils ,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl, FMX.DialogService, FMX.DialogService.Async,
  FMX.Controls.Presentation, FMX.StdCtrls,System.Permissions, MyShareUnit, MyShareProcedure,
  Androidapi.JNIBridge, Androidapi.Helpers, Androidapi.JNI.JavaTypes,Androidapi.JNI.CtpBridge,
  FMX.Memo.Types, FMX.ScrollBox, FMX.Memo, FMX.Layouts, FMX.Edit, FMX.ListBox,
  FMX.ListView.Types, FMX.ListView.Appearances, FMX.ListView.Adapters.Base,FMX.Platform.Android,
  FMX.ListView, FMX.Objects,u_Toast, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.FMXUI.Wait, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client;
type
  TMainFmx = class(TForm)
    tmr1: TTimer;
    tbc1: TTabControl;
    tbtmLogin: TTabItem;
    tbtmTrade: TTabItem;
    tbtmReq: TTabItem;
    tbtmIni: TTabItem;
    mmo1: TMemo;
    btnqryTradingAccount: TButton;
    btnqryInvestorPosition: TButton;
    lyt1: TLayout;
    lyt41: TLayout;
    edtusername: TEdit;
    lbl111: TLabel;
    lyt42: TLayout;
    edtpassword: TEdit;
    lbl112: TLabel;
    lyt431: TLayout;
    edtAuthCode: TEdit;
    lbl1131: TLabel;
    lyt44: TLayout;
    edtBrokerID: TEdit;
    lbl114: TLabel;
    lyt2: TLayout;
    lyt4: TLayout;
    edtProduct: TEdit;
    lbl11: TLabel;
    lyt43: TLayout;
    edtAppID: TEdit;
    lbl113: TLabel;
    lyt3: TLayout;
    lstTDFront: TListBox;
    lyt441: TLayout;
    edtTDFrontAddress: TEdit;
    btnTDFront: TButton;
    lyt: TLayout;
    lstMDFront: TListBox;
    lyt5: TLayout;
    edtMDFrontAddress: TEdit;
    btnMDFront: TButton;
    btn1: TButton;
    lyt6: TLayout;
    cbbIniFLst2: TComboBox;
    tbtmMarkData: TTabItem;
    lyt411: TLayout;
    lbl1111: TLabel;
    cbbIniFLst: TComboBox;
    lyt45: TLayout;
    lv11: TListView;
    lbl5: TLabel;
    RectMask: TRectangle;
    LayoutDialog: TLayout;
    RectBg: TRectangle;
    LabelTitle: TLabel;
    EditInput: TEdit;
    LayoutButtons: TLayout;
    BtnCancel: TButton;
    BtnOk: TButton;
    con1: TFDConnection;
    scrlbx1: TScrollBox;
    lyt7: TLayout;
    lyt8: TLayout;
    btnLogin: TButton;
    lbl62: TLabel;
    img31: TImage;
    lyt9: TLayout;
    lyt10: TLayout;
    procedure tmr1Timer(Sender: TObject);
    procedure UpdateStatus;
    procedure btnqryTradingAccountClick(Sender: TObject);
    procedure btnqryInvestorPositionClick(Sender: TObject);
    procedure btnTDFrontClick(Sender: TObject);
    procedure lstTDFrontClick(Sender: TObject);
    procedure edtTDFrontAddressKeyUp(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
    procedure edtMDFrontAddressKeyUp(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
    procedure lstMDFrontClick(Sender: TObject);
    procedure btnMDFrontClick(Sender: TObject);
    procedure lv11Click(Sender: TObject);
    procedure BtnOkClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);
    procedure btn1Click(Sender: TObject);  //此方法默认添加在 private区 APP闪崩 移到 public区正常
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure con1AfterConnect(Sender: TObject);
    procedure lv11Change(Sender: TObject);               // 保存配置: 参数控件 -> ini 文件
    procedure lv11ButtonClick(const Sender: TObject; const AItem: TListItem;
      const AObject: TListItemSimpleControl);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnLoginClick(Sender: TObject);
    procedure edtBrokerIDChange(Sender: TObject);
            // item 上「退订」按钮: 退订并删行 此方法默认添加在 private区 APP闪崩 移到 public区正常
      {CreateForm 阶段流式加载 .fmx 时，遇到 OnClick = btn1Click，运行时会去窗体类的 published 方法表里按名字查找这个方法。而 Delphi 规定：
        TForm 子类声明中，写在 private/public 关键字之前的“默认区”成员 → 自动 published，有 RTTI，能被 fmx 按名找到；
        private 区的方法 → 没有 published RTTI，按名字查不到 → filer 错误 → 在桌面 IDE 上会弹 "Method Btn1Click not found"，但在安卓上就是 CreateForm 阶段直接 EExternalException 静默闪崩。
        规则统一记一条：fmx 里每一条 OnXxx = 方法名，方法都必须在 published 区真实存在，否则就是同样的静默闪崩。}
  private
    { Private declarations }
    FCallback: TInputResultProc;
    loginInfo : TloginInfo ;
    FCtp: JCtpBridge;
    FCfgIds: TStringList;      // 与 cbbIniFLst.ItemIndex 一一对应的 CTPConFig.id
    FCurProduction: Integer;   // 当前选中配置的 生产/评测 标志(1=生产, 默认1)
    FCurFlowPath: string;      // 当前选中配置的流文件目录(空=默认私有目录/ctpflow)
    FIniFilled: Boolean;      // 启动后是否已扫描过 ini 列表(只自动扫一次)
    FUpdatingIni: Boolean;    // 程序内联动两个下拉框时防 OnChange 递归
    FQuoteInstrs: TStringList; // 与 lv11.Items 平行: 每行对应的合约代码
    FMdStarted: Boolean;       // 本次交易登录后是否已启动行情
    FMdUIBuilt: Boolean;       // 行情页顶部控件是否已创建
    FLastStatus: string;       // 上一次已写入日志的连接状态(仅变化时记录, 避免刷屏)
    edtMdInstr: TEdit;         // 行情页合约输入框(代码创建)
    function Ctp: JCtpBridge;
    procedure RequestAndroidPermissions;
    procedure AddLog(const AText: string); overload ;
    procedure AddLog(const AText: string;showited:Boolean); overload ;
    procedure FillIniList;              // 读数据库 CTPConFig 填充 cbbIniFLst/cbbIniFLst2
    function SelectedCfgId: Integer;    // 当前选中配置的 CTPConFig.id(未选返回 -1)
    procedure SyncIniCombo(Sender: TObject);            // 任一下拉框变化: 联动另一个并回填参数控件
    procedure ApplyCfgToControls(ACfgId: Integer);      // 按 id 读库(含前置地址表)回填参数控件
    procedure DoSaveCfg(const AName: string);           // AsyncInputQuery 回调后真正写数据库
    procedure DoDelCfg(const AName: string);
    function BuildLoginIni: string;                     // 用当前控件参数在私有目录生成登录 ini, 返回全路径
    procedure DeleteLoginIni;                           // 登录完成后删除私有目录的临时登录 ini
    // ---- 行情页 ----
    procedure BuildMdUI;                                // 行情页顶部: 合约输入 + 订阅/退订按钮(仅创建一次)
    procedure btnMdSubClick(Sender: TObject);
    procedure btnMdUnsubClick(Sender: TObject);
    procedure HandleEvent(const AEvent: string);        // 事件分发: MDQ→行情表刷新, 其它→日志
    function QuoteItem(const AInstr: string): TListViewItem; // 取/建合约对应的 item
    procedure UpdateQuote(const Parts: TArray<string>); // 把 MDQ 各字段写入 item 的 text
  public
    { Public declarations }
  end;
var
  MainFmx: TMainFmx;
implementation
{$R *.fmx}
procedure TMainFmx.AddLog(const AText: string);
begin
  if mmo1 = nil then
    Exit;
  if mmo1.Lines.Count > 3000 then
    mmo1.Lines.Clear;
  mmo1.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AText);
end;
procedure TMainFmx.AddLog(const AText: string;showited:Boolean);
begin
  if mmo1 = nil then
    Exit;
  if mmo1.Lines.Count > 3000 then
    mmo1.Lines.Clear;
  mmo1.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AText);
  if showited then Toast(AText,TToastLength.ShortToast,TGravity.CENTER,50,50);
end;
procedure TMainFmx.btnqryTradingAccountClick(Sender: TObject);
begin
  try
    Ctp.qryTradingAccount;
  except
    on E: Exception do
      AddLog('[UI] 查询资金异常: ' + E.Message);
  end;
end;
procedure TMainFmx.btnTDFrontClick(Sender: TObject);
begin
  if (btnTDFront.Text = '添加') and (Trim(edtTDFrontAddress.Text)<>'') then
    begin
      lstTDFront.Items.Add(Trim(edtTDFrontAddress.Text));
    end;
  if (btnTDFront.Text = '删除') and (lstTDFront.ItemIndex>=0) then
    begin
      lstTDFront.Items.Delete(lstTDFront.ItemIndex);
      btnTDFront.Text := '';
      btnTDFront.Text := '添加' ;
    end;
  btn1.Text := '保存配置';
end;
procedure TMainFmx.btnqryInvestorPositionClick(Sender: TObject);
begin
  try
    Ctp.qryInvestorPosition;
  except
    on E: Exception do
      AddLog('[UI] 查询持仓异常: ' + E.Message);
  end;
end;
{ 读取数据库 CTPConFig, 同时填充 cbbIniFLst 与 cbbIniFLst2(两个下拉框联动)。
  FCfgIds 与下拉框 Items 按下标一一对应存放 CTPConFig.id。
  选中第一项后由 SyncIniCombo -> ApplyCfgToControls 自动回填参数控件,
  服务器地址在 ApplyCfgToControls 里按 CFGid 查 TDMDFrontLST。 }
procedure TMainFmx.FillIniList;
var
  Q: TFDQuery;
begin
  if cbbIniFLst = nil then
    Exit;
  cbbIniFLst.Items.BeginUpdate;
  cbbIniFLst2.Items.BeginUpdate;
  try
    cbbIniFLst.Items.Clear;
    cbbIniFLst2.Items.Clear;
    if FCfgIds = nil then
      FCfgIds := TStringList.Create;
    FCfgIds.Clear;
    if (con1 = nil) or (not con1.Connected) then
    begin
      AddLog('[DB] 数据库未连接, 配置列表为空');
      Exit;
    end;
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := con1;
      Q.SQL.Text := 'select id, CFGNAME from CTPConFig order by id';
      Q.Open;
      while not Q.Eof do
      begin
        FCfgIds.Add(Q.FieldByName('id').AsString);
        cbbIniFLst.Items.Add(Trim(Q.FieldByName('CFGNAME').AsString));
        cbbIniFLst2.Items.Add(Trim(Q.FieldByName('CFGNAME').AsString));
        Q.Next;
      end;
      Q.Close;
    finally
      Q.Free;
    end;
  finally
    cbbIniFLst.Items.EndUpdate;
    cbbIniFLst2.Items.EndUpdate;
  end;
  // 事件全部代码挂接, 不依赖 .fmx
  cbbIniFLst.OnChange := SyncIniCombo;
  cbbIniFLst2.OnChange := SyncIniCombo;
  // 行情表: item 内「退订」按钮
  lv11.OnButtonClick := lv11ButtonClick;
  if cbbIniFLst.Count > 0 then
  begin
    // 选中第一个; ItemIndex 赋值会触发 SyncIniCombo -> 联动第二个下拉框并回填参数控件
    cbbIniFLst.ItemIndex := 0;
    AddLog('[DB] 找到 ' + IntToStr(cbbIniFLst.Count) + ' 个配置, 默认: '
      + cbbIniFLst.Items[0]);
  end
  else
    AddLog('[DB] 数据库中没有配置, 登录将使用界面参数');
end;
procedure TMainFmx.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := false ;
  try
    if (lv11.Items.count>=1) then
      begin
        var tmpstr:string;
        tmpstr:='';
        for var i := 0 to lv11.Items.count-1 do
          begin
            var vAItem:TListViewItem;
            vAItem := lv11.Items[i];
            tmpstr := tmpstr+trim((vAItem.Objects.FindDrawable('Text1') as TListItemText).Text )+',';
          end;
        mmo1.Lines.Clear ;
        mmo1.Text := tmpstr ;
        mmo1.Lines.SaveToFile(HYLstFileName);
      end;
  except


  end;
  CanClose := true ;
end;

procedure TMainFmx.FormCreate(Sender: TObject);
begin
  FCurProduction := 1;   // 默认生产环境, FillIniList->ApplyCfgToControls 会按库里的值覆盖
  FCurFlowPath := '';
  dbFileName := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetPublicPath, 'CTPINI.db');
  HYLstFileName := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetPublicPath, 'HYLst.ini');
  AddLog(dbFileName);
  con1.Params.Clear ;
  con1.Connected := False ;
  con1.Params.Add('DriverID=SQLite');
  con1.Params.Add('Database='+dbFileName  ); //本地数据库模式    //
  con1.Params.Add('Password='+Format('%s', [DBKeyConStr]));//
  con1.Connected := True ;
end;
procedure TMainFmx.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if (Key = 137) then // 如果按了虚拟键:返回键
    begin
      if backi =0 then
        begin
          Toast('再按一次退出键退出APP！',TToastLength.ShortToast,TGravity.CENTER,50,50);
          key := 0 ;
          inc(backi);
          exit;
        end;
      MainActivity.finish;
      application.Terminate;
    end;
end;
procedure TMainFmx.FormShow(Sender: TObject);
begin
  RectMask.Visible := False ;
end;
function TMainFmx.SelectedCfgId: Integer;
begin
  Result := -1;
  if (cbbIniFLst <> nil) and (cbbIniFLst.ItemIndex >= 0)
    and (FCfgIds <> nil) and (FCfgIds.Count > cbbIniFLst.ItemIndex) then
    Result := StrToIntDef(FCfgIds[cbbIniFLst.ItemIndex], -1);
end;
{ 任一下拉框选择变化: 先把另一个下拉框同步到同一项(防递归), 再按选中配置的
  CTPConFig.id 从数据库读参数回填 tbtmIni 页的各参数控件。 }
procedure TMainFmx.SyncIniCombo(Sender: TObject);
var
  Idx: Integer;
begin
  if FUpdatingIni then
    Exit;
  if not ((Sender = cbbIniFLst) or (Sender = cbbIniFLst2)) then
    Exit;
  Idx := TComboBox(Sender).ItemIndex;
  FUpdatingIni := True;
  try
    // 两个下拉框保持同一选中项
    cbbIniFLst.ItemIndex := Idx;
    cbbIniFLst2.ItemIndex := Idx;
  finally
    FUpdatingIni := False;
  end;
  if (Idx >= 0) and (FCfgIds <> nil) and (FCfgIds.Count > Idx) then
  begin
    AddLog('[DB] 已选择配置: ' + cbbIniFLst.Items[Idx]);
    ApplyCfgToControls(StrToIntDef(FCfgIds[Idx], -1));
    btn1.Text := '删除配置';
  end;
end;
{ 按配置号 ACfgId 读数据库回填参数控件:
  1) CTPConFig: BrokerID/UserID/UserProductInfo/AuthCode/AppID(密码不在库中, 保留登录页输入);
  2) TDMDFrontLST: 按 CFGid 取服务器地址, FrontName=TDFRONT 进交易前置列表,
     MDFRONT 进行情前置列表, 第一个地址同时放进输入框。 }
procedure TMainFmx.ApplyCfgToControls(ACfgId: Integer);
var
  Q: TFDQuery;
  Addr, CfgName: string;
begin
  if ACfgId < 0 then
    Exit;
  if (con1 = nil) or (not con1.Connected) then
  begin
    AddLog('[DB] 数据库未连接, 无法回填配置');
    Exit;
  end;
  Q := TFDQuery.Create(nil);
  try
    // 1) 主表参数 -> 控件
    Q.Connection := con1;
    Q.SQL.Text := 'select CFGNAME, BrokerID, UserID, UserProductInfo, AuthCode, AppID,'
      + ' Production, FlowPath from CTPConFig where id = :id';
    Q.ParamByName('id').AsInteger := ACfgId;
    Q.Open;
    if Q.Eof then
    begin
      AddLog('[DB] 找不到配置 id=' + IntToStr(ACfgId));
      Exit;
    end;
    CfgName := Trim(Q.FieldByName('CFGNAME').AsString);
    edtBrokerID.Text := Trim(Q.FieldByName('BrokerID').AsString);
    edtusername.Text := Trim(Q.FieldByName('UserID').AsString);
    edtProduct.Text  := Trim(Q.FieldByName('UserProductInfo').AsString);
    edtAuthCode.Text := Trim(Q.FieldByName('AuthCode').AsString);
    edtAppID.Text    := Trim(Q.FieldByName('AppID').AsString);
    // Production: NULL 按生产(1)处理; 显式存 0 才是评测
    if Q.FieldByName('Production').IsNull then
      FCurProduction := 1
    else
      FCurProduction := Q.FieldByName('Production').AsInteger;
    FCurFlowPath := Trim(Q.FieldByName('FlowPath').AsString);
    Q.Close;
    // 2) 前置地址
    lstTDFront.Items.BeginUpdate;
    lstMDFront.Items.BeginUpdate;
    try
      lstTDFront.Items.Clear;
      lstMDFront.Items.Clear;
      Q.SQL.Text := 'select FrontName, FrontAddress from TDMDFrontLST'
        + ' where CFGid = :id order by id';
      Q.ParamByName('id').AsInteger := ACfgId;
      Q.Open;
      while not Q.Eof do
      begin
        Addr := Trim(Q.FieldByName('FrontAddress').AsString);
        if Addr <> '' then
        begin
          if SameText(Trim(Q.FieldByName('FrontName').AsString), 'TDFRONT') then
            lstTDFront.Items.Add(Addr)
          else
            lstMDFront.Items.Add(Addr);
        end;
        Q.Next;
      end;
      Q.Close;
    finally
      lstTDFront.Items.EndUpdate;
      lstMDFront.Items.EndUpdate;
    end;
  finally
    Q.Free;
  end;
  // 第一个前置地址放进输入框, 添加/删除按钮复位为添加态
  if lstTDFront.Items.Count > 0 then
    edtTDFrontAddress.Text := lstTDFront.Items[0]
  else
    edtTDFrontAddress.Text := '';
  if lstMDFront.Items.Count > 0 then
    edtMDFrontAddress.Text := lstMDFront.Items[0]
  else
    edtMDFrontAddress.Text := '';
  btnTDFront.Text := '添加';
  btnMDFront.Text := '添加';
  AddLog('[DB] 已回填 ' + CfgName + ': BrokerID=' + edtBrokerID.Text
    + ' UserID=' + edtusername.Text
    + ' 交易前置 ' + IntToStr(lstTDFront.Items.Count) + ' 个, 行情前置 '
    + IntToStr(lstMDFront.Items.Count) + ' 个');
end;
{ 保存配置到数据库(不再是 ini 文件):
  同名配置覆盖(UPDATE), 否则新增(INSERT); 先写 CTPConFig 主表,
  再按 CFGid 重建 TDMDFrontLST 里的前置地址。密码不入库(表无该字段)。 }
procedure TMainFmx.DoDelCfg(const AName: string);
var
  Q: TFDQuery;
  I, CfgId: Integer;
  Name1, S: string;
begin
  Name1 := Trim(AName);
  if Name1 = '' then
    Exit;
  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := con1;
      // 已存在同名 -> 覆盖; 否则新增。char(30) 字段可能带尾部空格, 用 upper(trim()) 比较
      CfgId := -1;
      Q.SQL.Text := 'select id from CTPConFig where upper(trim(CFGNAME)) = :n order by id';
      Q.ParamByName('n').AsString := UpperCase(Name1);
      Q.Open;
      if not Q.Eof then
        CfgId := Q.FieldByName('id').AsInteger;
      Q.Close;
      if CfgId >= 0 then
      begin
        Q.SQL.Text := 'delete from  CTPConFig where id = :id ';
        Q.ParamByName('id').AsInteger  := CfgId;
        Q.ExecSQL;
      end;
      // 前置地址: 先删旧再插新, 顺序即优先级
      Q.SQL.Text := 'delete from TDMDFrontLST where CFGid = :id';
      Q.ParamByName('id').AsInteger := CfgId;
      Q.ExecSQL;
    except
      on e:Exception do  AddLog('[DB] 删除配置: ' + Name1 + ' (' + S + ')出错：'+e.Message, True);
    end;
  finally
    Q.Free;
  end;
  S := 'id=' + IntToStr(CfgId);
  AddLog('[DB] 已删除配置: ' + Name1 + ' (' + S + ')', True);
  // 刷新两个下拉框并选中新保存的配置(触发回填, 立即看到保存结果)
  FillIniList;

end;
{ 保存配置到数据库(不再是 ini 文件):
  同名配置覆盖(UPDATE), 否则新增(INSERT); 先写 CTPConFig 主表,
  再按 CFGid 重建 TDMDFrontLST 里的前置地址。密码不入库(表无该字段)。 }
procedure TMainFmx.DoSaveCfg(const AName: string);
var
  Q: TFDQuery;
  I, CfgId: Integer;
  Name1, S: string;
begin
  Name1 := Trim(AName);
  if Name1 = '' then
    Exit;
  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := con1;
      // 已存在同名 -> 覆盖; 否则新增。char(30) 字段可能带尾部空格, 用 upper(trim()) 比较
      CfgId := -1;
      Q.SQL.Text := 'select id from CTPConFig where upper(trim(CFGNAME)) = :n order by id';
      Q.ParamByName('n').AsString := UpperCase(Name1);
      Q.Open;
      if not Q.Eof then
        CfgId := Q.FieldByName('id').AsInteger;
      Q.Close;
      if CfgId < 0 then
      begin
        Q.SQL.Text := 'insert into CTPConFig (CFGNAME, BrokerID, UserID, InvestorID,'
          + ' UserProductInfo, AuthCode, AppID, Production, FlowPath)'
          + ' values (:n, :b, :u, :i, :p, :a, :ap, :prod, :f)';
        Q.ParamByName('n').AsString    := Name1;
        Q.ParamByName('b').AsString    := Trim(edtBrokerID.Text);
        Q.ParamByName('u').AsString    := Trim(edtusername.Text);
        Q.ParamByName('i').AsString    := Trim(edtusername.Text);  // InvestorID = UserID
        Q.ParamByName('p').AsString    := Trim(edtProduct.Text);
        Q.ParamByName('a').AsString    := Trim(edtAuthCode.Text);
        Q.ParamByName('ap').AsString   := Trim(edtAppID.Text);
        Q.ParamByName('prod').AsInteger := FCurProduction;
        Q.ParamByName('f').AsString    := FCurFlowPath;
        Q.ExecSQL;
        CfgId := con1.ExecSQLScalar('select last_insert_rowid()');
      end
      else
      begin
        Q.SQL.Text := 'update CTPConFig set BrokerID=:b, UserID=:u, InvestorID=:i,'
          + ' UserProductInfo=:p, AuthCode=:a, AppID=:ap, Production=:prod, FlowPath=:f'
          + ' where id = :id';
        Q.ParamByName('b').AsString    := Trim(edtBrokerID.Text);
        Q.ParamByName('u').AsString    := Trim(edtusername.Text);
        Q.ParamByName('i').AsString    := Trim(edtusername.Text);
        Q.ParamByName('p').AsString    := Trim(edtProduct.Text);
        Q.ParamByName('a').AsString    := Trim(edtAuthCode.Text);
        Q.ParamByName('ap').AsString   := Trim(edtAppID.Text);
        Q.ParamByName('prod').AsInteger := FCurProduction;
        Q.ParamByName('f').AsString    := FCurFlowPath;
        Q.ParamByName('id').AsInteger  := CfgId;
        Q.ExecSQL;
      end;
      // 前置地址: 先删旧再插新, 顺序即优先级
      Q.SQL.Text := 'delete from TDMDFrontLST where CFGid = :id';
      Q.ParamByName('id').AsInteger := CfgId;
      Q.ExecSQL;
      Q.SQL.Text := 'insert into TDMDFrontLST (CFGid, FrontName, FrontAddress)'
        + ' values (:id, :n, :a)';
      for I := 0 to lstTDFront.Items.Count - 1 do
      begin
        Q.ParamByName('id').AsInteger := CfgId;
        Q.ParamByName('n').AsString   := 'TDFRONT';
        Q.ParamByName('a').AsString   := Trim(lstTDFront.Items[I]);
        Q.ExecSQL;
      end;
      for I := 0 to lstMDFront.Items.Count - 1 do
      begin
        Q.ParamByName('id').AsInteger := CfgId;
        Q.ParamByName('n').AsString   := 'MDFRONT';
        Q.ParamByName('a').AsString   := Trim(lstMDFront.Items[I]);
        Q.ExecSQL;
      end;
    except
      on e:Exception do  AddLog('[DB] 保存配置: ' + Name1 + ' (' + S + ')出错：'+e.Message, True);
    end;
  finally
    Q.Free;
  end;
  S := 'id=' + IntToStr(CfgId);
  AddLog('[DB] 已保存配置: ' + Name1 + ' (' + S + ')'
    + ' 交易前置 ' + IntToStr(lstTDFront.Items.Count) + ' 个', True);
  // 刷新两个下拉框并选中新保存的配置(触发回填, 立即看到保存结果)
  FillIniList;
  if FCfgIds <> nil then
  begin
    I := FCfgIds.IndexOf(IntToStr(CfgId));
    if I >= 0 then
      cbbIniFLst.ItemIndex := I;
  end;
end;
{ 用当前控件参数在程序私有目录生成登录 ini(Java 侧解析器格式不变):
  Front1..N 交易前置, MdFront1..N 行情前置。返回全路径, 失败返回空串。 }
function TMainFmx.BuildLoginIni: string;
var
  Lines: TStringList;
  I: Integer;
  Path: string;
begin
  Result := '';
  if lstTDFront.Items.Count = 0 then
  begin
    AddLog('[INI] 交易前置列表为空, 无法生成登录配置', True);
    Exit;
  end;
  Path := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'ctp_login.ini');
  Lines := TStringList.Create;
  try
    Lines.Add('; CTP 登录配置 - 由 APP 界面生成 '
      + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Lines.Add('; 键名不区分大小写; 以 ; 或 # 开头是注释');
    Lines.Add('[Login]');
    // 交易前置(顺序即优先级)
    for I := 0 to lstTDFront.Items.Count - 1 do
      Lines.Add(Format('Front%d = %s', [I + 1, lstTDFront.Items[I]]));
    // 行情前置
    for I := 0 to lstMDFront.Items.Count - 1 do
      Lines.Add(Format('MdFront%d = %s', [I + 1, lstMDFront.Items[I]]));
    Lines.Add('BrokerID = ' + Trim(edtBrokerID.Text));
    Lines.Add('UserID = ' + Trim(edtusername.Text));
    Lines.Add('Password = ' + edtpassword.Text);
    Lines.Add('InvestorID = ' + Trim(edtusername.Text));
    Lines.Add('UserProductInfo = ' + Trim(edtProduct.Text));
    Lines.Add('AuthCode = ' + Trim(edtAuthCode.Text));
    Lines.Add('AppID = ' + Trim(edtAppID.Text));
    Lines.Add('; 1 = 生产环境, 0 = 评测环境');
    Lines.Add('Production = ' + IntToStr(FCurProduction));
    Lines.Add('; 流文件目录, 留空 = 应用私有目录/ctpflow');
    Lines.Add('FlowPath = ' + FCurFlowPath);
    try
      // UTF-8 无 BOM; Java 侧解析器对 BOM/CRLF 均兼容
      System.IOUtils.TFile.WriteAllText(Path, Lines.Text, TEncoding.UTF8);
      Result := Path;
    except
      on E: Exception do
        AddLog('[INI] 生成登录配置失败: ' + E.Message, True);
    end;
  finally
    Lines.Free;
  end;
end;
{ 登录完成后删除私有目录的临时登录 ini(一次性凭据文件, 不留在设备上)。 }
procedure TMainFmx.DeleteLoginIni;
var
  Path: string;
begin
  Path := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'ctp_login.ini');
  try
    if System.IOUtils.TFile.Exists(Path) then
    begin
      System.IOUtils.TFile.Delete(Path);
      AddLog('[INI] 已删除临时登录配置: ' + Path);
    end;
  except
    on E: Exception do
      AddLog('[INI] 删除临时登录配置失败: ' + E.Message);
  end;
end;
{ ==================== 行情页 ==================== }
{ 行情页顶部: 合约输入框 + 订阅/退订 按钮。Align=Left 的按钮先建, Align=Client
  的输入框后建, FMX 自动把剩余宽度给输入框。只在第一次交易登录后创建一次。 }
procedure TMainFmx.BuildMdUI;
var
  btn: TButton;
begin
  if FMdUIBuilt then
    Exit;
  FMdUIBuilt := True;
  btn := TButton.Create(lyt7);
  btn.Name := 'btnMdSub';
  btn.Parent := lyt7;
  btn.Align := TAlignLayout.Left;
  btn.Width := 64;
  btn.Margins.Rect := TRectF.Create(6, 6, 2, 6);
  btn.Text := '订阅';
  btn.OnClick := btnMdSubClick;
  btn := TButton.Create(lyt7);
  btn.Name := 'btnMdUnsub';
  btn.Parent := lyt7;
  btn.Align := TAlignLayout.Left;
  btn.Width := 64;
  btn.Margins.Rect := TRectF.Create(2, 6, 2, 6);
  btn.Text := '退订';
  btn.OnClick := btnMdUnsubClick;
  edtMdInstr := TEdit.Create(lyt7);
  edtMdInstr.Name := 'edtMdInstr';
  edtMdInstr.Parent := lyt7;
  edtMdInstr.Align := TAlignLayout.Client;
  edtMdInstr.Margins.Rect := TRectF.Create(2, 6, 6, 6);
  edtMdInstr.TextPrompt := '合约代码, 可多个: rb2601,cu2508';
  try
    if FileExists(HYLstFileName) then
      begin
        var tmplst:TStringList;
        tmplst := TStringList.Create  ;
        tmplst.LoadFromFile(HYLstFileName);
        edtMdInstr.Text := trim(tmplst.Text) ;
        tmplst.Clear ;
        tmplst.Free ;
      end;
  except

  end;
end;
procedure TMainFmx.con1AfterConnect(Sender: TObject);
begin
  try
    con1.ExecSQL(Format('create table if not exists CTPConFig (id integer primary key autoincrement,CFGNAME char(30) ,'+
                        'BrokerID char(9),UserID char(30) ,InvestorID char(30),'+
                        'UserProductInfo char(40),AuthCode char(40),AppID char(40),Production integer DEFAULT (1),'+
                        'FlowPath char(240))', []),false );
    con1.ExecSQL(Format('create table if not exists TDMDFrontLST (id integer primary key autoincrement,CFGid integer,'+
                          'FrontName char(8),FrontAddress char(30))', []),false );
  except
    on e:Exception do
      begin
        AddLog(Format('创建数据表错误 %s',[e.Message]),True);
      end;
  end;
end;
procedure TMainFmx.btnMdSubClick(Sender: TObject);
var
  S: string;
begin
  if edtMdInstr = nil then
    Exit;
  S := Trim(edtMdInstr.Text);
  if S = '' then
  begin
    AddLog('[MD] 请先输入合约代码',True);
    Exit;
  end;
  try
    Ctp.mdSubscribe(StringToJString(S));
  except
    on E: Exception do
      AddLog('[MD] 订阅异常: ' + E.Message,True);
  end;
end;
procedure TMainFmx.btnMdUnsubClick(Sender: TObject);
var
  S: string;
begin
  if edtMdInstr = nil then
    Exit;
  S := Trim(edtMdInstr.Text);
  if S = '' then
  begin
    AddLog('[MD] 请先输入要退订的合约代码(或点行内「退订」按钮)');
    Exit;
  end;
  try
    Ctp.mdUnsubscribe(StringToJString(S));
  except
    on E: Exception do
      AddLog('[MD] 退订异常: ' + E.Message);
  end;
end;
procedure TMainFmx.BtnOkClick(Sender: TObject);
begin
  // 示例校验：非空
  if Trim(EditInput.Text) = '' then
  begin
    AddLog('配置名不能为空',true);
    Exit;
  end;
  CloseDialog(mmo1,EditInput,mrOk,FCallback,RectMask);
end;
{ 事件统一分发: 行情快照(MDQ|)不进日志, 直接刷新行情表; 其它照常进日志。
  交易登录成功后自动启动行情(连接/登录/重订阅全部在 Java 层自动完成)。 }
procedure TMainFmx.HandleEvent(const AEvent: string);
begin
  if AEvent.StartsWith('MDQ|', True) then
  begin
    try
      UpdateQuote(AEvent.Split(['|']));
    except
      // 单条行情解析失败不影响其它
    end;
    Exit;
  end;
  AddLog(AEvent);
  // [SYS] 登录成功 → 删除临时登录 ini + 启动行情
  if (not FMdStarted) and (Pos('[SYS] 登录成功', AEvent) > 0) then
  begin
    FMdStarted := True;
    DeleteLoginIni;   // 登录完成, 私有目录的一次性登录 ini 立即删除
    try
      BuildMdUI;
      Ctp.mdStart;
      AddLog('[MD] 已请求启动行情, 等待行情前置连接...');
    except
      on E: Exception do
        AddLog('[MD] 启动行情异常: ' + E.Message);
    end;
  end;
  // 交易会话结束(释放/断开)后, 允许下次登录重新启动行情
  if (Pos('API 已释放', AEvent) > 0) or (Pos('[SYS] 前置连接断开', AEvent) > 0) then
    FMdStarted := False;
end;
{ 取合约对应的 item, 不存在则新建一行并放入行情表。FQuoteInstrs 与
  lv11.Items 按下标一一对应。 }
function TMainFmx.QuoteItem(const AInstr: string): TListViewItem;
var
  I: Integer;
begin
  if FQuoteInstrs = nil then
    FQuoteInstrs := TStringList.Create;
  I := FQuoteInstrs.IndexOf(AInstr);
  if I >= 0 then
    Exit(lv11.Items[I]);
  //if lv11.ItemHeight < 50 then
  //  lv11.ItemHeight := 52;
  Result := lv11.Items.Add;
  Result.Data['Text1'] := AInstr;
  Result.Data['Text2'] := '--';
  Result.Data['Text3'] := '--';
  Result.Data['Text4'] := '--';
  FQuoteInstrs.Add(AInstr);
end;
{ 把 MDQ 事件的字段写入 item:
  Parts: 0=MDQ 1=合约 2=最新 3=昨结/昨收 4=开 5=高 6=低 7=成交量
         8=买一 9=买一量 10=卖一 11=卖一量 12=持仓 13=涨停 14=跌停 15=时间 16=毫秒
  颜色遵循国内惯例: 红涨绿跌。 }
procedure TMainFmx.UpdateQuote(const Parts: TArray<string>);
var
  Item: TListViewItem;
  Last, Pre, Chg: Double;
  ColMain, ColChg: TAlphaColor;
  function F(const S: string): Double;
  begin
    Result := StrToFloatDef(S, 0);
  end;
  procedure SetText(const AName, AText: string; const AColor: TAlphaColor);
  var
    D: TListItemText;
  begin
    D := Item.Objects.FindDrawable(AName) as TListItemText;
    if D = nil then
      Exit;
    D.Text := AText;
    if AColor <> TAlphaColors.Null then
      D.TextColor := AColor;
  end;
begin
  if Length(Parts) < 16 then
    Exit;
  Item := QuoteItem(Parts[1]);
  Last := F(Parts[2]);
  Pre := F(Parts[3]);
  Chg := 0;
  if Pre > 0 then
    Chg := Last - Pre;
  if Pre <= 0 then
  begin
    ColMain := TAlphaColors.Black;
    ColChg := TAlphaColors.Dimgray;
  end
  else if Last > Pre then
  begin
    ColMain := TAlphaColors.Red;
    ColChg := TAlphaColors.Red;
  end
  else if Last < Pre then
  begin
    ColMain := TAlphaColors.Green;
    ColChg := TAlphaColors.Green;
  end
  else
  begin
    ColMain := TAlphaColors.Black;
    ColChg := TAlphaColors.Dimgray;
  end;
  SetText('Text1', Parts[1], TAlphaColors.Null); // 合约名颜色用外观默认(steelblue)
  SetText('Text2', '现价 ' +FormatFloat('0.00', Last), ColMain);
  SetText('Text3', '涨跌 ' + FormatFloat('+0.00;-0.00;0.00', Chg), ColChg);
  if Pre > 0 then
    SetText('Text4', '幅度 ' + FormatFloat('+0.00;-0.00;0.00', Chg / Pre * 100) + '%', ColChg)
  else
    SetText('Text4', '--', ColChg);
  SetText('Text5', '现手 ' + Parts[7], TAlphaColors.Dimgray);
  SetText('Text6', '持仓 ' + Parts[12], TAlphaColors.Dimgray);
  SetText('Text7', Parts[15], TAlphaColors.Dimgray);
  SetText('Text8', '买一 ' + FormatFloat('0.00', F(Parts[8])), TAlphaColors.Red);
  SetText('Text9', Parts[9], TAlphaColors.Red);
  SetText('Text10', '卖一 ' + FormatFloat('0.00', F(Parts[10])), TAlphaColors.Green);
  SetText('Text11', Parts[11], TAlphaColors.Green);
  SetText('Text12', '开盘 ' + FormatFloat('0.00', F(Parts[4])), TAlphaColors.Dimgray);
  SetText('Text13', '最高 ' + FormatFloat('0.00', F(Parts[5])), TAlphaColors.Dimgray);
  SetText('Text14', '最低 ' + FormatFloat('0.00', F(Parts[6])), TAlphaColors.Dimgray);
  SetText('Text15', '涨停 ' + FormatFloat('0.00', F(Parts[13])), TAlphaColors.Dimgray);
  SetText('Text16', '跌停 ' + FormatFloat('0.00', F(Parts[14])), TAlphaColors.Dimgray);
  SetText('Text18', '昨收 ' + FormatFloat('0.00', F(Parts[2])), TAlphaColors.Dimgray);
end;
{ 行内「退订」按钮(TextButton3): 退订该行合约并把该行从行情表移除。 }
procedure TMainFmx.lv11ButtonClick(const Sender: TObject; const AItem: TListItem;
  const AObject: TListItemSimpleControl);
var
  I: Integer;
  Instr: string;
begin
  if (AObject = nil) or (AItem = nil) then
    Exit;
  if AObject.Name <> 'TextButton3' then
    Exit;
  var vAItem := lv11.Items[lv11.ItemIndex];
  Instr := trim((vAItem.Objects.FindDrawable('Text1') as TListItemText).Text ) ;
  try
    if FCtp <> nil then
      FCtp.mdUnsubscribe(StringToJString(Instr));
  except
    on E: Exception do
      AddLog('[MD] 退订异常: ' + E.Message);
  end;
  Sleep(200);
  {I := (AItem as TListViewItem).Index;
  if (FQuoteInstrs = nil) or (I < 0) or (I >= FQuoteInstrs.Count) then
    Exit;
  Instr := FQuoteInstrs[I];
  var vAItem := lv11.Items[lv11.ItemIndex];
  Instr := trim((vAItem.Objects.FindDrawable('Text1') as TListItemText).Text ) ;
  try
    if FCtp <> nil then
      FCtp.mdUnsubscribe(StringToJString(Instr));
  except
    on E: Exception do
      AddLog('[MD] 退订异常: ' + E.Message);
  end;  }
  try
    LvItemBeDeleteIndex := (AItem as TListViewItem).Index;
    {
    lv11.BeginUpdate;
    try
      lv11.Items.Delete(I); //由定时器删除 在lv中删除出错。
    finally
      lv11.EndUpdate;
    end;
    AddLog('[MD] 已退订并移除: ' + Instr);
    }
  except
    on E: Exception do AddLog('[MD] 已退订并移除: ' + Instr+' 异常: ' + E.Message);
  end;
end;
{ 保存配置: 把 tbtmIni 页参数控件 + 登录页账号密码写入数据库
  (CTPConFig 主表 + TDMDFrontLST 前置地址表), 同名配置覆盖。 }
procedure TMainFmx.btn1Click(Sender: TObject);
var
  Name1: string;
  Idx: Integer;
begin
  Name1 := 'ctp_new';
  Idx := cbbIniFLst.ItemIndex;
  if Idx >= 0 then
    Name1 := cbbIniFLst.Items[Idx]; // 默认覆盖当前选中项
  if btn1.Text='保存配置' then
    begin
      // 基本完整性检查: 缺了这些登录必失败, 存了也是废数据
      if lstTDFront.Items.Count = 0 then
      begin
        AddLog('交易前置列表为空, 请先在上方输入地址后点「添加」',True);
        Exit;
      end;
      if (Trim(edtBrokerID.Text) = '') or (Trim(edtusername.Text) = '')
        or (Trim(edtpassword.Text) = '') then
      begin
        AddLog('BrokerID / 账号 / 密码不能为空(账号密码在登录页)',True);
        Exit;
      end;

      var cp:TInputResultProc ;
      cp := procedure(const AResult: TModalResult; const AValue: string)
        begin
          if (AResult = mrOk) and (Trim(AValue) <> '') then DoSaveCfg(Trim(AValue));
        end;
      ShowInputDialog('请输入配置名(同名覆盖)', Name1, cp,FCallback,LabelTitle,EditInput,RectMask,0);
    end
  else
    begin
      var cp:TInputResultProc ;
      cp := procedure(const AResult: TModalResult; const AValue: string)
        begin
          if (AResult = mrOk) then DoDelCfg(Trim(AValue));
        end;
      ShowInputDialog('请确认是否删除配置(删除不可恢复)', Name1, cp,FCallback,LabelTitle,EditInput,RectMask,1);
    end;
end;
procedure TMainFmx.btnLoginClick(Sender: TObject);
var
  FlowPath, IniPath: string;
begin
  try
    // 1) 用当前界面参数(选中配置回填或手工修改后的值)在私有目录生成登录 ini
    IniPath := BuildLoginIni;
    // 2) 文件正确存在 -> 按 ini 登录(Java 侧解析, 支持多个前置故障切换)
    if (IniPath <> '') and System.IOUtils.TFile.Exists(IniPath) then
    begin
      AddLog('[UI] 按配置登录: ' + IniPath);
      Ctp.startFromIni(StringToJString(IniPath));
      Exit;
    end;
    // 3) ini 生成失败 -> 按参数控件中的参数直接登录(取第一个交易前置)
    if lstTDFront.Items.Count = 0 then
    begin
      AddLog('[UI] 没有交易前置地址, 无法登录', True);
      Exit;
    end;
    FlowPath := Trim(FCurFlowPath);
    if FlowPath = '' then
      FlowPath := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'ctpflow');
    Ctp.start(
      StringToJString(lstTDFront.Items[0]),
      StringToJString(FlowPath),
      FCurProduction <> 0,
      StringToJString(Trim(edtBrokerID.Text)),
      StringToJString(Trim(edtusername.Text)),
      StringToJString(Trim(edtpassword.Text)),
      StringToJString(Trim(edtusername.Text)),
      StringToJString(Trim(edtProduct.Text)),
      StringToJString(Trim(edtAppID.Text)),
      StringToJString(Trim(edtAuthCode.Text)));
    AddLog('[UI] 已发起连接(界面参数)');
  except
    on E: Exception do
      AddLog('[UI] 连接异常: ' + E.Message);
  end;

end;

procedure TMainFmx.BtnCancelClick(Sender: TObject);
begin
  CloseDialog(mmo1,EditInput,mrCancel,FCallback,RectMask);
end;
procedure TMainFmx.btnMDFrontClick(Sender: TObject);
begin
  if (btnMDFront.Text = '添加') and (Trim(edtMDFrontAddress.Text)<>'') then
    begin
      lstMDFront.Items.Add(Trim(edtMDFrontAddress.Text));
    end;
  if (btnMDFront.Text = '删除') and (lstMDFront.ItemIndex>=0) then
    begin
      lstMDFront.Items.Delete(lstMDFront.ItemIndex);
      btnMDFront.Text := '';
      btnMDFront.Text := '添加' ;
    end;
  btn1.Text := '保存配置';
end;
function TMainFmx.Ctp: JCtpBridge;
begin
  if FCtp = nil then
    FCtp := TJCtpBridge.JavaClass.init;
  Result := FCtp;
end;
procedure TMainFmx.edtBrokerIDChange(Sender: TObject);
begin
  btn1.Text := '保存配置';
end;

procedure TMainFmx.edtMDFrontAddressKeyUp(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  btnMDFront.Text := '添加';
end;
procedure TMainFmx.edtTDFrontAddressKeyUp(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  btnTDFront.Text := '添加';
end;
procedure TMainFmx.lstMDFrontClick(Sender: TObject);
begin
  if lstMDFront.ItemIndex>=0 then
    begin
      edtMDFrontAddress.Text := lstMDFront.Items[lstMDFront.ItemIndex];
      btnMDFront.Text := '删除';
    end;
end;
procedure TMainFmx.lstTDFrontClick(Sender: TObject);
begin
  if lstTDFront.ItemIndex>=0 then
    begin
      edtTDFrontAddress.Text := lstTDFront.Items[lstTDFront.ItemIndex];
      btnTDFront.Text := '删除';
    end;
end;
procedure TMainFmx.lv11Change(Sender: TObject);
begin
  if (edtMdInstr<>nil) and (lv11.ItemIndex>=0) and (lv11.ItemIndex<lv11.Items.Count) then
    begin
      var vAItem:TListViewItem;
      vAItem := lv11.Items[lv11.ItemIndex];
      edtMdInstr.Text := trim((vAItem.Objects.FindDrawable('Text1') as TListItemText).Text );
    end;
end;
procedure TMainFmx.lv11Click(Sender: TObject);
begin
  {
  AItem := lv12.Items.Add;
                            (AItem.Objects.FindDrawable('Text1') as TListItemText).Text := trim(fdqry1.FieldByname('序号').AsString);
                            (AItem.Objects.FindDrawable('Text2') as TListItemText).Text := '住址:'+trim(fdqry1.FieldByname('住址').AsString);
                            (AItem.Objects.FindDrawable('Text4') as TListItemText).Text := trim(fdqry1.FieldByname('姓名').AsString);
                            (AItem.Objects.FindDrawable('Text10') as TListItemText).Text := trim(fdqry1.FieldByname('性别').AsString);
                            (AItem.Objects.FindDrawable('Text5') as TListItemText).Text := trim(fdqry1.FieldByname('身份证号').AsString);
                            (AItem.Objects.FindDrawable('Text6') as TListItemText).Text := trim(fdqry1.FieldByname('电话').AsString);
                            (AItem.Objects.FindDrawable('Text7') as TListItemText).Text := '楼号:'+trim(fdqry1.FieldByname('楼号').AsString);
                            (AItem.Objects.FindDrawable('Text8') as TListItemText).Text := '单元号:'+trim(fdqry1.FieldByname('单元号').AsString);
                            (AItem.Objects.FindDrawable('Text9') as TListItemText).Text := '门牌号:'+trim(fdqry1.FieldByname('门牌号').AsString);
                            (AItem.Objects.FindDrawable('Text11') as TListItemText).Text := '备注:'+trim(fdqry1.FieldByname('备注').AsString);
                            (AItem.Objects.FindDrawable('Text12') as TListItemText).Text := trim(fdqry1.FieldByname('姓名缩写').AsString);
                            (AItem.Objects.FindDrawable('Text13') as TListItemText).Text := trim(fdqry1.FieldByname('js').AsString);
  }
end;

procedure TMainFmx.RequestAndroidPermissions;
begin
  // 看穿式监管的采集模块需要位置与设备状态权限, 否则登录可能被柜台拒绝
  try
    PermissionsService.RequestPermissions(
      ['android.permission.ACCESS_FINE_LOCATION',
       'android.permission.ACCESS_COARSE_LOCATION',
       'android.permission.READ_PHONE_STATE'], nil);
  except
    // 权限申请失败不阻塞启动
  end;
end;
procedure TMainFmx.UpdateStatus;
var
  Txt: string;
begin
  if FCtp = nil then
    Txt := '未连接'
  else
    try
      if FCtp.isLoggedIn then
        Txt := '已登录  交易日 ' + JStringToString(FCtp.getTradingDay)
          + '  FrontID=' + IntToStr(FCtp.getFrontId)
          + '  SessionID=' + IntToStr(FCtp.getSessionId)
      else if FCtp.isConnected then
        Txt := '前置已连接, 正在登录...'
      else
        Txt := '未连接';
    except
      Txt := '状态未知';
    end;
  // 定时器每 tick 都会调到这里, 状态没变就不再写日志, 否则日志页会被"未连接"刷满
  if Txt <> FLastStatus then
  begin
    FLastStatus := Txt;
    AddLog(Txt);
  end;
end;
procedure TMainFmx.tmr1Timer(Sender: TObject);
var
  Arr: TJavaObjectArray<JString>;
  I: Integer;
  LastMsg: string;
begin
  // 启动后首个 tick 扫描一次应用目录下的 ini, 填充 cbbIniFLst
  if not FIniFilled then
  begin
    FIniFilled := True;
    try
      FillIniList;
    except
      on E: Exception do
        AddLog('[INI] 扫描 ini 列表异常: ' + E.Message);
    end;
  end;
  if FCtp = nil then
    Exit;
  try
    Arr := FCtp.pollEvents;
    if (Arr <> nil) and (Arr.Length > 0) then
    begin
      LastMsg := '';
      for I := 0 to Arr.Length - 1 do
      begin
        LastMsg := JStringToString(Arr[I]);
        HandleEvent(LastMsg);
      end;
      // 注意: 循环结束后 I 已经等于 Arr.Length, 再取 Arr[I] 会越界。
      // JNI 的 GetObjectArrayElement 越界会抛 ArrayIndexOutOfBoundsException,
      // Delphi 不会清除该 pending 异常, 下一次调用 isLoggedIn 时 ART 直接 abort。
      // 这里改用循环里缓存的最后一条消息, 不再二次访问数组。
      if (LastMsg <> '') and not LastMsg.StartsWith('MDQ|', True) then
        UpdateStatus;
    end;
  except
    // 轮询期间忽略异常, 避免定时器中断
  end;
  if LvItemBeDeleteIndex>=0 then
    begin
      var vAItem := lv11.Items[LvItemBeDeleteIndex];
      var Instr := (vAItem.Objects.FindDrawable('Text1') as TListItemText).Text;
      lv11.BeginUpdate;
      try
        lv11.Items.Delete(LvItemBeDeleteIndex);//由定时器删除 在lv中删除出错。
        FQuoteInstrs.Delete(LvItemBeDeleteIndex);
        AddLog('[MD] 已退订并移除: ' + Instr);
      except
        on E: Exception do AddLog('[MD] 已退订并移除: ' + Instr + ' Instr异常: ' + E.Message);
      end;
      lv11.EndUpdate;
      LvItemBeDeleteIndex := -1 ;
    end;
end;
end.
