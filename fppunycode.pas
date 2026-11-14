unit fppunycode;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes
  ;

{ Punycode converter per RFC 3492.

  Error contract (Stage 3): the Try* functions are the primary API. They
  return True on success with the output parameter filled, and False on
  invalid input with the output parameter guaranteed to be EmptyStr. An
  empty input string is a success with an empty result, not an error.

  The plain functions (UTF8ToPunycode, PunycodeToUTF8) are compatibility
  wrappers around the Try* pair: on any failure they return EmptyStr, so
  an empty result means "either an empty input or an error" - use the
  Try* variants to tell these cases apart.

  The input of UTF8ToPunycode / TryUTF8ToPunycode must be well-formed
  UTF-8 (RFC 3629). Encode failure reasons: malformed UTF-8 (invalid lead
  byte, truncated sequence, missing continuation byte, overlong encoding,
  UTF-16 surrogate, code point above U+10FFFF) and RFC 3492 section 6.4
  arithmetic overflow. Decode failure reasons: a non-ASCII byte in the
  basic part, a character outside the punycode alphabet, a digit group
  truncated by the end of input, arithmetic overflow, a decoded code point
  above U+10FFFF. }

function TryUTF8ToPunycode(const UTF8Str: string; out Puny: string): Boolean;
function TryPunycodeToUTF8(const aPunycodeStr: string; out UTF8Str: string): Boolean;
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

// Bias adaptation for the next iteration. aDelta is QWord: RFC 3492
// section 6.4 requires overflow-controlled arithmetic on deltas, so both
// encode and decode pass deltas that no longer fit into 32 bits.
function Adapt(aDelta: QWord; aNumPoints: Cardinal; aFirstTime: Boolean): QWord; inline;
var
  k: QWord;
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
function EncodeDigit(aDigit: QWord): Char; inline;
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

// Strict UTF-8 decoder: converts a UTF-8 string into an array of Unicode
// code points and accepts only well-formed UTF-8 (RFC 3629). A stray
// continuation byte, an invalid lead byte, a truncated sequence, a missing
// continuation inside a sequence, an overlong encoding, a UTF-16 surrogate
// or a code point above U+10FFFF fails the whole input: the caller gets
// False and an empty array, never a partially parsed or "repaired" result.
function TryUTF8ToUnicodeArray(const aUTF8Str: string; out aArray: TUnicodeArray): Boolean;
var
  i, aPos, aLen: Integer;
  aCodePoint: Cardinal;
  aByteCount, aSeqLen: Integer;
  aParsed: TUnicodeArray;
begin
  aLen := Length(aUTF8Str);
  SetLength(aParsed, aLen);
  aPos := 0;
  i := 1;

  while i <= aLen do
  begin
    // Determine the number of bytes in the UTF-8 character. Lead bytes
    // $C0/$C1 (always overlong) and $F5..$F7 (always above U+10FFFF) are
    // rejected by the lead ranges themselves.
    case Ord(aUTF8Str[i]) of
      $00..$7F: // 1-byte sequence (ASCII)
        begin
          aCodePoint := Ord(aUTF8Str[i]);
          aSeqLen := 1;
        end;
      $C2..$DF: // 2-byte sequence
        begin
          aCodePoint := Ord(aUTF8Str[i]) and $1F;
          aSeqLen := 2;
        end;
      $E0..$EF: // 3-byte sequence
        begin
          aCodePoint := Ord(aUTF8Str[i]) and $0F;
          aSeqLen := 3;
        end;
      $F0..$F4: // 4-byte sequence
        begin
          aCodePoint := Ord(aUTF8Str[i]) and $07;
          aSeqLen := 4;
        end;
      else // $80..$BF, $C0/$C1, $F5..$FF: invalid lead byte
        Exit(False);
    end;

    if (i + aSeqLen - 1) > aLen then
      Exit(False); // truncated sequence at the end of input

    Inc(i);
    aByteCount := aSeqLen;
    while aByteCount > 1 do
    begin
      if (Ord(aUTF8Str[i]) and $C0) <> $80 then
        Exit(False); // non-continuation byte inside the sequence

      aCodePoint := (aCodePoint shl 6) or (Ord(aUTF8Str[i]) and $3F);
      Inc(i);
      Dec(aByteCount);
    end;

    // Reject overlong encodings: the code point must not fit a shorter form
    if (aSeqLen = 3) and (aCodePoint < $800) then
      Exit(False);
    if (aSeqLen = 4) and ((aCodePoint < $10000) or (aCodePoint > $10FFFF)) then
      Exit(False);
    // Reject UTF-16 surrogate code points
    if (aCodePoint >= $D800) and (aCodePoint <= $DFFF) then
      Exit(False);

    // Append code point to array
    aParsed[aPos] := aCodePoint;
    Inc(aPos);
  end;

  SetLength(aParsed, aPos);
  aArray := aParsed;
  Result := True;
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

