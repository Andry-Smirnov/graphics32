unit GR32_VectorMaps;

(* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1 or LGPL 2.1 with linking exception
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * Alternatively, the contents of this file may be used under the terms of the
 * Free Pascal modified version of the GNU Lesser General Public License
 * Version 2.1 (the "FPC modified LGPL License"), in which case the provisions
 * of this license are applicable instead of those above.
 * Please see the file LICENSE.txt for additional information concerning this
 * license.
 *
 * The Original Code is GR32_VectorMaps
 *
 * The Initial Developer of the Original Code is
 * Michael Hansen <dyster_tid@hotmail.com>
 *
 * Portions created by the Initial Developer are Copyright (C) 2000-2009
 * the Initial Developer. All Rights Reserved.
 *
 * ***** END LICENSE BLOCK ***** *)

interface

{$include GR32.inc}

uses
{$if defined(UseInlining)}
  Types,
{$ifend}
  GR32;

type
  TFixedVector = TFixedPoint;
  PFixedVector = ^TFixedVector;
  TFloatVector = TFloatPoint;
  PFloatVector = ^TFloatVector;
  TArrayOfFixedVector = array of TFixedVector;
  PArrayOfFixedVector = ^TArrayOfFixedVector;
  TArrayOfFloatVector = array of TFloatVector;
  PArrayOfFloatVector = ^TArrayOfFixedVector;

type
  TVectorCombineMode = (vcmAdd, vcmReplace, vcmCustom);
  TVectorCombineEvent= procedure(F, P: TFixedVector; var B: TFixedVector) of object;

  TVectorMap = class(TCustomMap)
  private
    FVectors: TArrayOfFixedVector;
    FOnVectorCombine: TVectorCombineEvent;
    FVectorCombineMode: TVectorCombineMode;
    function GetVectors: PFixedPointArray;
    function GetFixedVector(X,Y: Integer): TFixedVector;
    function GetFixedVectorS(X,Y: Integer): TFixedVector;
    function GetFixedVectorX(X,Y: TFixed): TFixedVector;
    function GetFixedVectorXS(X,Y: TFixed): TFixedVector;
    function GetFloatVector(X,Y: Integer): TFloatVector;
    function GetFloatVectorS(X,Y: Integer): TFloatVector;
    function GetFloatVectorF(X,Y: Single): TFloatVector;
    function GetFloatVectorFS(X,Y: Single): TFloatVector;
    procedure SetFixedVector(X,Y: Integer; const Point: TFixedVector);
    procedure SetFixedVectorS(X,Y: Integer; const Point: TFixedVector);
    procedure SetFixedVectorX(X,Y: TFixed; const Point: TFixedVector);
    procedure SetFixedVectorXS(X,Y: TFixed; const Point: TFixedVector);
    procedure SetFloatVector(X,Y: Integer; const Point: TFloatVector);
    procedure SetFloatVectorS(X,Y: Integer; const Point: TFloatVector);
    procedure SetFloatVectorF(X,Y: Single; const Point: TFloatVector);
    procedure SetFloatVectorFS(X,Y: Single; const Point: TFloatVector);
    procedure SetVectorCombineMode(const Value: TVectorCombineMode);
  protected
    procedure ChangeSize(var Width, Height: Integer; NewWidth,
      NewHeight: Integer); override;
  public
    destructor Destroy; override;

    procedure Clear;
    procedure Merge(DstLeft, DstTop: Integer; Src: TVectorMap; SrcRect: TRect);

    property Vectors: PFixedPointArray read GetVectors;
    function BoundsRect: TRect;
    function GetTrimmedBounds: TRect;
    function Empty: Boolean; override;
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);

    property FixedVector[X, Y: Integer]: TFixedVector read GetFixedVector write SetFixedVector; default;
    property FixedVectorS[X, Y: Integer]: TFixedVector read GetFixedVectorS write SetFixedVectorS;
    property FixedVectorX[X, Y: TFixed]: TFixedVector read GetFixedVectorX write SetFixedVectorX;
    property FixedVectorXS[X, Y: TFixed]: TFixedVector read GetFixedVectorXS write SetFixedVectorXS;

    property FloatVector[X, Y: Integer]: TFloatVector read GetFloatVector write SetFloatVector;
    property FloatVectorS[X, Y: Integer]: TFloatVector read GetFloatVectorS write SetFloatVectorS;
    property FloatVectorF[X, Y: Single]: TFloatVector read GetFloatVectorF write SetFloatVectorF;
    property FloatVectorFS[X, Y: Single]: TFloatVector read GetFloatVectorFS write SetFloatVectorFS;
  published
    property VectorCombineMode: TVectorCombineMode read FVectorCombineMode write SetVectorCombineMode;
    property OnVectorCombine: TVectorCombineEvent read FOnVectorCombine write FOnVectorCombine;
  end;

