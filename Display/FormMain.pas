Unit FormMain;

{-------------------------------------------------------------------------------
  Project   : SeaeyeSnifferSimulator
  Unit      : FormMain (FormMain.pas)
  Description
    Main Form that displays:
    - Current ROV Telemtry
    - Configure RS232
    - Allows for Start/Stop of RS232
    - Allows different strings to be sent
    - Displays log of all strings sent

  Source
    Copyright (c) 2025
    Inspector Mike 2.0 Pty Ltd
    Mike Thompson (mike.cornflake@gmail.com)

  History
    2025-11-14: Creation.
    2025-11-28: Addition of this header
                Expanded UI to include CP and two possible strings

  License
    This file is part of SeaeyeSnifferSimulator.

    It is free software: you can redistribute it and/or modify it under the
    terms of the GNU General Public License as published by the Free Software
    Foundation, either version 3 of the License, or (at your option) any
    later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <https://www.gnu.org/licenses/>.

    SPDX-License-Identifier: GPL-3.0-or-later
-------------------------------------------------------------------------------}

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}
Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin,
  ExtCtrls, Menus, SerialSpammer, LazSerial;

Type

  { TfrmMain }

  TfrmMain = Class(TForm)
    btnSerial: TButton;
    btnStart: TButton;
    chkStrings: TCheckGroup;
    edtCP: TFloatSpinEdit;
    lblHeading: TLabel;
    lblPitch: TLabel;
    lblRoll: TLabel;
    edtDepth: TFloatSpinEdit;
    lblDepth: TLabel;
    edtHeading: TFloatSpinEdit;
    edtPitch: TFloatSpinEdit;
    edtRoll: TFloatSpinEdit;
    lblCP: TLabel;
    MainMenu1: TMainMenu;
    memInfo: TMemo;
    memOutput: TMemo;
    mnuHelp: TMenuItem;
    mnuAbout: TMenuItem;
    Panel1: TPanel;
    Timer1: TTimer;
    Procedure btnSerialClick(Sender: TObject);
    Procedure btnStartClick(Sender: TObject);
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    procedure mnuAboutClick(Sender: TObject);
    Procedure Timer1Timer(Sender: TObject);
  Private
    FSerial: TLazSerial;
    FSpammer: TSerialSpammer;
  Public

  End;

Var
  frmMain: TfrmMain;

Implementation

Uses
  GPSSupport, FormAbout;

  {$R *.lfm}

  { TfrmMain }

Procedure TfrmMain.FormCreate(Sender: TObject);
Begin
  FSerial := TLazSerial.Create(Self);
  FSerial.BaudRate := br__9600;
  FSpammer := TSerialSpammer.Create(FSerial);

  chkStrings.Checked[0] := True;
  chkStrings.Checked[1] := True;
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

Procedure TfrmMain.btnSerialClick(Sender: TObject);
Begin
  FSerial.ShowSetupDialog;
End;

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

procedure TfrmMain.mnuAboutClick(Sender: TObject);
begin
  FormAbout.ShowAbout;
end;

Procedure TfrmMain.Timer1Timer(Sender: TObject);
Var
  oState: TTelemetryState;
Begin
  FSpammer.EnablePOSII:=chkStrings.Checked[0];
  FSpammer.EnablePC1:=chkStrings.Checked[1];

  oState := FSpammer.GetState;
  edtDepth.Value := oState.Depth;
  edtHeading.Value := oState.Heading;
  edtPitch.Value := oState.Pitch;
  edtRoll.Value := oState.Roll;
  edtCP.Value := oState.CP;

  memOutput.Lines.Text := FSpammer.GetHistory;
End;


End.
