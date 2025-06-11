unit fppunycode;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math
  ;

function UTF8ToPunycode(const UTF8Str: string): string;
function PunycodeToUTF8(const aPunycodeStr: string): string;

implementation

uses
  StrUtils
  ;

const
  _BASE = 36;
  _TMIN = 1;
  _TMAX = 26;
  _SKEW = 38;
  _DAMP = 700;
  _INITIAL_BIAS = 72;
  _INITIAL_N = $80;
  _DELIMITER = '-';

type
  TUnicodeArray = array of Cardinal;

// Bias adaptation for the next iteration
function Adapt(aDelta, aNumPoints: Cardinal; aFirstTime: Boolean): Cardinal; inline;
var
  k: Cardinal;
begin
  if aDelta=0 then Exit(0);
  if aFirstTime then
    aDelta := aDelta div _DAMP
  else
    aDelta := aDelta shr 1;
  aDelta += (aDelta div aNumPoints);
  k := 0;
  while aDelta > (((_BASE - _TMIN) * _TMAX) div 2) do
  begin
    aDelta := aDelta div (_BASE - _TMIN);
    Inc(k, _BASE);
  end;
  Result := k + (((_BASE - _TMIN + 1) * aDelta) div (aDelta + _SKEW));
end;

// Encode a digit into a character
function EncodeDigit(aDigit: Cardinal): Char; inline;
begin
  if aDigit < 26 then
    Result := Chr(Ord('a') + aDigit)
  else
    Result := Chr(Ord('0') + aDigit - 26);
end;

// Decode a character into a digit
function DecodeDigit(C: Char): Cardinal; inline;
begin
  case C of
    'a'..'z': Result := Ord(C) - Ord('a');
    'A'..'Z': Result := Ord(C) - Ord('A');
    '0'..'9': Result := Ord(C) - Ord('0') + 26;
    else      Result := _BASE; // Error
  end;
end;

// Convert a UTF-8 string into an array of Unicode code points
function UTF8ToUnicodeArray(const aUTF8Str: string): TUnicodeArray;
var
  i, aPos: Integer;
  aCodePoint: Cardinal;
  aByteCount: Integer;
begin
  Initialize(Result);
  SetLength(Result, Length(aUTF8Str));
  aPos := 0;
  i := 1;

  while i <= Length(aUTF8Str) do
  begin
    // Determine the number of bytes in the UTF-8 character
    case Ord(aUTF8Str[i]) of
      $00..$7F: // 1-byte sequence (ASCII)
        begin
          aCodePoint := Ord(aUTF8Str[i]);
          aByteCount := 1;
        end;
      $C0..$DF: // 2-byte sequence
        begin
          aCodePoint := Ord(aUTF8Str[i]) and $1F;
          aByteCount := 2;
        end;
      $E0..$EF: // 3-byte sequence
        begin
          aCodePoint := Ord(aUTF8Str[i]) and $0F;
          aByteCount := 3;
        end;
      $F0..$F7: // 4-byte sequence
        begin
          aCodePoint := Ord(aUTF8Str[i]) and $07;
          aByteCount := 4;
        end;
      else // Skip unknown byte
        begin
          Inc(i);
          Continue;
        end;
    end;

    if (i + aByteCount - 1) > Length(aUTF8Str) then
      Break;

    Inc(i);
    while (aByteCount > 1) and (i <= Length(aUTF8Str)) do
    begin
      if (Ord(aUTF8Str[i]) and $C0) <> $80 then
        Break;

      aCodePoint := (aCodePoint shl 6) or (Ord(aUTF8Str[i]) and $3F);
      Inc(i);
      Dec(aByteCount);
    end;

    // Append code point to array
    if aPos < Length(Result) then
    begin
      Result[aPos] := aCodePoint;
      Inc(aPos);
    end;
  end;

  SetLength(Result, aPos);
end;

function UnicodeToUTF8Char(U: Cardinal; Dest: PByte): Integer; inline;
begin
  if U <= $7F then
  begin
    Dest^ := U;
    Result := 1;
  end
  else if U <= $7FF then
  begin
    Dest^ := $C0 or (U shr 6);
    Inc(Dest);
    Dest^ := $80 or (U and $3F);
    Result := 2;
  end
  else if U <= $FFFF then
  begin
    Dest^ := $E0 or (U shr 12);
    Inc(Dest);
    Dest^ := $80 or ((U shr 6) and $3F);
    Inc(Dest);
    Dest^ := $80 or (U and $3F);
    Result := 3;
  end
  else if U <= $10FFFF then
  begin
    Dest^ := $F0 or (U shr 18);
    Inc(Dest);
    Dest^ := $80 or ((U shr 12) and $3F);
    Inc(Dest);
    Dest^ := $80 or ((U shr 6) and $3F);
    Inc(Dest);
    Dest^ := $80 or (U and $3F);
    Result := 4;
  end
  else
    Result := 0; // Invalid character
end;

// Convert an array of Unicode code points into a UTF-8 string
function UnicodeArrayToUTF8(const UnicodeArray: TUnicodeArray): String;
var
  MaxLen, ActualLen, i: Integer;
  pDest: PByte;