implementation

uses
  SysUtils,
  GR32_Lowlevel,
  GR32_Math;

resourcestring
  RCStrCantAllocateVectorMap = 'Can''t allocate VectorMap!';
  RCStrBadFormat = 'Bad format - Photoshop .msh expected!';
  RCStrFileNotFound = 'File not found!';
  RCStrSrcIsEmpty = 'Src is empty!';
  RCStrBaseIsEmpty = 'Base is empty!';

{ TVectorMap }

function CombineVectorsReg(const A, B: TFixedVector; Weight: TFixed): TFixedVector;
begin
  Result.X := FixedCombine(Weight, B.X, A.X);
  Result.Y := FixedCombine(Weight, B.Y, A.Y);
end;

procedure CombineVectorsMem(const A: TFixedVector;var  B: TFixedVector; Weight: TFixed);
begin
  B.X := FixedCombine(Weight, B.X, A.X);
  B.Y := FixedCombine(Weight, B.Y, A.Y);
end;

function TVectorMap.BoundsRect: TRect;
begin
  Result := MakeRect(0, 0, Width, Height);
end;

procedure TVectorMap.ChangeSize(var Width, Height: Integer;
  NewWidth, NewHeight: Integer);
begin
  inherited;
  FVectors := nil;
  Width := 0;
  Height := 0;
  SetLength(FVectors, NewWidth * NewHeight);
  if (NewWidth > 0) and (NewHeight > 0) then
  begin
    if FVectors = nil then
      raise Exception.Create(RCStrCantAllocateVectorMap);
    FillLongword(FVectors[0], NewWidth * NewHeight * 2, 0);
  end;
  Width := NewWidth;
  Height := NewHeight;
end;

procedure TVectorMap.Clear;
begin
  FillLongword(FVectors[0], Width * Height * 2, 0);
end;

destructor TVectorMap.Destroy;
begin
  Lock;
  try
    SetSize(0, 0);
  finally
    Unlock;
  end;
  inherited;
end;

function TVectorMap.GetVectors: PFixedPointArray;
begin
  Result := @FVectors[0];
end;

function TVectorMap.GetFloatVector(X, Y: Integer): TFloatVector;
begin
  Result := FloatPoint(FVectors[X + Y * Width]);
end;

function TVectorMap.GetFloatVectorF(X, Y: Single): TFloatVector;
begin
  Result := FloatPoint(GetFixedVectorX(Fixed(X), Fixed(Y)));
end;

function TVectorMap.GetFloatVectorFS(X, Y: Single): TFloatVector;
begin
  Result := FloatPoint(GetFixedVectorXS(Fixed(X), Fixed(Y)));
end;

function TVectorMap.GetFloatVectorS(X, Y: Integer): TFloatVector;
begin
  if (X >= 0) and (Y >= 0) and
   (X < Width) and (Y < Height) then
     Result := GetFloatVector(X,Y)
    else
    begin
      Result.X := 0;
      Result.Y := 0;
    end;
