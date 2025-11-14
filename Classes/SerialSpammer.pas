Unit SerialSpammer;

Interface

Uses
  Classes, SysUtils, SyncObjs, LazSerial;

Type
  TTelemetryState = Record
    Depth: Double;
    Heading: Integer;
    Pitch: Integer;
    Roll: Integer;
  End;

  { TSerialSpammer }

  TSerialSpammer = Class(TThread)
  Private
    FLock: TCriticalSection;
    FState: TTelemetryState;
    FSerial: TLazSerial;
    FDepth, FDepthStep: Double;
    FHeading: Double;
    FPitch, FPitchStep: Double;
    FRoll, FRollStep: Double;
    FDepthDir, FPitchDir, FRollDir: Integer;
    Procedure UpdateValues;
    Function FormatNMEA: String;
  Protected
    FHistory: TStringList;

    Procedure Execute; Override;
  Public
    Constructor Create(ASerialPort: TLazSerial);
    Destructor Destroy; Override;

    Function GetState: TTelemetryState;
    Function GetHistory: String;
  End;

Implementation

Uses
  GPSSupport;

Const
  NMEA_POSII_STR = '$POSII,D,%.1f,H,%d,R,%d,P,%d*';

  { TSerialSpammer }

Constructor TSerialSpammer.Create(ASerialPort: TLazSerial);
Begin
  Inherited Create(False);
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FSerial := ASerialPort;

  FHistory := TStringList.Create;
  FHistory.LineBreak := LineEnding;

  // Initial values
  FDepth := 5.0;
  FDepthStep := 0.15;
  FDepthDir := 1;

  FHeading := 0;

  FPitch := 10.0;
  FPitchStep := 0.1;
  FPitchDir := -1;

  FRoll := -10.0;
  FRollStep := 0.1;
  FRollDir := 1;
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
Begin
  While Not Terminated Do
  Begin
    UpdateValues;

    If FSerial.Active Then
    Begin
      s := FormatNMEA;

      FSerial.WriteData(s + LineEnding);
    End;

    Sleep(100);
  End;
End;

Procedure TSerialSpammer.UpdateValues;
Begin
  If Not Assigned(FLock) Then
    Exit;

  FLock.Acquire;
  Try
    // Depth bounce
    FDepth := FDepth + FDepthStep * FDepthDir;
    If (FDepth >= 60) Or (FDepth <= 5) Then
      FDepthDir := -FDepthDir;

    // Heading wrap
    FHeading := FHeading + 0.5;
    If FHeading >= 360 Then
      FHeading := FHeading - 360;

    // Pitch bounce
    FPitch := FPitch + FPitchStep * FPitchDir;
    If (FPitch >= 10) Or (FPitch <= -10) Then
      FPitchDir := -FPitchDir;

    // Roll bounce
    FRoll := FRoll + FRollStep * FRollDir;
    If (FRoll >= 10) Or (FRoll <= -10) Then
      FRollDir := -FRollDir;

    // Update shared state
    FState.Depth := FDepth;
    FState.Heading := Round(FHeading);
    FState.Pitch := Round(FPitch);
    FState.Roll := Round(FRoll);
  Finally
    FLock.Release;
  End;
End;

Function TSerialSpammer.FormatNMEA: String;
Begin
  Result := Format(NMEA_POSII_STR, [FDepth, Round(FHeading), Round(FPitch), Round(FRoll)]);
  Result := Result + NMEA_ChecksumAsHex(Result);

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
