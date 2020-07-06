unit uJsonReaders;

///
///  json 顺序解析读取
///

interface

uses
  Classes, Windows, SysUtils;

type
  TJSONReaderKind = (
    jrkNone, jrkNull, jrkFalse, jrkTrue, jrkString,
    jrkNumber, // 不确定 int 还是 float 类型
    jrkObject, jrkArray);

  TJSONReader = record
    JSON: string;
    CurIdx: integer;
    LastIdx: integer;
    TokenIdx: Integer;
    TokenLen : integer;
    ExistsEscapeChar: Boolean;
    procedure Init(const aJSON: string; aIndex, aLen: integer);
    function GetNextChar: char;                           inline;
    function GetNextNonWhiteChar: char;                   inline;
    function CheckNextNonWhiteChar(aChar: char): boolean; inline;
    function JSONStrToStr: string;
    function GetToken: string;                            inline;
    function GetToStrToken: string;                       inline;

    function GetNextString: boolean;
    function GetNextToken: string;
    function ReadJSONObject: boolean;
    function ReadJSONArray: boolean;
    procedure AppendNextStringUnEscape; //(var str: string);

    function GetDataType: TJSONReaderKind;
    function GetNext: TJSONReaderKind;

    function AsStr: string;    inline;
    function AsInt: Integer;   inline;
    function AsInt64: Int64;   inline;
    function AsUInt64: UInt64; inline;
    function AsFloat: Extended; inline;
  end;

implementation

uses
  Math;

//procedure AppendChar(var str: string; chr: Char);
//var len: Integer;
//begin
//  len := length(str);
//  SetLength(str,len+1);
//  PChar(pointer(str))[len] := chr;
//end;

procedure TJSONReader.Init(const aJSON: string; aIndex, aLen: integer);
begin
  JSON := aJSON;
  if aLen > 0 then
    LastIdx := aLen + aIndex
  else
    LastIdx := length(JSON);
  CurIdx := aIndex;
end;

function TJSONReader.GetNextChar: char;
begin
  if CurIdx <= LastIdx then
  begin
    result := JSON[CurIdx];
    inc(CurIdx);
  end
  else
    result := #0;
end;

function TJSONReader.GetNextNonWhiteChar: char;
begin
  if CurIdx<=LastIdx then
    repeat
      if JSON[CurIdx]>' ' then
      begin
        result := JSON[CurIdx];
        inc(CurIdx);
        exit;
      end;
      inc(CurIdx);
    until CurIdx>LastIdx;
  result := #0;
end;

function TJSONReader.CheckNextNonWhiteChar(aChar: char): boolean;
begin
  if CurIdx<=LastIdx then
    repeat
      if JSON[CurIdx]>' ' then
      begin
        result := JSON[CurIdx] = aChar;
        if result then
          inc(CurIdx);
        exit;
      end;
      inc(CurIdx);
    until CurIdx>LastIdx;
  result := false;
end;

procedure TJSONReader.AppendNextStringUnEscape; //(var str: string);
var c: char;
    u: string;
    unicode,err: integer;
begin
  repeat
    c := GetNextChar;
    case c of
      #0: exit;
      '"': break;
      '\': begin
          c := GetNextChar;
          case c of
            #0: exit;
            'u': inc(CurIdx, 4);
          end;
        end;
    end;
    TokenLen := CurIdx - TokenIdx;
  until false;
end;

function TJSONReader.GetToken: string;
begin
  Result := copy(JSON,TokenIdx,tokenLen);
end;

function TJSONReader.GetToStrToken: string;
begin
  if not ExistsEscapeChar then
    Result := GetToken
  else
    Result := JSONStrToStr;
end;


function TJSONReader.GetNextString: boolean;
var i: integer;
begin
  result := false;
  for i := CurIdx to LastIdx do
    case JSON[i] of
    '"': begin // end of string without escape -> direct copy
          TokenIdx := CurIdx; TokenLen := i- CurIdx;
          CurIdx := i+1;
          result := true;
          break;
        end;
    '\': begin // need unescaping
          ExistsEscapeChar := True;
          TokenIdx := CurIdx; TokenLen := i- CurIdx;
          CurIdx := i;
          AppendNextStringUnEscape; //(str);
          result := true;
          break;
        end;
    end;
end;

function TJSONReader.GetNextToken: string;
begin
  if GetNextString then
    Result := GetToken
  else result := '';
end;

function TJSONReader.GetDataType: TJSONReaderKind;
begin
  // 第一次读取
  //   确定数据类型： 1、对象类型
  //                  2、数组类型
  //
  case GetNextNonWhiteChar of
    '{': Result := jrkObject;
    '[': Result := jrkArray;
    else Result := jrkNone;
  end;
end;