end;

function TVectorMap.GetFixedVector(X, Y: Integer): TFixedVector;
begin
  Result := FVectors[X + Y * Width];
end;

function TVectorMap.GetFixedVectorS(X, Y: Integer): TFixedVector;
begin
  if (X >= 0) and (Y >= 0) and
    (X < Width) and (Y < Height) then
      Result := GetFixedVector(X,Y)
    else
    begin
      Result.X := 0;
      Result.Y := 0;
    end;
end;

function TVectorMap.GetFixedVectorX(X, Y: TFixed): TFixedVector;
const
  Next = SizeOf(TFixedVector);
var
  WX,WY: TFixed;
  W, H: Integer;
  P: Pointer;
begin
  WX := TFixedRec(X).Int;
  WY := TFixedRec(Y).Int;
  W := Width;
  H := Height;
  if (WX >= 0) and (WX <= W - 1) and (WY >= 0) and (WY <= H - 1) then
  begin
    P := @FVectors[WX + WY * W];
    if (WY = H - 1) then
      W := 0
    else
      W := W * Next;
    if (WX = W - 1) then
      H := 0
    else
      H := Next;
    WX := TFixedRec(X).Frac;
    WY := TFixedRec(Y).Frac;
    Result := CombineVectorsReg(CombineVectorsReg(PFixedPoint(P)^,
      PFixedPoint(NativeUInt(P) + NativeUInt(H))^, WX), CombineVectorsReg(
      PFixedPoint(NativeUInt(P) + NativeUInt(W))^,
      PFixedPoint(NativeUInt(P) + NativeUInt(W + H))^, WX), WY);
  end else
  begin
    Result.X := 0;
    Result.Y := 0;
  end;
end;

function TVectorMap.GetFixedVectorXS(X, Y: TFixed): TFixedVector;
var
  WX,WY: TFixed;
begin
  WX := TFixedRec(X).Frac;
  X := TFixedRec(X).Int;

  WY := TFixedRec(Y).Frac;
  Y := TFixedRec(Y).Int;

  Result := CombineVectorsReg(CombineVectorsReg(FixedVectorS[X,Y], FixedVectorS[X + 1,Y], WX),
                              CombineVectorsReg(FixedVectorS[X,Y + 1], FixedVectorS[X + 1,Y + 1], WX), WY);
end;

function TVectorMap.Empty: Boolean;
begin
  Result := false;
  if (Width = 0) or (Height = 0) or (FVectors = nil) then Result := True;
end;

const
  MeshIdent = 'yfqLhseM';

type
  {TVectorMap supports the photoshop liquify mesh fileformat .msh}
  TPSLiquifyMeshHeader = record
    Pad0  : cardinal;
    Ident : array [0..7] of Char;
    Pad1  : cardinal;
    Width : cardinal;
    Height: cardinal;
  end;

procedure TVectorMap.LoadFromFile(const FileName: string);

  procedure ConvertVertices;
  var
    I: Integer;
  begin
    for I := 0 to Length(FVectors) - 1 do
    begin
      //Not a mistake! Converting physical mem. directly to avoid temporary floating point buffer
      //Do no change to PFloat.. the type is relative to the msh format.
      FVectors[I].X := Fixed(PSingle(@FVectors[I].X)^);
      FVectors[I].Y := Fixed(PSingle(@FVectors[I].Y)^);
    end;
  end;

var
  Header: TPSLiquifyMeshHeader;
  MeshFile: File;
begin
  If FileExists(Filename) then
  try
    AssignFile(MeshFile, FileName);
    Reset(MeshFile, 1);
    BlockRead(MeshFile, Header, SizeOf(TPSLiquifyMeshHeader));
    if LowerCase(string(Header.Ident)) <> LowerCase(MeshIdent) then
      Exception.Create(RCStrBadFormat);
    with Header do
    begin
      SetSize(Width, Height);
      BlockRead(MeshFile, FVectors[0], Width * Height * SizeOf(TFixedVector));
      ConvertVertices;
    end;
  finally
    CloseFile(MeshFile);
  end
    else Exception.Create(RCStrFileNotFound);