// Convert an array of Unicode code points into a UTF-8 string. Returns
// False on an invalid code point (above U+10FFFF): the strict decoder never
// produces such points, so this is a defensive check that must fail loudly
// (False + empty string), not silently drop a character.
function TryUnicodeArrayToUTF8(const UnicodeArray: TUnicodeArray; out aUTF8Str: String): Boolean;
var
  MaxLen, ActualLen, i, aBytes: Integer;
  pDest: PByte;
begin
  aUTF8Str := EmptyStr;
  // Maximum possible length: each character is up to 4 bytes
  MaxLen := Length(UnicodeArray) * 4;
  SetLength(aUTF8Str, MaxLen);
  if MaxLen = 0 then
    Exit(True); // empty input is a valid empty output

  pDest := @aUTF8Str[1];
  ActualLen := 0;

  for i := 0 to High(UnicodeArray) do
  begin
    aBytes := UnicodeToUTF8Char(UnicodeArray[i], pDest + ActualLen);
    if aBytes = 0 then
    begin
      aUTF8Str := EmptyStr;
      Exit(False); // UnicodeToUTF8Char rejected the code point
    end;
    Inc(ActualLen, aBytes);
  end;

  SetLength(aUTF8Str, ActualLen);
  Result := True;
end;

// Core encoder with the Try* error contract (Stage 3): internal checks
// report success/failure via Boolean instead of the "empty string = error"
// convention. Puny is guaranteed to be EmptyStr when False is returned;
// the plain UTF8ToPunycode below is a thin wrapper projecting False to
// EmptyStr.
function TryUTF8ToPunycode(const UTF8Str: string; out Puny: string): Boolean;
var
  aInput: TUnicodeArray;
  aOutput: string;
  aInputLen, aBasicLen, aHandledLen: Integer;
  aOutLen, aOutCap: Integer;
  // QWord arithmetic per RFC 3492 section 6.4: deltas and their
  // intermediate products overflow 32-bit Cardinal on large inputs
  aBias, aDelta, N, M, Q, K, T: QWord;
  i: Integer;

  // Append one character to the preallocated output buffer, keeping the
  // write index in sync. The initial capacity is an upper estimate (see
  // below); doubling on overflow is a safety net for inputs whose digit
  // output outgrows the estimate, so the amortized append cost stays O(1)
  procedure Emit(C: Char);
  begin
    if aOutLen >= aOutCap then
    begin
      aOutCap := aOutCap * 2;
      SetLength(aOutput, aOutCap);
    end;
    Inc(aOutLen);
    aOutput[aOutLen] := C;
  end;

