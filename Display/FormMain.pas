Unit FormMain;

{$mode objfpc}{$H+}

// 4D
Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin,
  ExtCtrls, SerialSpammer, LazSerial;

Type

  { TfrmMain }

  TfrmMain = Class(TForm)
    btnSerial: TButton;
    btnStart: TButton;
    lblHeading: TLabel;
    lblPitch: TLabel;
    lblRoll: TLabel;
    edtDepth: TFloatSpinEdit;
    lblDepth: TLabel;
    edtHeading: TFloatSpinEdit;
    edtPitch: TFloatSpinEdit;
    edtRoll: TFloatSpinEdit;
    memInfo: TMemo;
    memOutput: TMemo;
    Panel1: TPanel;
    Timer1: TTimer;
    procedure btnSerialClick(Sender: TObject);
    Procedure btnStartClick(Sender: TObject);
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure Timer1Timer(Sender: TObject);
  Private
    FSerial: TLazSerial;
    FSpammer: TSerialSpammer;
  Public

  End;

Const
  NMEA_POSII_STR: String = '$POSII,D,%.1f,H,%d,R,%d,P,%d*';

Var
  frmMain: TfrmMain;

Implementation

Uses
  GPSSupport;

  {$R *.lfm}

  { TfrmMain }

Procedure TfrmMain.FormCreate(Sender: TObject);
Begin
  FSerial := TLazSerial.Create(Self);
  FSerial.BaudRate:=br__9600;
  FSpammer := TSerialSpammer.Create(FSerial);
End;

Procedure TfrmMain.btnStartClick(Sender: TObject);
Begin
  If btnStart.Caption = 'Stop' Then
  Begin
    If FSerial.Active Then
      FSerial.Active := False;
  End
  Else
  Begin
    If Not FSerial.Active Then
    Try
      FSerial.Active := True;
    Except
      On E: Exception Do
        ShowMessage(E.Message);
    End;
  End;

  If FSerial.Active Then
    btnStart.Caption := 'Stop'
  Else
    btnStart.Caption := 'Start';
End;

procedure TfrmMain.btnSerialClick(Sender: TObject);
begin
  FSerial.ShowSetupDialog;
end;

Procedure TfrmMain.FormDestroy(Sender: TObject);
Begin
  If Assigned(FSpammer) Then
  Begin
    FSpammer.Terminate;
    FSpammer.WaitFor;
    FreeAndNil(FSpammer);
  End;

  If Assigned(FSerial) Then
  Begin
    If FSerial.Active Then
      FSerial.Close;
    FreeAndNil(FSerial);
  End;
End;

Procedure TfrmMain.Timer1Timer(Sender: TObject);
Var
  oState: TTelemetryState;
Begin
  oState := FSpammer.GetState;
  edtDepth.Value := oState.Depth;
  edtHeading.Value := oState.Heading;
  edtPitch.Value := oState.Pitch;
  edtRoll.Value := oState.Roll;

  memOutput.Lines.Text := FSpammer.GetHistory;
End;


End.