end;

procedure TVectorMap.Merge(DstLeft, DstTop: Integer; Src: TVectorMap; SrcRect: TRect);
var
  I,J,P: Integer;
  DstRect: TRect;
  Progression: TFixedVector;
  ProgressionX, ProgressionY: TFixed;
  CombineCallback: TVectorCombineEvent;
  DstPtr : PFixedPointArray;
  SrcPtr : PFixedPoint;
begin
  if Src.Empty then Exception.Create(RCStrSrcIsEmpty);
  if Empty then Exception.Create(RCStrBaseIsEmpty);
  GR32.IntersectRect(SrcRect, Src.BoundsRect, SrcRect);

  DstRect.Left := DstLeft;
  DstRect.Top := DstTop;
  DstRect.Right := DstLeft + (SrcRect.Right - SrcRect.Left);
  DstRect.Bottom := DstTop + (SrcRect.Bottom - SrcRect.Top);

  GR32.IntersectRect(DstRect, BoundsRect, DstRect);
  if GR32.IsRectEmpty(DstRect) then Exit;

  P := SrcRect.Top * Src.Width;
  Progression.Y := - FixedOne;
  case Src.FVectorCombineMode of
    vcmAdd:
      begin
        for I := DstRect.Top to DstRect.Bottom do
        begin
          // Added ^ for FPC
          DstPtr := @GetVectors^[I * Width];
          SrcPtr := @Src.GetVectors^[SrcRect.Left + P];
          for J := DstRect.Left to DstRect.Right do
          begin
            Inc(SrcPtr^.X, DstPtr[J].X);
            Inc(SrcPtr^.Y, DstPtr[J].Y);
            Inc(SrcPtr);
          end;
          Inc(P, Src.Width);
        end;
      end;
    vcmReplace:
      begin
        for I := DstRect.Top to DstRect.Bottom do
        begin
          // Added ^ for FPC
          DstPtr := @GetVectors^[I * Width];
          SrcPtr := @Src.GetVectors^[SrcRect.Left + P];
          for J := DstRect.Left to DstRect.Right do
          begin
            SrcPtr^.X := DstPtr[J].X;
            SrcPtr^.Y := DstPtr[J].Y;
            Inc(SrcPtr);
          end;
          Inc(P, Src.Width);
        end;
      end;
  else
    CombineCallback := Src.FOnVectorCombine;
    ProgressionX := Fixed(2 / (DstRect.Right - DstRect.Left - 1));
    ProgressionY := Fixed(2 / (DstRect.Bottom - DstRect.Top - 1));
    for I := DstRect.Top to DstRect.Bottom do
    begin
      Progression.X := - FixedOne;
      // Added ^ for FPC
      DstPtr := @GetVectors^[I * Width];
      SrcPtr := @Src.GetVectors^[SrcRect.Left + P];
      for J := DstRect.Left to DstRect.Right do
      begin
        CombineCallback(SrcPtr^, Progression, DstPtr[J]);
        Inc(SrcPtr);
        Inc(Progression.X, ProgressionX);
      end;
      Inc(P, Src.Width);
      Inc(Progression.Y, ProgressionY);
    end;
  end;
end;

