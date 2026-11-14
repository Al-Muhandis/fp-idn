unit fpidn;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fppunycode;

{ Domain-level IDN wrapper over the punycode converter.

  Error contract (Stage 3): the Try* functions are the primary API. They
  return True on success with the output parameter filled, and False on
  invalid input with the output parameter guaranteed to be EmptyStr. An
  empty domain is a success with an empty result, not an error.

  The plain functions (UnicodeToIDN, IDNToUnicode) are compatibility
  wrappers around the Try* pair: on any failure they return EmptyStr.

  UnicodeToIDN / TryUnicodeToIDN take a UTF-8 domain and encode every
  non-ASCII label as an xn-- label; empty labels pass through unchanged.
  Before encoding, a pragmatic IDNA mapping is applied (Stage 5): the
  Unicode label separators U+FF0E, U+3002 and U+FF61 are mapped to the
  ASCII full stop, and a per-label casefold MVP maps ASCII A-Z, Cyrillic
  U+0400..U+042F (U+0400..U+040F by +$50, so U+0401 folds to U+0451) and
  basic Greek U+0391..U+03A9 (except the unassigned U+03A2, by +$20) to
  lowercase. Full Unicode case folding and NFC normalization are out of
  scope by design (they need Unicode tables): other characters pass
  through unchanged and the input is expected to be already normalized -
  see the README "Limitations" section.

  Failure reasons of TryUnicodeToIDN (UseSTD3ASCIIRules-lite): malformed
  UTF-8, RFC 3492 section 6.4 arithmetic overflow, a label containing a
  byte < $21 (control characters and space) or any of <>"/\?#@:| (named
  constant in the implementation), a label above the DNS limit of 63
  bytes (ASCII labels included, not only 'xn--' ones) or a result above
  the 253-byte domain limit.

  IDNToUnicode / TryIDNToUnicode decode every xn-- label back to UTF-8
  (Stage 4). The prefix is recognized case-insensitively (DNS is
  case-insensitive) and the label is lowercased before decoding, so
  mixed-case A-labels such as 'Xn--Mnchen-3ya' decode to lowercase Unicode
  ('münchen'). An xn-- label that fails punycode decoding is kept verbatim
  (in its original case) instead of failing the whole domain or being
  silently dropped, so the result never loses a label. As a consequence
  the decode direction currently always succeeds: the Try* signature is
  kept for contract symmetry with TryUnicodeToIDN. }

function TryUnicodeToIDN(const aDomain: string; out IDN: string): Boolean;
function TryIDNToUnicode(const aDomain: string; out Unicode: string): Boolean;
function UnicodeToIDN(const aDomain: string): string;
function IDNToUnicode(const aDomain: string): string;

implementation