begin
  // Maximum possible length: each character is up to 4 bytes (UTF-8 can encode surrogates)
  MaxLen := Length(UnicodeArray) * 4;
  Initialize(Result);
  SetLength(Result, MaxLen);
  if MaxLen = 0 then Exit;

  pDest := @Result[1];
  ActualLen := 0;

  for i := 0 to High(UnicodeArray) do
    Inc(ActualLen, UnicodeToUTF8Char(UnicodeArray[i], pDest + ActualLen));

  SetLength(Result, ActualLen);
end;

// Main function for encoding into Punycode
function UTF8ToPunycode(const UTF8Str: string): string;
var
  aInput: TUnicodeArray;
  aOutput: string;
  aInputLen, aBasicLen, aHandledLen: Integer;
  aBias, aDelta, N, M, Q, K, T: Cardinal;
  i: Integer;
begin
  aInput := UTF8ToUnicodeArray(UTF8Str);
  aInputLen := Length(aInput);

  if aInputLen = 0 then
    Exit(EmptyStr);

  aOutput := EmptyStr;
  aBasicLen := 0;

  // Copy all basic ASCII characters
  for i := 0 to aInputLen - 1 do
  begin
    if aInput[i] < $80 then
    begin
      aOutput += Chr(aInput[i]);
      Inc(aBasicLen);
    end;
  end;

  aHandledLen := aBasicLen;

  // Append delimiter if there are basic characters
  if (aBasicLen > 0) and (aBasicLen < aInputLen) then
    aOutput += _DELIMITER
  else if (aBasicLen = aInputLen) then
    Exit(aOutput);

  N := _INITIAL_N;
  aDelta := 0;
  aBias := _INITIAL_BIAS;

  while aHandledLen < aInputLen do
  begin
    // Find the smallest code point >= N
    M := High(Cardinal);
    for i := 0 to aInputLen - 1 do
    begin
      if (aInput[i] >= N) and (aInput[i] < M) then
        M := aInput[i];
    end;

    if M = High(Cardinal) then
      Break;

    // Increment delta
    aDelta += (M - N) * (aHandledLen + 1);
    N := M;

    // Process all characters equal to N
    for i := 0 to aInputLen - 1 do
    begin
      if aInput[i] < N then
        Inc(aDelta)
      else if aInput[i] = N then
      begin
        Q := aDelta;
        K := _BASE;

        while True do
        begin
          if K <= aBias then
            T := _TMIN
          else if K >= aBias + _TMAX then
            T := _TMAX
          else
            T := K - aBias;

          if Q < T then
            Break;

          aOutput += EncodeDigit(T + ((Q - T) mod (_BASE - T)));
          Q := (Q - T) div (_BASE - T);
          Inc(K, _BASE);
        end;

        aOutput += EncodeDigit(Q);
        aBias := Adapt(aDelta, aHandledLen + 1, aHandledLen = aBasicLen);
        aDelta := 0;
        Inc(aHandledLen);
      end;
    end;

    Inc(aDelta);
    Inc(N);
  end;

  Result := aOutput;
end;

// Main function for decoding from Punycode
function PunycodeToUTF8(const aPunycodeStr: string): string;
var
  aOutput: TUnicodeArray = ();
  aInputLen, aOutputLen, aBasicLen: Integer;
  aBias, N, I, K, aDigit, T, W: Cardinal;
  aPos, aDelimPos: Integer;
  aOldI: Cardinal;
  D: Cardinal = 0;
begin
  aInputLen := Length(aPunycodeStr);

  // Find the last delimiter
  aDelimPos:=RPos(_DELIMITER, aPunycodeStr);

  if aDelimPos > 0 then
    aBasicLen := aDelimPos - 1
  else
    aBasicLen := 0;

  SetLength(aOutput, aBasicLen);
  aOutputLen := aBasicLen;

  // Copy basic characters
  for aPos := 1 to aBasicLen do
    aOutput[aPos - 1] := Ord(aPunycodeStr[aPos]);

  N := _INITIAL_N;
  I := 0;
  aBias := _INITIAL_BIAS;

  if aDelimPos > 0 then
    aPos := aDelimPos + 1
  else
    aPos := 1;

  while aPos <= aInputLen do
  begin
    aOldI := I;
    W := 1;
    K := _BASE;

    while aPos <= aInputLen do
    begin
      aDigit := DecodeDigit(aPunycodeStr[aPos]);
      Inc(aPos);

      if aDigit >= _BASE then
        Exit(EmptyStr); // Invalid character

      I += aDigit * W;

      if K <= aBias then
        T := _TMIN
      else if K >= aBias + _TMAX then
        T := _TMAX
      else
        T := K - aBias;

      if aDigit < T then
        Break;

      W *= (_BASE - T);
      Inc(K, _BASE);
    end;

    aBias := Adapt(I - aOldI, aOutputLen + 1, aOldI = 0);
    DivMod(I, aOutputLen + 1, D, I);
    N += D;

    if aOutputLen >= High(aOutput) then SetLength(aOutput, Round(aOutputLen*1.33)+1);

    // Prevent out-of-bounds access
    if I > aOutputLen then
      I := aOutputLen;

    if I < aOutputLen then
      Move(aOutput[I], aOutput[I + 1], (aOutputLen - I) * SizeOf(Cardinal));

    aOutput[I] := N;

    Inc(aOutputLen);
    Inc(I);
  end;

  SetLength(aOutput, aOutputLen);
  Result := UnicodeArrayToUTF8(aOutput);
end;

end.