procedure TVectorMap.SaveToFile(const FileName: string);

  procedure ConvertVerticesX;
  var
    I: Integer;
  begin
    for I := 0 to Length(FVectors) - 1 do
    begin
      //Not a mistake! Converting physical mem. directly to avoid temporary floating point buffer
      //Do no change to PFloat.. the type is relative to the msh format.
      FVectors[I].X := Fixed(PSingle(@FVectors[I].X)^);
      FVectors[I].Y := Fixed(PSingle(@FVectors[I].Y)^);
    end;
  end;

  procedure ConvertVerticesF;
  var
    I: Integer;
{$if (defined(CompilerVersion)) and (CompilerVersion = 31)}
    f: single;
{$ifend}
  begin
    for I := 0 to Length(FVectors) - 1 do
    begin
      //Not a mistake! Converting physical mem. directly to avoid temporary floating point buffer
      //Do no change to PFloat.. the type is relative to the msh format.

// Workaround for Delphi 10.1 Internal Error C6949 ...
{$if (defined(CompilerVersion)) and (CompilerVersion = 31)}
      f := FVectors[I].X * FixedToFloat;
      FVectors[I].X := PInteger(@f)^;
      f := FVectors[I].Y * FixedToFloat;
      FVectors[I].Y := PInteger(@f)^;
{$else}
      PSingle(@FVectors[I].X)^ := FVectors[I].X * FixedToFloat;
      PSingle(@FVectors[I].Y)^ := FVectors[I].Y * FixedToFloat;
{$ifend}
    end;
  end;

var
  Header: TPSLiquifyMeshHeader;
  MeshFile: File;
  Pad: Cardinal;
begin
  try
    AssignFile(MeshFile, FileName);
    Rewrite(MeshFile, 1);
    with Header do
    begin
      Pad0 := $02000000;
      Ident := MeshIdent;
      Pad1 := $00000002;
      Width := Self.Width;
      Height := Self.Height;
    end;
    BlockWrite(MeshFile, Header, SizeOf(TPSLiquifyMeshHeader));
    with Header do
    begin
      ConvertVerticesF;
      BlockWrite(MeshFile, FVectors[0], Length(FVectors) * SizeOf(TFixedVector));
      ConvertVerticesX;
    end;
    if Odd(Length(FVectors) * SizeOf(TFixedVector) - 1) then
    begin
      Pad := $00000000;
      BlockWrite(MeshFile, Pad, 4);
      BlockWrite(MeshFile, Pad, 4);
    end;
  finally
    CloseFile(MeshFile);
  end;
end;

procedure TVectorMap.SetFloatVector(X, Y: Integer; const Point: TFloatVector);
begin
  FVectors[X + Y * Width] := FixedPoint(Point);
end;

procedure TVectorMap.SetFloatVectorF(X, Y: Single; const Point: TFloatVector);
begin
  SetFixedVectorX(Fixed(X), Fixed(Y), FixedPoint(Point));
end;

procedure TVectorMap.SetFloatVectorFS(X, Y: Single; const Point: TFloatVector);
begin
  SetFixedVectorXS(Fixed(X), Fixed(Y), FixedPoint(Point));
end;

procedure TVectorMap.SetFloatVectorS(X, Y: Integer; const Point: TFloatVector);
begin
  if (X >= 0) and (X < Width) and
     (Y >= 0) and (Y < Height) then
       FVectors[X + Y * Width] := FixedPoint(Point);
end;

procedure TVectorMap.SetFixedVector(X, Y: Integer; const Point: TFixedVector);
begin
  FVectors[X + Y * Width] := Point;
end;

procedure TVectorMap.SetFixedVectorS(X, Y: Integer; const Point: TFixedVector);
begin
  if (X >= 0) and (X < Width) and
     (Y >= 0) and (Y < Height) then
       FVectors[X + Y * Width] := Point;
end;

procedure TVectorMap.SetFixedVectorX(X, Y: TFixed; const Point: TFixedVector);
var
  flrx, flry, celx, cely: Integer;
  P: PFixedPoint;
