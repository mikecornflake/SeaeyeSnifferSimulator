Unit SerialSpammer;

{-------------------------------------------------------------------------------
  Project   : SeaeyeSnifferSimulator
  Unit      : SerialSpammer (SerialSpammer.pas)
  Description
    Threaded class that simulates the state of an ROV and outputs this
    at a rate comparable with the SAAB Seaeye Outputs.

    SAAB Seaeye Outputs are either via the console (COM1 & "NMEA Outputs" menu option)
    or the older SeaeyeSniffer external box (hence the name of this software).

    This module is named SerialSpammer as the Seaeye outputs do not appear regulated
    but instead are output at maximum rate.  This makes sense when you consider the
    original SeaeyeSniffer unit simply listened to the telemetry between the
    ROV and the console and redirected specific fields to RS232.

    For the sake of CPU sanity, this module enforces a minimum 50ms delay between the
    broadcast of each string.

  Source
    Copyright (c) 2025
    Inspector Mike 2.0 Pty Ltd
    Mike Thompson (mike.cornflake@gmail.com)

  History
    2025-11-14: Creation.
    2025-11-28: Addition of $PC1 output
                Rationalised Simulation Code
                Allowed for variable delay between outputs
                Addition of this header

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

Interface

Uses
  Classes, SysUtils, SyncObjs, LazSerial;

Type
  TTelemetryState = Record
    Depth: Double;
    Heading: Double;
    Pitch: Double;
    Roll: Double;
    CP: Double;
  End;

  TSimulationBounds = Record
    Max: Double;
    Min: Double;
    Step: Double;
    Dirn: Integer;
  End;

  { TSerialSpammer }

  TSerialSpammer = Class(TThread)
  Private
    FEnablePC1: Boolean;
    FEnablePOSII: Boolean;
    FLock: TCriticalSection;
    FmsDelay: Integer;
    FSerial: TLazSerial;

    FState: TTelemetryState;
    FDepthSim: TSimulationBounds;
    FHeadingSim: TSimulationBounds;
    FPitchSim: TSimulationBounds;
    FRollSim: TSimulationBounds;
    FCPSim: TSimulationBounds;

    Procedure SetmsDelay(AValue: Integer);
    Procedure UpdateValues;

    Function FormatPOSII: String;
    Function FormatPC1: String;
  Protected
    FHistory: TStringList;

    Procedure Execute; Override;
  Public
    Constructor Create(ASerialPort: TLazSerial);
    Destructor Destroy; Override;

    Function GetState: TTelemetryState;
    Function GetHistory: String;

    Property msDelay: Integer Read FmsDelay Write SetmsDelay;

    Property EnablePOSII: Boolean Read FEnablePOSII Write FEnablePOSII;
    Property EnablePC1: Boolean Read FEnablePC1 Write FEnablePC1;
  End;

Implementation

Uses
  GPSSupport;

Const
  // Seaeye Falcon
  NMEA_POSII_STR = '$POSII,D,%.1f,H,%d,R,%d,P,%d*';

  // Seaeye Cougar (It's an older model Sir, but it checks out)
  NMEA_PC1_STR = '$PC1,%.1f,%.1f,%.3f';

  { TSerialSpammer }

Constructor TSerialSpammer.Create(ASerialPort: TLazSerial);

  Function InitSim(AMax, AMin, AStep: Double; ADirn: Integer): TSimulationBounds;
  Begin
    Result.Max := AMax;
    Result.Min := AMin;
    Result.Step := AStep;
    Result.Dirn := ADirn;
  End;

Begin
  Inherited Create(False);
  FreeOnTerminate := False;

  FEnablePOSII := True;
  FEnablePC1 := True;

  FmsDelay := 60; // Delay between string broadcasts

  FLock := TCriticalSection.Create;
  FSerial := ASerialPort;

  FHistory := TStringList.Create;
  FHistory.LineBreak := LineEnding;

  // Initialise values
  FState.Depth := 6.0;
  FDepthSim := InitSim(60, 5, 0.015, 1);

  FState.Heading := 90;
  FHeadingSim := InitSim(360, 0, 0.5, 1);

  FState.Pitch := 2.0;
  FPitchSim := InitSim(10, -10, 0.01, -1);

  FState.Roll := -3.0;
  FRollSim := InitSim(10, -10, 0.01, 1);

  FState.CP := -1.0;
  FCPSim := InitSim(-0.55, -1.04, 0.001, -1);
End;

Destructor TSerialSpammer.Destroy;
Begin
  FreeAndNil(FLock);
  FreeAndNil(FHistory);

  Inherited Destroy;
End;

Procedure TSerialSpammer.Execute;
Var
  s: String;
  bAlreadySent: Boolean;
Begin
  While Not Terminated Do
  Begin
    UpdateValues;

    If FSerial.Active Then
    Begin
      bAlreadySent := False;

      If FEnablePOSII Then
      Begin
        s := FormatPOSII;
        FSerial.WriteData(s + LineEnding);

        bAlreadySent := True;
      End;

      If FEnablePC1 Then
      Begin
        If bAlreadySent Then
          Sleep(FmsDelay);

        s := FormatPC1;
        FSerial.WriteData(s + LineEnding);
      End;
    End;

    Sleep(FmsDelay);
  End;
End;

Procedure TSerialSpammer.UpdateValues;

  Function Update(AOldValue: Double; Var ASim: TSimulationBounds): Double;
  Begin
    If (AOldValue >= ASim.Max) Or (AOldValue <= ASim.Min) Then
      ASim.Dirn := -ASim.Dirn;

    Result := AOldValue + ASim.Step * ASim.Dirn;
  End;

Begin
  If Not Assigned(FLock) Then
    Exit;

  FLock.Acquire;
  Try
    FState.Depth := Update(FState.Depth, FDepthSim);
    FState.Heading := Update(FState.Heading, FHeadingSim);
    FState.Pitch := Update(FState.Pitch, FPitchSim);
    FState.Roll := Update(FState.Roll, FRollSim);
    FState.CP := Update(FState.CP, FCPSim);
  Finally
    FLock.Release;
  End;
End;

Procedure TSerialSpammer.SetmsDelay(AValue: Integer);
Begin
  If (FmsDelay = AValue) Then
    Exit;

  // Ensure this isn't so small it causes this thread to hog the CPU...
  If (AValue <= 50) Then
    FmsDelay := 50
  Else
    FmsDelay := AValue;
End;

Function TSerialSpammer.FormatPOSII: String;
Begin
  Result := Format(NMEA_POSII_STR, [FState.Depth, Round(FState.Heading),
    Round(FState.Pitch), Round(FState.Roll)]);
  Result := Result + NMEA_ChecksumAsHex(Result);

  FHistory.Add(Result);
End;

Function TSerialSpammer.FormatPC1: String;
Begin
  // Note: Not a real NMEA String (No checksum)
  Result := Format(NMEA_PC1_STR, [FState.Depth, FState.Heading, FState.CP]);

  FHistory.Add(Result);
End;

Function TSerialSpammer.GetState: TTelemetryState;
Begin
  If Not Assigned(FLock) Then
    Exit;

  FLock.Acquire;
  Try
    Result := FState;
  Finally
    FLock.Release;
  End;
End;

Function TSerialSpammer.GetHistory: String;
Begin
  If Not Assigned(FLock) Then
    Exit;

  FLock.Acquire;
  Try
    Result := FHistory.Text;
    FHistory.Clear;
  Finally
    FLock.Release;
  End;
End;

End.