function TJSONReader.GetNext: TJSONReaderKind;
begin
  ExistsEscapeChar := False;
  result := jrkNone;
  case GetNextNonWhiteChar of
    'n': begin //if copy(JSON,CurIdx,3)='ull' then begin
           inc(CurIdx,3);
           result := jrkNull;
         end;
    'f': begin //if copy(JSON,CurIdx,4)='alse' then begin
           inc(CurIdx,4);
           result := jrkFalse;
         end;
    't': begin //if copy(JSON,CurIdx,3)='rue' then begin
           inc(CurIdx,3);
           result := jrkTrue;
         end;
    '"': if GetNextString then begin
           result := jrkString;
         end;
    '{': if ReadJSONObject then
           result := jrkObject;
    '[': if ReadJSONArray then
           result := jrkArray;
    '-','0'..'9': begin
        TokenIdx := CurIdx-1;
        while true do
          case JSON[CurIdx] of
          '-','+','0'..'9','.','E','e': inc(CurIdx);
          else break;
          end;
        TokenLen := CurIdx-TokenIdx;
        Result := jrkNumber;
      end;
  end;
end;

procedure HexTo(c: Char; var d: LongWord); inline;
begin
  case c of
    '0'..'9': d := (d shl 4) or LongWord(Ord(c) - Ord('0'));
    'A'..'F': d := (d shl 4) or LongWord(Ord(c) - (Ord('A') - 10));
    'a'..'f': d := (d shl 4) or LongWord(Ord(c) - (Ord('a') - 10));
    else raise Exception.Create('Error Message');
  end;
end;

function TJSONReader.JSONStrToStr: string;

const
  MaxBufPos = 127;
var
  Buf: array[0..MaxBufPos] of Char;
  F: PChar;
  BufPos, Len: Integer;
  d: LongWord;
  idx, iEndIdx: Integer;
  s: string;
begin
  if TokenLen <= 0 then
  begin
    Result := '';
    Exit;
  end;

  s := '';
  idx := TokenIdx;
  iEndIdx := idx + TokenLen;
  BufPos := 0;
  while idx < iEndIdx do
  begin
    if JSON[idx] <> '\' then
      Buf[BufPos] := JSON[idx]
    else //if JSON[idx] = '\' do
    begin
      inc(idx);
      if idx = iEndIdx then Break;
      case JSON[idx] of
        '"': Buf[BufPos] := '"';
        '\': Buf[BufPos] := '\';
        '/': Buf[BufPos] := '/';
        'b': Buf[BufPos] := #8;
        'f': Buf[BufPos] := #12;
        'n': Buf[BufPos] := #10;
        'r': Buf[BufPos] := #13;
        't': Buf[BufPos] := #9;
        'u': begin
            inc(idx);
            if idx + 3 >= iEndIdx then
              Break;

            d := 0;
            HexTo(JSON[idx], d);
            HexTo(JSON[idx+1], d);
            HexTo(JSON[idx+2], d);
            HexTo(JSON[idx+3], d);
            Buf[BufPos] := Char(d);
            Inc(idx, 3);
          end;
      else
        Break;
      end;
    end;
    Inc(idx);
    Inc(BufPos);

    if BufPos > MaxBufPos then
    begin
      Len := Length(s);
      SetLength(S, Len + BufPos);
      Move(Buf[0], PChar(Pointer(S))[Len], BufPos * SizeOf(Char));
      BufPos := 0;
    end;
  end;

  if BufPos > 0 then
  begin
    Len := Length(S);
    SetLength(S, Len + BufPos);
    Move(Buf[0], PChar(Pointer(S))[Len], BufPos * SizeOf(Char));
  end;

  Result := s;
end;

function TJSONReader.ReadJSONArray: boolean;
var
  level: Integer;
begin
  TokenIdx := CurIdx - 1;
  level := 0;
  result := false;
  if CurIdx <= LastIdx then
    repeat
      case JSON[CurIdx] of
        '[': inc(level);
        ']': begin
          if level = 0 then
          begin
            inc(CurIdx);
            TokenLen := CurIdx - TokenIdx;
            Result := True;
            Break;
          end;
          dec(level);
        end;
      end;
      inc(CurIdx);
    until CurIdx>LastIdx;
end;

function TJSONReader.ReadJSONObject: boolean;
var
  level: Integer;
begin
  TokenIdx := CurIdx - 1;
  level := 0;
  result := false;
  if CurIdx <= LastIdx then
    repeat
      case JSON[CurIdx] of
        '{': inc(level);
        '}': begin
          if level = 0 then
          begin
            inc(CurIdx);
            TokenLen := CurIdx - TokenIdx;
            Result := True;
            Break;
          end;
          dec(level);
        end;
      end;
      inc(CurIdx);
    until CurIdx>LastIdx;
end;

function TJSONReader.AsStr: string;
begin
  Result := GetToStrToken;
end;

function TJSONReader.AsInt: Integer;
begin
  Result := integer(AsInt64);
end;

function TJSONReader.AsInt64: Int64;
var
  err: Integer;
  i64: Int64;
  d: Extended;
  str: string;
begin
  Result := 0;
  str := GetToken;
  val(str,i64,err);
  if err=0 then
    Result := i64
  else
  begin
    val(str,d,err);
    if err = 0 then
      Result := Round(d);
  end;
end;

function TJSONReader.AsUInt64: UInt64;
begin
  Result := UInt64(AsInt64);
end;

function TJSONReader.AsFloat: Extended;
var
  err: Integer;
  i64: UInt64;
  d: Extended;
  str: string;
begin
  Result := 0;
  str := GetToken;
  val(str, d, err);
  if err = 0 then
    Result := d
  else begin
    val(str, i64, err);
    if err = 0 then
      Result := i64;
  end;
end;


end.