begin
  flrx := TFixedRec(X).Frac;
  celx := flrx xor $FFFF;
  flry := TFixedRec(Y).Frac;
  cely := flry xor $FFFF;

  P := @FVectors[TFixedRec(X).Int + TFixedRec(Y).Int * Width];

  CombineVectorsMem(Point, P^, FixedMul(celx, cely)); Inc(P);
  CombineVectorsMem(Point, P^, FixedMul(flrx, cely)); Inc(P, Width);
  CombineVectorsMem(Point, P^, FixedMul(flrx, flry)); Dec(P);
  CombineVectorsMem(Point, P^, FixedMul(celx, flry));
end;

procedure TVectorMap.SetFixedVectorXS(X, Y: TFixed; const Point: TFixedVector);
var
  flrx, flry, celx, cely: Integer;
  P: PFixedPoint;
begin
  if (X < -$10000) or (Y < -$10000) then Exit;

  flrx := TFixedRec(X).Frac;
  X := TFixedRec(X).Int;
  flry := TFixedRec(Y).Frac;
  Y := TFixedRec(Y).Int;

  if (X >= Width) or (Y >= Height) then Exit;

  celx := flrx xor $FFFF;
  cely := flry xor $FFFF;
  P := @FVectors[X + Y * Width];

  if (X >= 0) and (Y >= 0)then
  begin
    CombineVectorsMem(Point, P^, FixedMul(celx, cely) ); Inc(P);
    CombineVectorsMem(Point, P^, FixedMul(flrx, cely) ); Inc(P, Width);
    CombineVectorsMem(Point, P^, FixedMul(flrx, flry) ); Dec(P);
    CombineVectorsMem(Point, P^, FixedMul(celx, flry) );
  end
  else
  begin
    if (X >= 0) and (Y >= 0) then CombineVectorsMem(Point, P^, FixedMul(celx, cely)); Inc(P);
    if (X < Width - 1) and (Y >= 0) then CombineVectorsMem(Point, P^, FixedMul(flrx, cely)); Inc(P, Width);
    if (X < Width - 1) and (Y < Height - 1) then CombineVectorsMem(Point, P^, FixedMul(flrx, flry)); Dec(P);
    if (X >= 0) and (Y < Height - 1) then CombineVectorsMem(Point, P^, FixedMul(celx, flry));
  end;
end;

procedure TVectorMap.SetVectorCombineMode(const Value: TVectorCombineMode);
begin
  if FVectorCombineMode <> Value then
  begin
    FVectorCombineMode := Value;
    Changed;
  end;
end;

function TVectorMap.GetTrimmedBounds: TRect;
var
  J: Integer;
  VectorPtr : PFixedVector;
label
  TopDone, BottomDone, LeftDone, RightDone;

begin
  with Result do
  begin
    //Find Top
    Top := 0;
    VectorPtr := @Vectors[Top];
    repeat
      if Int64(VectorPtr^) <> 0 then goto TopDone;
      Inc(VectorPtr);
      Inc(Top);
    until Top = Self.Width * Self.Height;

    TopDone: Top := Top div Self.Width;

    //Find Bottom
    Bottom := Self.Width * Self.Height - 1;
    VectorPtr := @Vectors[Bottom];
    repeat
      if Int64(VectorPtr^) <> 0 then goto BottomDone;
      Dec(VectorPtr);
      Dec(Bottom);
    until Bottom < 0;

    BottomDone: Bottom := Bottom div Self.Width - 1;

    //Find Left
    Left := 0;
    repeat
      J := Top;
      repeat
        if Int64(FixedVector[Left, J]) <> 0 then goto LeftDone;
        Inc(J);
      until J >= Bottom;
      Inc(Left)
    until Left >= Self.Width;

    LeftDone:

    //Find Right
    Right := Self.Width - 1;
    repeat
      J := Bottom;
      repeat
        if Int64(FixedVector[Right, J]) <> 0 then goto RightDone;
        Dec(J);
      until J <= Top;
      Dec(Right)
    until Right <= Left;

  end;
  RightDone:
  if GR32.IsRectEmpty(Result) then
    Result := MakeRect(0, 0, 0, 0);
end;

end.