begin
  Puny := EmptyStr;

  // Strict UTF-8 validation (Stage 2): malformed input must never reach
  // the encoder and turn into garbage output
  if not TryUTF8ToUnicodeArray(UTF8Str, aInput) then
    Exit(False);
  aInputLen := Length(aInput);

  // Empty input is a success with an empty result, not an error (Stage 3)
  if aInputLen = 0 then
    Exit(True);

  aBasicLen := 0;

  // Count the basic characters first: the buffer is allocated once from an
  // upper estimate instead of growing by string concatenation, which copies
  // the whole output on every append (O(n) reallocations overall)
  for i := 0 to aInputLen - 1 do
  begin
    if aInput[i] < $80 then
      Inc(aBasicLen);
  end;

  // Upper estimate: every basic character once, one delimiter, 6 digits per
  // non-basic character (the typical output is 1-2 digits per character;
  // Emit doubles the buffer if the estimate is ever exceeded)
  aOutCap := aBasicLen + 1 + 6 * (aInputLen - aBasicLen);
  SetLength(aOutput, aOutCap);
  aOutLen := 0;

  // Copy all basic ASCII characters
  for i := 0 to aInputLen - 1 do
  begin
    if aInput[i] < $80 then
      Emit(Chr(aInput[i]));
  end;

  aHandledLen := aBasicLen;

  // Append delimiter if there are basic characters
  if (aBasicLen > 0) and (aBasicLen < aInputLen) then
    Emit(_DELIMITER)
  else if (aBasicLen = aInputLen) then
  begin
    SetLength(aOutput, aOutLen);
    Puny := aOutput;
    Exit(True);
  end;

  N := _INITIAL_N;
  aDelta := 0;
  aBias := _INITIAL_BIAS;

  while aHandledLen < aInputLen do
  begin
    // Find the smallest code point >= N
    M := High(QWord);
    for i := 0 to aInputLen - 1 do
    begin
      if (aInput[i] >= N) and (aInput[i] < M) then
        M := aInput[i];
    end;

    if M = High(QWord) then
      Break;

    // RFC 3492 section 6.4: delta += (m - n) * (h + 1), fail on overflow.
    // Widening to QWord alone is not enough: every dangerous operation is
    // guarded explicitly, as in the RFC reference implementation.
    if (M - N) > (High(QWord) - aDelta) div QWord(aHandledLen + 1) then
      Exit(False);
    aDelta += (M - N) * QWord(aHandledLen + 1);
    N := M;

    // Process all characters equal to N
    for i := 0 to aInputLen - 1 do
    begin
      if aInput[i] < N then
      begin
        // RFC 3492 section 6.4: delta++, fail on overflow
        if aDelta = High(QWord) then
          Exit(False);
        Inc(aDelta);
      end
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

          Emit(EncodeDigit(T + ((Q - T) mod (_BASE - T))));
          Q := (Q - T) div (_BASE - T);
          Inc(K, _BASE);
        end;

        Emit(EncodeDigit(Q));
        aBias := Adapt(aDelta, aHandledLen + 1, aHandledLen = aBasicLen);
        aDelta := 0;
        Inc(aHandledLen);
      end;
    end;

    Inc(aDelta);
    Inc(N);
  end;

  SetLength(aOutput, aOutLen);
  Puny := aOutput;
  Result := True;
end;

// Compatibility wrapper around TryUTF8ToPunycode: on any failure returns
// EmptyStr, so an empty result means "either an empty input or an error" -
// use the Try* variant to tell these cases apart
function UTF8ToPunycode(const UTF8Str: string): string;
begin
  if not TryUTF8ToPunycode(UTF8Str, Result) then
    Result := EmptyStr;
end;

// Core decoder with the Try* error contract (Stage 3): internal checks
// report success/failure via Boolean instead of the "empty string = error"
// convention. UTF8Str is guaranteed to be EmptyStr when False is returned;
// the plain PunycodeToUTF8 below is a thin wrapper projecting False to
// EmptyStr.
function TryPunycodeToUTF8(const aPunycodeStr: string; out UTF8Str: string): Boolean;
var
  aOutput: TUnicodeArray = ();
  aInputLen, aOutputLen, aBasicLen: Integer;
  // QWord arithmetic per RFC 3492 section 6.4: i, w and n overflow
  // 32-bit Cardinal on hostile input
  aBias, N, I, K, aDigit, T, W: QWord;
  aPos, aDelimPos: Integer;
  aOldI, D: QWord;
  aGroupDone: Boolean;