const
  // UseSTD3ASCIIRules-lite (Stage 5): ASCII characters that must not occur
  // in any label, together with bytes < $21 (control characters and space).
  // A named constant so the list is easy to extend.
  cForbiddenASCII = ['<', '>', '"', '/', '\', '?', '#', '@', ':', '|'];

  // DNS limits (RFC 1035): a label is at most 63 octets, a full domain
  // name at most 253 characters in the textual form (Stage 5)
  cMaxLabelLen = 63;
  cMaxDomainLen = 253;

  // Unicode label separators mapped to '.' before splitting (Stage 5),
  // as UTF-8 byte sequences
  cSepFF0E = #$EF#$BC#$8E; // U+FF0E FULLWIDTH FULL STOP
  cSep3002 = #$E3#$80#$82; // U+3002 IDEOGRAPHIC FULL STOP
  cSepFF61 = #$EF#$BD#$81; // U+FF61 HALFWIDTH IDEOGRAPHIC FULL STOP

function IsASCII(const S: string): Boolean;
var
  ch: Char;
begin
  for ch in S do
    if Ord(ch) >= 128 then
      Exit(False);
  Result := True;
end;

// Lowercase ASCII letters only. Punycode digits are case-insensitive and
// the basic part of a label must be ASCII, so this locale-independent
// lowering is exactly what the IDN decode needs (IDNA nameprep lowercases
// the label before ToUnicode as well). Non-ASCII bytes are left untouched:
// they make an xn-- label undecodable anyway, and the original label is
// kept on failure.
function LowercaseASCII(const S: string): string;
var
  i: Integer;
begin
  Result := S;
  for i := 1 to Length(Result) do
    if Result[i] in ['A'..'Z'] then
      Result[i] := Chr(Ord(Result[i]) + 32);
end;

// Maps the Unicode label separators to the ASCII full stop before the
// domain is split into labels (Stage 5): without this, 'пример．рф' would
// be encoded as a single DNS-invalid label containing a dot. The decode
// direction deliberately does not map anything: these separators cannot
// occur inside an xn-- label produced by the encoder, and foreign labels
// are kept verbatim.
function MapLabelSeparators(const aDomain: string): string;
begin
  Result := StringReplace(aDomain, cSepFF0E, '.', [rfReplaceAll]);
  Result := StringReplace(Result, cSep3002, '.', [rfReplaceAll]);
  Result := StringReplace(Result, cSepFF61, '.', [rfReplaceAll]);
end;

// Folds one code point per the Stage 5 MVP; returns aCodePoint unchanged
// when it is outside the folded ranges (the full Unicode case-fold tables
// are out of scope). The ASCII range is not handled here: it takes the
// cheap byte-level path in CasefoldMVP below.
function FoldCodePoint(aCodePoint: Cardinal): Cardinal; inline;
begin
  if (aCodePoint >= $0400) and (aCodePoint <= $040F) then
    // Cyrillic uppercase with the historic letters; U+0401 (Yo) folds
    // to U+0451 (lowercase yo)
    Result := aCodePoint + $50
  else if (aCodePoint >= $0410) and (aCodePoint <= $042F) then
    // Basic Cyrillic uppercase
    Result := aCodePoint + $20
  else if (aCodePoint >= $0391) and (aCodePoint <= $03A9) and
          (aCodePoint <> $03A2) then
    // Basic Greek uppercase; U+03A2 is unassigned and must not map to
    // the final sigma
    Result := aCodePoint + $20
  else
    Result := aCodePoint;
end;

// Pragmatic casefold MVP (Stage 5): ASCII A-Z, Cyrillic U+0400..U+042F
// and basic Greek U+0391..U+03A9 (see FoldCodePoint). Everything else
// passes through unchanged; the input is expected to be already
// normalized (no NFC). The transformation is length-preserving - every
// folded form has the same UTF-8 length (1 byte -> 1 byte, 2 bytes ->
// 2 bytes) - so the bytes can be rewritten in place. Bytes of invalid
// UTF-8 are left untouched here: the strict punycode validation rejects
// such labels afterwards.
function CasefoldMVP(const aLabel: string): string;
var
  i: Integer;
  aCodePoint: Cardinal;
begin
  Result := aLabel;
  i := 1;
  while i <= Length(Result) do
  begin
    case Ord(Result[i]) of
      $41..$5A: // ASCII A-Z: 1 byte in, 1 byte out
        begin
          Result[i] := Chr(Ord(Result[i]) + $20);
          Inc(i);
        end;
      $D0: // lead byte of U+0400..U+043F (2-byte UTF-8)
        if (i < Length(Result)) and ((Ord(Result[i + 1]) and $C0) = $80) then
        begin
          aCodePoint := FoldCodePoint($0400 + (Ord(Result[i + 1]) and $3F));
          Result[i] := Chr($C0 or (aCodePoint shr 6));
          Result[i + 1] := Chr($80 or (aCodePoint and $3F));
          Inc(i, 2);
        end
        else
          Inc(i);
      $CE: // lead byte of U+0380..U+03BF (2-byte UTF-8)
        if (i < Length(Result)) and ((Ord(Result[i + 1]) and $C0) = $80) then
        begin
          aCodePoint := FoldCodePoint($0380 + (Ord(Result[i + 1]) and $3F));
          Result[i] := Chr($C0 or (aCodePoint shr 6));
          Result[i + 1] := Chr($80 or (aCodePoint and $3F));
          Inc(i, 2);
        end
        else
          Inc(i);
    else
      Inc(i);
    end;
  end;
end;

// UseSTD3ASCIIRules-lite (Stage 5): no byte < $21 (control characters and
// space) and no character of cForbiddenASCII may occur in a label. ASCII
// bytes inside a non-ASCII label are checked too, so 'т est' fails as well.
function HasForbiddenASCII(const aLabel: string): Boolean;
var
  i: Integer;
begin
  for i := 1 to Length(aLabel) do
    if (Ord(aLabel[i]) < $21) or (aLabel[i] in cForbiddenASCII) then
      Exit(True);
  Result := False;
end;

// Core IDN encoder with the Try* error contract (Stage 3): internal checks
// report success/failure via Boolean instead of relying on the "empty
// string = error" convention of the punycode layer. IDN is guaranteed to
// be EmptyStr when False is returned; the plain UnicodeToIDN below is a
// thin wrapper projecting False to EmptyStr.
function TryUnicodeToIDN(const aDomain: string; out IDN: string): Boolean;
var
  aParts: TStringArray;
  aEncodedParts: TStringArray = ();
  aLabel, aJoined: string;
  aPuny: string;
  i: Integer;
begin
  IDN := EmptyStr;
  // IDNA label separators first, then the ASCII full stop splits the
  // domain into labels (Stage 5)
  aParts := MapLabelSeparators(aDomain).Split(['.']);
  SetLength(aEncodedParts, Length(aParts));
  for i := 0 to High(aParts) do
  begin
    if aParts[i] = EmptyStr then
      aEncodedParts[i] := EmptyStr
    else
    begin
      aLabel := CasefoldMVP(aParts[i]);

      // UseSTD3ASCIIRules-lite: a forbidden byte fails the whole domain
      if HasForbiddenASCII(aLabel) then
        Exit(False);

      if IsASCII(aLabel) then
      begin
        // DNS limit: an ASCII label is its own wire form
        if Length(aLabel) > cMaxLabelLen then
          Exit(False);
        aEncodedParts[i] := aLabel;
      end
      else
      begin
        // A non-ASCII label that cannot be encoded (malformed UTF-8 or
        // overflow) fails the whole domain instead of producing a broken
        // 'xn--' label
        if not TryUTF8ToPunycode(aLabel, aPuny) then
          Exit(False);
        aEncodedParts[i] := 'xn--' + aPuny;
        // DNS limit: the encoded label must fit into 63 bytes
        if Length(aEncodedParts[i]) > cMaxLabelLen then
          Exit(False);
      end;
    end;
  end;

  aJoined := string.Join('.', aEncodedParts);
  // DNS limit for the whole domain (textual form without the root dot)
  if Length(aJoined) > cMaxDomainLen then
    Exit(False);
  IDN := aJoined;
  Result := True;
end;

// Core IDN decoder with the Try* error contract (Stage 4): the xn-- prefix
// is recognized in any case, the label is lowercased before decoding, and
// a label that cannot be decoded is kept verbatim (original case) instead
// of failing the whole domain or being silently dropped — the result never
// loses a label, so a decode round-trip cannot collapse the domain. The
// decode direction therefore currently always succeeds; the Boolean
// contract is kept for symmetry with TryUnicodeToIDN.
function TryIDNToUnicode(const aDomain: string; out Unicode: string): Boolean;
var
  aParts: TStringArray;
  aDecodedParts: TStringArray = ();
  i: Integer;
  aPuny: string;
begin
  Unicode := EmptyStr;
  aParts := aDomain.Split(['.']);
  SetLength(aDecodedParts, Length(aParts));
  for i := 0 to High(aParts) do
  begin
    // DNS is case-insensitive, so the prefix must match in any case
    if aParts[i].StartsWith('xn--', True) then
    begin
      // Decode the lowercased copy: mixed-case A-labels ('Xn--Mnchen-3ya')
      // produce lowercase Unicode ('münchen'), as IDNA ToUnicode does
      if TryPunycodeToUTF8(LowercaseASCII(aParts[i]).Remove(0, 4), aPuny) then
        aDecodedParts[i] := aPuny
      else
        // Undecodable label: keep the original verbatim instead of
        // dropping it (Stage 3 failure of the whole domain was replaced
        // by label preservation in Stage 4)
        aDecodedParts[i] := aParts[i];
    end
    else
      aDecodedParts[i] := aParts[i];
  end;

  Unicode := Unicode.Join('.', aDecodedParts);
  Result := True;
end;

function UnicodeToIDN(const aDomain: string): string;
begin
  if not TryUnicodeToIDN(aDomain, Result) then
    Result := EmptyStr;
end;

function IDNToUnicode(const aDomain: string): string;
begin
  if not TryIDNToUnicode(aDomain, Result) then
    Result := EmptyStr;
end;

end.
