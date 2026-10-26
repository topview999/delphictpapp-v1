unit MyShareProcedure;

interface
uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Edit, FMX.Objects,
  FMX.Layouts,u_Toast;
type
  TInputResultProc = reference to procedure(const AResult: TModalResult;const AValue: string);// System.UITypes

procedure CloseDialog(mmo1:tmemo;EditInput:TEdit;AResult: TModalResult;FCallback: TInputResultProc;RectMask: TRectangle);
procedure ShowInputDialog(const ATitle, ADefault: string;
  ACallback: TInputResultProc;var FCallback: TInputResultProc;LabelTitle:tlabel;EditInput:TEdit;RectMask: TRectangle);
procedure AddLog(mmo1:tmemo;const AText: string;showited:Boolean); overload;

implementation

procedure AddLog(mmo1:tmemo;const AText: string;showited:Boolean);
begin
  if mmo1 = nil then
    Exit;
  if mmo1.Lines.Count > 3000 then
    mmo1.Lines.Clear;
  mmo1.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AText);
  if showited then Toast(AText,TToastLength.ShortToast,TGravity.CENTER,50,50);
end;

procedure CloseDialog(mmo1:tmemo;EditInput:TEdit;AResult: TModalResult;FCallback: TInputResultProc;RectMask: TRectangle);
var
  LValue: string;
  LCallback: TInputResultProc;
begin
  LValue := EditInput.Text;
  LCallback := FCallback;
  FCallback := nil;

  RectMask.Visible := False;
  EditInput.SetFocus; // 先移走焦点，避免软键盘残留
  if Assigned(LCallback) then
    begin
      LCallback(AResult, LValue);
    end
  else
    begin
      AddLog(mmo1,'未能保存，回调为空！',True);
    end;
end;
procedure ShowInputDialog(const ATitle, ADefault: string;
  ACallback: TInputResultProc;var FCallback: TInputResultProc;LabelTitle:tlabel;EditInput:TEdit;RectMask: TRectangle);
begin
  FCallback := ACallback;
  LabelTitle.Text := ATitle;
  EditInput.Text := ADefault;
  //LabelHint.Text := '';
  RectMask.Position.Y := 100 ;
  RectMask.Position.x := 30 ;
  RectMask.Visible := True;
  RectMask.BringToFront;
  // 延迟聚焦，确保控件已可见，安卓软键盘才会弹出
  TThread.ForceQueue(nil,
    procedure
    begin
      EditInput.SetFocus;
    end, 200);
end;
end.