begin
  UTF8Str := EmptyStr;
  aInputLen := Length(aPunycodeStr);

  // Find the last delimiter
  aDelimPos:=RPos(_DELIMITER, aPunycodeStr);

  if aDelimPos > 0 then
    aBasicLen := aDelimPos - 1
  else
    aBasicLen := 0;

  SetLength(aOutput, aBasicLen);
  aOutputLen := aBasicLen;

  // Copy basic characters; per RFC 3492 every basic code point is ASCII,
  // so a byte >= $80 makes the whole input invalid instead of being
  // silently re-encoded into random code points (Stage 2)
  for aPos := 1 to aBasicLen do
  begin
    if Ord(aPunycodeStr[aPos]) >= $80 then
      Exit(False);
    aOutput[aPos - 1] := Ord(aPunycodeStr[aPos]);
  end;

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
    aGroupDone := False;

    while aPos <= aInputLen do
    begin
      aDigit := DecodeDigit(aPunycodeStr[aPos]);
      Inc(aPos);

      if aDigit >= _BASE then
        Exit(False); // Invalid character

      // RFC 3492 section 6.4: i += digit * w, fail on overflow
      if aDigit > (High(QWord) - I) div W then
        Exit(False);
      I += aDigit * W;

      if K <= aBias then
        T := _TMIN
      else if K >= aBias + _TMAX then
        T := _TMAX
      else
        T := K - aBias;

      if aDigit < T then
      begin
        aGroupDone := True;
        Break;
      end;

      // RFC 3492 section 6.4: w *= (base - t), fail on overflow
      if W > High(QWord) div (_BASE - T) then
        Exit(False);
      W *= (_BASE - T);
      Inc(K, _BASE);
    end;

    // RFC 3492 decoder: input that ends inside a digit group (before a
    // digit < t arrives) is invalid, not "one more final digit" (Stage 2;
    // reference Python raises "incomplete punycode string")
    if not aGroupDone then
      Exit(False);

    // RFC 3492 section 6.4: i - oldi must not wrap around
    if I < aOldI then
      Exit(False);
    aBias := Adapt(I - aOldI, aOutputLen + 1, aOldI = 0);

    // DivMod is 32-bit; n = i div (out + 1), i = i mod (out + 1) manually
    D := I div QWord(aOutputLen + 1);
    I := I mod QWord(aOutputLen + 1);

    // RFC 3492 section 6.4: n += delta, fail on overflow. N is kept within
    // Cardinal range so the store into aOutput cannot truncate it.
    if D > High(Cardinal) - N then
      Exit(False);
    N += D;

    // A point above U+10FFFF is not valid Unicode: fail instead of letting
    // it through to the output (Stage 2 completes the Stage 1 guard;
    // reference Python raises "Invalid character U+...")
    if N > $10FFFF then
      Exit(False);

    if aOutputLen >= High(aOutput) then SetLength(aOutput, Round(aOutputLen*1.33)+1);

    // I <= aOutputLen is guaranteed by the mod above, so no clamping is
    // needed before the insertion
    if I < aOutputLen then
      Move(aOutput[I], aOutput[I + 1], (aOutputLen - I) * SizeOf(Cardinal));

    aOutput[I] := N;

    Inc(aOutputLen);
    Inc(I);
  end;

  SetLength(aOutput, aOutputLen);
  // TryUnicodeArrayToUTF8 leaves UTF8Str empty on failure, so the
  // output-empty guarantee holds on this path as well
  if not TryUnicodeArrayToUTF8(aOutput, UTF8Str) then
    Exit(False);
  Result := True;
end;

// Compatibility wrapper around TryPunycodeToUTF8: on any failure returns
// EmptyStr, so an empty result means "either an empty input or an error" -
// use the Try* variant to tell these cases apart
function PunycodeToUTF8(const aPunycodeStr: string): string;
begin
  if not TryPunycodeToUTF8(aPunycodeStr, Result) then
    Result := EmptyStr;
end;

end.
