unit frmEnumerateDLLsUnit;

{$MODE Delphi}

interface

uses
  windows, LCLIntf, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs,CEFuncProc,imagehlp, StdCtrls, ComCtrls, ExtCtrls, ActnList,
  Menus, LResources,symbolhandler;

type tenumthread=class(tthread)
  public
    symbolcount: integer;
    moduletext: string;
    symbolname: array [1..25] of string;
    x: TTreenode;
    procedure AddModule;
    procedure AddSymbol;
    procedure Done;
    procedure execute; override;
end;

type
  TfrmEnumerateDLLs = class(TForm)
    Label2: TLabel;
    TreeView1: TTreeView;
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    FindDialog1: TFindDialog;
    ActionList1: TActionList;
    Find: TAction;
    pmSymbol: TPopupMenu;
    Find1: TMenuItem;
    procedure Button1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure TreeView1DblClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FindExecute(Sender: TObject);
    procedure FindDialog1Find(Sender: TObject);
  private
    { Private declarations }
    enumthread: tenumthread;
  public
    { Public declarations }

    procedure Enumerate;

  end;

var
  frmEnumerateDLLs: TfrmEnumerateDLLs;

implementation

uses MemoryBrowserFormUnit;


var canceled: boolean; //global var for only this unit

procedure tenumthread.Done;
begin
  if frmEnumerateDLLs<>nil then
    frmEnumerateDLLs.button2.visible:=false
  else canceled:=true;

  if x<>nil then frmEnumerateDLLs.treeview1.EndUpdate;
end;

procedure tenumthread.addsymbol;
var i: integer;
begin

  if frmEnumerateDLLs<>nil then
  begin
    for i:=1 to symbolcount do
      frmEnumerateDLLs.treeview1.items.addchild(x,symbolname[i]);
  end else canceled:=true;

  symbolcount:=0;
end;

procedure tenumthread.AddModule;
begin
  if frmEnumerateDLLs<>nil then
  begin
    if x<>nil then frmEnumerateDLLs.treeview1.EndUpdate;

    x:=frmEnumerateDLLs.treeview1.items.add(nil,moduletext);
    frmEnumerateDLLs.treeview1.BeginUpdate;
  end else canceled:=true;
end;

function ES(SymName:PSTR; SymbolAddress:dword64; SymbolSize:ULONG; UserContext:pointer):bool;stdcall;
begin
  with tenumthread(usercontext) do
  begin
    inc(symbolcount);
    symbolname[symbolcount]:=IntToHex(SymbolAddress,8)+' - '+SymName+' ('+IntToStr(SymbolSize)+')';

    if symbolcount=25 then
      Synchronize(addsymbol);
    result:=not canceled;
  end;
end;

function EM(ModuleName:PSTR; BaseOfDll:dword64; UserContext:pointer):bool;stdcall;
begin
  result:=not canceled;

  with tenumthread(usercontext) do
  begin
    if symbolcount>0 then
      synchronize(addsymbol);
    moduletext:=IntToHex(BaseOfDll,8)+' - '+ModuleName;
    Synchronize(addmodule);
  end;
  SymEnumerateSymbols64(processhandle,BaseOfDLL,@ES,usercontext);

end;

procedure tenumthread.execute;
begin
  freeonterminate:=true;
  symbolcount:=0;
  Priority:=tpLower;

  symhandler.waitforsymbolsloaded;
  
  if not canceled then
    SymEnumerateModules64(processhandle,@EM,self);

  if symbolcount>0 then
    synchronize(addsymbol);

  synchronize(done);
end;

procedure TfrmEnumerateDLLs.Enumerate;
var crashcount: integer;
begin
  treeview1.items.Clear;

  canceled:=false;
  enumthread:=tenumthread.create(false);

  frmEnumerateDLLs.TreeView1.SortType:=stText;
end;

procedure TfrmEnumerateDLLs.Button1Click(Sender: TObject);
begin
  close;
end;

procedure TfrmEnumerateDLLs.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  canceled:=true;
  action:=cafree;
  frmEnumerateDLLS:=nil;
end;

procedure TfrmEnumerateDLLs.FormShow(Sender: TObject);
begin
  enumerate;
end;

procedure TfrmEnumerateDLLs.TreeView1DblClick(Sender: TObject);
var address: ptrUint;
    i: integer;
    s: string;
begin
  if Treeview1.Selected<>nil then
  begin
    if treeview1.Selected.Level=1 then
    begin
      //showmessage('dblclick: '+treeview1.Selected.Text);
      s:='';
      for i:=1 to length(treeview1.Selected.Text)-1 do
        if not (treeview1.Selected.Text[i] in ['0'..'9','a'..'f','A'..'F'] ) then
        begin
          s:=copy(treeview1.Selected.Text,1,i-1);
          break;
        end;


      if s='' then //should never happen
        s:=treeview1.Selected.Text;

      address:=strtoint64('$'+s);
      { val('$'+s,address,i); fpc 2.4.1 doesn't handle this correctly }

     //showmessage('s='+s+' address='+inttohex(address,8));
      memorybrowser.disassemblerview.SelectedAddress:=address;
    end;
  end;
end;

procedure TfrmEnumerateDLLs.Button2Click(Sender: TObject);
begin
  canceled:=true;
end;

procedure TfrmEnumerateDLLs.FindExecute(Sender: TObject);
begin
  finddialog1.Execute;
end;

procedure TfrmEnumerateDLLs.FindDialog1Find(Sender: TObject);
var current: ttreenode;
    i,j: integer;

begin
  if treeview1.Selected=nil then
    current:=treeview1.Items.GetFirstNode
  else
    current:=treeview1.Selected;

  i:=current.AbsoluteIndex;
  if frFindNext in finddialog1.Options then
    inc(i);

  for j:=i to treeview1.Items.Count-1 do
  begin
    if pos(uppercase(finddialog1.FindText),uppercase(treeview1.Items[j].Text))>0 then
    begin
      treeview1.Selected:=treeview1.Items[j];
      exit;
    end;
  end;
  showmessage('nothing found');
end;

initialization
  {$i frmEnumerateDLLsUnit.lrs}

end.
