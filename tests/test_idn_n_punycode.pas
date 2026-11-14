unit test_idn_n_punycode;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  { TTestPunycode }
  TTestPunycode = class(TTestCase)
  private
    procedure AssertEncodeDecode(const aTestName, aInput, ExpectedPunycode: string);
    procedure AssertRoundTrip(const aTestName, aInput: string);
  published
    // Basic encoding/decoding tests
    procedure TestRussianDomain;
    procedure TestChineseCharacters;
    procedure TestArabicText;
    procedure TestGermanUmlaut;
    procedure TestJapaneseText;
    procedure TestMixedContent;
    // Edge cases
    procedure TestEmptyString;
    procedure TestSingleCharacter;
    procedure TestLongString;
    procedure TestOnlyNonASCII;
    // Special cases
    procedure TestSpecialCharacters;
    procedure TestNumbersAndSymbols;
    procedure TestCaseInsensitive;
    // Error handling tests
    procedure TestInvalidPunycode;
    procedure TestCorruptedData;
    procedure TestOutOfBoundsAndCorruptedData;
    // Strict input validation (Stage 2): invalid input never becomes garbage
    procedure TestStrictUTF8Encode;
    procedure TestStrictPunycodeDecode;
    // Try* error contract (Stage 3): True on success, False + EmptyStr on error
    procedure TestTryPunycodeContract;
    // Reference vectors verified against Python's punycode codec
    procedure TestReferenceVectors;
    // Stress vector for encoder overflow (enabled in Stage 1)
    procedure TestOverflowStress;
    // Performance tests
    procedure TestLargeData;
    // Real-world domain examples
    procedure TestRealWorldDomains;
    procedure TestDisallowedCharacters;
    procedure TestMalformedStructure;
    procedure TestDeterministicEncoding;

  end;

  { TTestIDN }

  TTestIDN = class(TTestCase)
  published
    procedure TestPureASCII;
    procedure TestRussianIDN;
    procedure TestMixedDomain;
    procedure TestSubdomains;
    procedure TestRealDomain;
    procedure TestEmptyInput;
    // Try* error contract (Stage 3): True on success, False + EmptyStr on error
    procedure TestTryIDNContract;
    // xn-- prefix handling (strict assertions enabled in Stage 4)
    procedure TestXnPrefixCaseInsensitive;
    procedure TestFailedLabelKept;
    // IDNA mapping and label validation (Stage 5)
    procedure TestIDNCasefoldMVP;
    procedure TestIDNAltSeparators;
    procedure TestIDNForbiddenASCII;
    procedure TestIDNLabelLengthLimit;
    procedure TestIDNDomainLengthLimit;
  end;

implementation

uses
  fppunycode, fpidn
  ;

// Repeats a UTF-8 sequence (one or more bytes encoding a single code point)
// aCount times. StringOfChar cannot do this for multi-byte code points:
// repeating the bytes separately would produce invalid UTF-8.
function RepeatUTF8(const aUTF8Sequence: string; aCount: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to aCount do
    Result += aUTF8Sequence;
end;

const
  // Conforming RFC 3492 decode of 'invalid' — a reference vector verified
  // with two independent implementations (Python codecs.encode/decode
  // 'punycode' and this library): UTF-8 bytes
  // E6 9B 8C E6 9B 93 E6 9B 90 E6 9B 92 E6 9B 8C
  // = U+66CC U+66D3 U+66D0 U+66D2 U+66CC
  DecodedInvalid = #$E6#$9B#$8C#$E6#$9B#$93#$E6#$9B#$90#$E6#$9B#$92#$E6#$9B#$8C;
  // Conforming decode of 'invalid-punycode-string' (same verification)
  DecodedInvalidLong =
    #$69#$6E#$76#$D5#$B1#$61#$6C#$69#$D5#$B2#$64#$2D#$70#$75#$6E#$D5#$B1 +
    #$D5#$B2#$79#$63#$6F#$64#$65;

procedure TTestPunycode.AssertEncodeDecode(const aTestName, aInput, ExpectedPunycode: string);
var
  aEncoded, aDecoded: string;
begin
  aEncoded := UTF8ToPunycode(aInput);
  AssertEquals(aTestName + ': encoding mismatch', ExpectedPunycode, aEncoded);
  aDecoded := PunycodeToUTF8(aEncoded);
  AssertEquals(aTestName, aInput, aDecoded);
end;

procedure TTestPunycode.AssertRoundTrip(const aTestName, aInput: string);
var
  aEncoded, aDecoded: string;
begin
  aEncoded := UTF8ToPunycode(aInput);
  aDecoded := PunycodeToUTF8(aEncoded);
  AssertEquals(Format('%s: data changed after round-trip', [aTestName]), aInput, aDecoded);
end;

procedure TTestPunycode.TestRussianDomain;
begin
  // Test Cyrillic characters
  AssertRoundTrip('Cyrillic word', 'пример');
  AssertRoundTrip('Test', 'испытание');

  // Known results
  AssertEncodeDecode('Test', 'тест', 'e1aybc');
end;

procedure TTestPunycode.TestChineseCharacters;
begin
  // Chinese characters
  AssertRoundTrip('China', '中国');
  AssertRoundTrip('Chinese text', '中文域名');
end;

procedure TTestPunycode.TestArabicText;
begin
  // Arabic text
  AssertRoundTrip('Arabic', 'العربية');
  AssertRoundTrip('Arabic domain', 'مثال');
end;

procedure TTestPunycode.TestGermanUmlaut;
begin
  // German characters with umlauts
  AssertRoundTrip('München', 'München');
  AssertRoundTrip('Bücher', 'Bücher');
end;

procedure TTestPunycode.TestJapaneseText;
begin
  // Japanese Character
  AssertRoundTrip('Japan', '日本');
  AssertRoundTrip('Japanese text', 'ドメイン名例');
end;

procedure TTestPunycode.TestMixedContent;
begin
  // Mixed content: ASCII + Unicode
  AssertRoundTrip('Mixed 1', 'hello世界');
  AssertRoundTrip('Mixed 2', 'тест-123');
  AssertRoundTrip('Mixed 3', 'example中文');
end;

procedure TTestPunycode.TestEmptyString;
begin
  // Empty string
  AssertEncodeDecode('Empty string', '', '');
end;

procedure TTestPunycode.TestSingleCharacter;
begin
  // Single character cases
  AssertRoundTrip('One cyrillic character', 'а');
  AssertRoundTrip('One chinese character', '中');
end;

procedure TTestPunycode.TestLongString;
var
  aLongRussian: String;
  i: Integer;
begin
  // Long string
  aLongRussian := EmptyStr;
  for i := 1 to 100 do
    aLongRussian+='тест';

  AssertRoundTrip('Long string', aLongRussian);
end;

procedure TTestPunycode.TestOnlyNonASCII;
begin
  // Only non-ASCII characters
  AssertRoundTrip('Only cyrillic', 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя');
  AssertRoundTrip('Only chinese', '一二三四五六七八九十');
end;

procedure TTestPunycode.TestSpecialCharacters;
begin
  // Special Unicode characters
  AssertRoundTrip('Currency symbols', '€£¥₽');
  AssertRoundTrip('Mathematical symbols', '∑∏∫∆');
  AssertRoundTrip('Emoji', '😀😃😄😁');
end;

procedure TTestPunycode.TestNumbersAndSymbols;
begin
  // Numbers and symbols mixed
  AssertRoundTrip('Digits with Cyrillic', 'тест123');
  AssertRoundTrip('Symbols with Chinese', '中国-test');
end;

procedure TTestPunycode.TestCaseInsensitive;
var
  aLower, aUpper, aCombined: string;
begin
  // Test case insensitivity of Punycode
  aLower := UTF8ToPunycode('тест');
  aUpper := UTF8ToPunycode('ТЕСТ');  
  aCombined := UTF8ToPunycode('Тест');

  // All must be converted correctly
  AssertEquals('Lowercase', 'тест', PunycodeToUTF8(aLower));
  AssertEquals('Uppercase', 'ТЕСТ', PunycodeToUTF8(aUpper));
  AssertEquals('Capitalized', 'Тест', PunycodeToUTF8(aCombined));
end;

procedure TTestPunycode.TestInvalidPunycode;
begin
  // 'invalid' is not valid punycode, yet RFC 3492 decoders produce a
  // well-defined output for it. This is a conformance vector verified
  // byte-for-byte against Python's punycode codec:
  AssertEquals('Conforming decode of ''invalid''',
               DecodedInvalid, PunycodeToUTF8('invalid'));
  AssertEquals('Conforming decode of ''invalid-punycode-string''',
               DecodedInvalidLong, PunycodeToUTF8('invalid-punycode-string'));
end;

procedure TTestPunycode.TestCorruptedData;
begin
  // Corrupted data must not raise exceptions and must follow the
  // library error contract (EmptyStr on error)
  AssertEquals('Empty input', EmptyStr, PunycodeToUTF8(EmptyStr));
  AssertEquals('Invalid input decodes conformingly',
               DecodedInvalid, PunycodeToUTF8('invalid'));
end;

procedure TTestPunycode.TestLargeData;
var
  aLargeString: string;
  i: Integer;
begin
  // Big data test
  aLargeString := '';
  for i := 1 to 1000 do
    aLargeString := aLargeString + 'тест' + IntToStr(i) + 'test';

  AssertRoundTrip('Big data', aLargeString);
end;

procedure TTestPunycode.TestRealWorldDomains;
begin
  // Real-world examples of internationalized domain names
  AssertRoundTrip('Wikipedia', 'википедия'); // википедия.org
  AssertRoundTrip('Mail', 'почта'); // почта.рф
end;

procedure TTestPunycode.TestDisallowedCharacters;
begin
  AssertEquals('Corrupted character (cyrillic)', EmptyStr, PunycodeToUTF8('пример'));
  AssertEquals('Corrupted character (%)', EmptyStr, PunycodeToUTF8('ab%cd'));
end;

procedure TTestPunycode.TestMalformedStructure;
begin
  AssertEquals('Only delimiter', EmptyStr, PunycodeToUTF8('-'));
end;

procedure TTestPunycode.TestDeterministicEncoding;
begin
  AssertEquals('Deterministic encoding', UTF8ToPunycode('пример'), UTF8ToPunycode('пример'));
end;

procedure TTestPunycode.TestReferenceVectors;
begin
  // Reference vectors verified with two independent implementations
  // (Python codecs 'punycode' and known registered domains);
  // every vector is checked in both directions (encode and decode)
  AssertEncodeDecode('Cyrillic', 'тест', 'e1aybc');
  AssertEncodeDecode('Cyrillic', 'пример', 'e1afmkfd');
  AssertEncodeDecode('German', 'münchen', 'mnchen-3ya');
  AssertEncodeDecode('German', 'bücher', 'bcher-kva');
  AssertEncodeDecode('Chinese', '中国', 'fiqs8s');
  AssertEncodeDecode('Japanese', '日本', 'wgv71a');
  AssertEncodeDecode('Arabic', 'مثال', 'mgbh0fb');
  AssertEncodeDecode('Japanese', 'ドメイン名例', 'eckwd4c7cu47r2wf');
  AssertEncodeDecode('Emoji', '😀', 'e28h');
  AssertEncodeDecode('Mixed basic+extended', 'ab-ч', 'ab--vfd');
  AssertEncodeDecode('Mixed digits', 'субдомен123', '123-9cdpg2cjg1aw');
end;

procedure TTestPunycode.TestOverflowStress;
var
  s, puny: string;
begin
  // Stress vector for the encoder overflow (RFC 3492 section 6.4):
  // 50000 x U+0080 + 5000 x U+0099 + 5000 x U+10FFFF. Verified with
  // Python's punycode codec: the encoded length must be 60015 and the
  // round-trip must be identical. The pre-Stage-1 encoder returned 60013
  // and broke the round-trip because of 32-bit overflow in the delta
  // accumulation; fixed by QWord arithmetic + explicit guards.
  s := RepeatUTF8(#$C2#$80, 50000) +           // 50000 x U+0080
       RepeatUTF8(#$C2#$99, 5000) +            // 5000 x U+0099
       RepeatUTF8(#$F4#$8F#$BF#$BF, 5000);     // 5000 x U+10FFFF
  puny := UTF8ToPunycode(s);
  AssertEquals('Overflow stress: encoded length', 60015, Length(puny));
  AssertRoundTrip('Overflow stress: round-trip', s);
end;

procedure TTestPunycode.TestOutOfBoundsAndCorruptedData;
var
  puny: string;
begin
  // Invalid punycode-strings: verified that Python's punycode codec raises
  // UnicodeError for every input below; the library contract is EmptyStr
  AssertEquals('', PunycodeToUTF8('ex ample')); // whitespace forbidden
  AssertEquals('', PunycodeToUTF8('%'));        // forbidden character
  AssertEquals('', PunycodeToUTF8(#$01#$02'test')); // Control chars
  AssertEquals('', PunycodeToUTF8('!@#$%^&*()'));   // Symbols only
  AssertEquals('', PunycodeToUTF8('%%%%%'));        // Total garbage

  // Out-of-bounds: 5000 x 'a' is a conforming decode producing
  // 5000 x U+0080 (verified against Python's punycode codec) —
  // this must stay a non-empty, deterministic result
  puny := PunycodeToUTF8(StringOfChar('a', 5000));
  AssertEquals('5000 x ''a'' must decode to 5000 x U+0080',
    RepeatUTF8(#$C2#$80, 5000), puny);

  // 20 x 'z' ends with a truncated digit group: invalid input since
  // Stage 2 (Python raises "incomplete punycode string"); here it also
  // dies on the W overflow guard. 20 x '9' overflows W/I; since Stage 1
  // that is cut off by explicit guards, not luck.
  puny := PunycodeToUTF8(StringOfChar('z', 20));
  AssertEquals('20 x ''z'': truncated digit group', EmptyStr, puny);
  puny := PunycodeToUTF8(StringOfChar('9', 20));
  AssertEquals('20 x ''9'': overflow', EmptyStr, puny);
end;

procedure TTestPunycode.TestStrictUTF8Encode;
begin
  // Stage 2: the encoder input must be well-formed UTF-8 (RFC 3629); any
  // violation fails the whole input with EmptyStr — no phantom code
  // points, no skipped bytes
  AssertEquals('Truncated 2-byte sequence', EmptyStr, UTF8ToPunycode(#$C3'AB'));
  AssertEquals('Stray continuation byte', EmptyStr, UTF8ToPunycode(#$80));
  AssertEquals('Invalid lead byte ($F8)', EmptyStr,
    UTF8ToPunycode('a' + #$F8#$80#$80#$80#$80 + 'b'));
  AssertEquals('Overlong encoding ($C0 $80)', EmptyStr, UTF8ToPunycode(#$C0#$80));
  AssertEquals('UTF-16 surrogate (ED A0 80)', EmptyStr, UTF8ToPunycode(#$ED#$A0#$80));
  AssertEquals('Above U+10FFFF (F4 90 80 80)', EmptyStr, UTF8ToPunycode(#$F4#$90#$80#$80));
  // Valid UTF-8 must still encode
  AssertEquals('Valid UTF-8 still encodes', 'e1aybc', UTF8ToPunycode('тест'));
end;

procedure TTestPunycode.TestStrictPunycodeDecode;
begin
  // Stage 2 decode-side strictness: a non-ASCII byte in the basic part
  // (before the last delimiter) is invalid, since basic code points are
  // ASCII per RFC 3492 (verified: Python raises UnicodeDecodeError)
  AssertEquals('Non-ASCII byte in basic part', EmptyStr,
    PunycodeToUTF8('x' + #$C3#$A4 + '-aa'));

  // A valid punycode without a delimiter must still decode; the exact
  // output is verified with Python ('Ωίθηδ'). Pure-ASCII inputs decode as
  // digit sequences by design, so this is not an identity round-trip.
  AssertEquals('Valid punycode without delimiter',
    #$CE#$A9#$CE#$AF#$CE#$B8#$CE#$B7#$CE#$B4, PunycodeToUTF8('example'));
end;

procedure TTestPunycode.TestTryPunycodeContract;
var
  aOut: string;
begin
  // Stage 3: the Try* pair is the primary API — True on success with the
  // output filled, False on invalid input with the output guaranteed
  // empty. An empty input is a success with an empty result, not an error.

  // Positive: reference vectors of Stage 0, both directions
  AssertTrue('Encode ''тест'' succeeds', TryUTF8ToPunycode('тест', aOut));
  AssertEquals('Encode ''тест'' result', 'e1aybc', aOut);
  AssertTrue('Decode ''e1aybc'' succeeds', TryPunycodeToUTF8('e1aybc', aOut));
  AssertEquals('Decode ''e1aybc'' result', 'тест', aOut);
  AssertTrue('Encode ''münchen'' succeeds', TryUTF8ToPunycode('münchen', aOut));
  AssertEquals('Encode ''münchen'' result', 'mnchen-3ya', aOut);
  AssertTrue('Decode ''mnchen-3ya'' succeeds', TryPunycodeToUTF8('mnchen-3ya', aOut));
  AssertEquals('Decode ''mnchen-3ya'' result', 'münchen', aOut);

  // Positive: empty input is a success with an empty result
  AssertTrue('Empty encode succeeds', TryUTF8ToPunycode(EmptyStr, aOut));
  AssertEquals('Empty encode result', EmptyStr, aOut);
  AssertTrue('Empty decode succeeds', TryPunycodeToUTF8(EmptyStr, aOut));
  AssertEquals('Empty decode result', EmptyStr, aOut);

  // Negative: the Stage 2 invalid-UTF-8 set (encode side)
  AssertFalse('Malformed UTF-8 fails', TryUTF8ToPunycode(#$C3'AB', aOut));
  AssertEquals('Failed encode leaves output empty', EmptyStr, aOut);
  AssertFalse('Invalid lead byte fails',
    TryUTF8ToPunycode('a' + #$F8#$80#$80#$80#$80 + 'b', aOut));
  AssertEquals('Failed encode leaves output empty (2)', EmptyStr, aOut);

  // Negative: the Stage 2 invalid-punycode set (decode side)
  AssertFalse('Non-ASCII byte in basic part fails',
    TryPunycodeToUTF8('x' + #$C3#$A4 + '-aa', aOut));
  AssertEquals('Failed decode leaves output empty', EmptyStr, aOut);
  AssertFalse('Forbidden character fails', TryPunycodeToUTF8('ab%cd', aOut));
  AssertFalse('Truncated digit group fails',
    TryPunycodeToUTF8(StringOfChar('z', 20), aOut));
  AssertFalse('Overflow fails', TryPunycodeToUTF8(StringOfChar('9', 20), aOut));
  AssertEquals('Failed decode leaves output empty (2)', EmptyStr, aOut);

  // Conforming-but-odd inputs remain successes, not errors
  AssertTrue('Conforming decode of ''invalid'' is a success',
    TryPunycodeToUTF8('invalid', aOut));
  AssertEquals('Conforming decode result', DecodedInvalid, aOut);
end;

{ TTestIDN }

procedure TTestIDN.TestPureASCII;
begin
  AssertEquals('Pure ASCII domain remains unchanged',
               'example.com', UnicodeToIDN('example.com'));
  AssertEquals('Pure ASCII domain round-trip',
               'example.com', IDNToUnicode('example.com'));
end;

procedure TTestIDN.TestRussianIDN;
begin
  AssertEquals('Russian domain to IDN',
               'xn--e1afmkfd.xn--p1ai', UnicodeToIDN('пример.рф'));
  AssertEquals('Russian domain to Unicode',
               'пример.рф', IDNToUnicode('xn--e1afmkfd.xn--p1ai'));
end;

procedure TTestIDN.TestMixedDomain;
begin
  AssertEquals('Mixed domain to IDN',
               'xn--mnchen-3ya.com', UnicodeToIDN('münchen.com'));
  AssertEquals('Mixed domain to Unicode',
               'münchen.com', IDNToUnicode('xn--mnchen-3ya.com'));
end;

procedure TTestIDN.TestSubdomains;
begin
  AssertEquals('Subdomain with IDN', 'mail.xn--80a1acny', UnicodeToIDN('mail.почта'));
  AssertEquals('Subdomain with IDN', 'xn--123-9cdpg2cjg1aw.123.xn--d1aad1agbce.xn--e1afmkfd.xn--p1acf',
    UnicodeToIDN('субдомен123.123.поддомен.пример.рус'));
  AssertEquals('Subdomain Unicode', 'mail.онлайн', IDNToUnicode('mail.xn--80asehdb'));            
  AssertEquals('Subdomain Unicode', 'субдомен123.123.поддомен.пример.рус',
    IDNToUnicode('xn--123-9cdpg2cjg1aw.123.xn--d1aad1agbce.xn--e1afmkfd.xn--p1acf'));
end;

procedure TTestIDN.TestRealDomain;
begin
  AssertEquals('Real .org domain', 'xn--d1acufc.xn--p1ai', UnicodeToIDN('домен.рф'));
  AssertEquals('Real .org domain decoded', 'домен.рф', IDNToUnicode('xn--d1acufc.xn--p1ai'));
end;

procedure TTestIDN.TestEmptyInput;
begin
  AssertEquals('Empty input to IDN', '', UnicodeToIDN(''));
  AssertEquals('Empty input from IDN', '', IDNToUnicode(''));
end;

procedure TTestIDN.TestTryIDNContract;
var
  aOut: string;
begin
  // Stage 3: the Try* pair of the IDN layer — True on success with the
  // output filled, False on invalid input with the output guaranteed empty

  // Positive: the Stage 0 vectors through the domain layer
  AssertTrue('Encode пример.рф succeeds', TryUnicodeToIDN('пример.рф', aOut));
  AssertEquals('Encode пример.рф result', 'xn--e1afmkfd.xn--p1ai', aOut);
  AssertTrue('Decode xn--e1afmkfd.xn--p1ai succeeds',
    TryIDNToUnicode('xn--e1afmkfd.xn--p1ai', aOut));
  AssertEquals('Decode xn--e1afmkfd.xn--p1ai result', 'пример.рф', aOut);
  AssertTrue('Encode münchen.com succeeds', TryUnicodeToIDN('münchen.com', aOut));
  AssertEquals('Encode münchen.com result', 'xn--mnchen-3ya.com', aOut);
  AssertTrue('Pure ASCII passes', TryUnicodeToIDN('example.com', aOut));
  AssertEquals('Pure ASCII result', 'example.com', aOut);

  // Positive: empty domain is a success with an empty result
  AssertTrue('Empty domain encode succeeds', TryUnicodeToIDN(EmptyStr, aOut));
  AssertEquals('Empty domain encode result', EmptyStr, aOut);
  AssertTrue('Empty domain decode succeeds', TryIDNToUnicode(EmptyStr, aOut));
  AssertEquals('Empty domain decode result', EmptyStr, aOut);

  // Negative: a non-ASCII label that cannot be encoded fails the whole
  // domain instead of emitting a broken 'xn--' label
  AssertFalse('Malformed UTF-8 label fails',
    TryUnicodeToIDN(#$C3'AB' + '.com', aOut));
  AssertEquals('Failed encode leaves output empty', EmptyStr, aOut);

  // Stage 4: an xn-- label that cannot be decoded is kept verbatim instead
  // of failing the whole domain or being silently dropped — the result
  // never loses a label, so a decode round-trip cannot collapse the domain
  AssertTrue('Undecodable xn-- label keeps the domain decodable',
    TryIDNToUnicode('test.xn--!!', aOut));
  AssertEquals('Undecodable xn-- label kept verbatim', 'test.xn--!!', aOut);
end;

procedure TTestIDN.TestXnPrefixCaseInsensitive;
begin
  // Baseline: lowercase prefix decodes fine
  AssertEquals('Lowercase xn-- prefix',
               'пример.рф', IDNToUnicode('xn--e1afmkfd.xn--p1ai'));
  // DNS is case-insensitive: the uppercase prefix must decode as well
  AssertEquals('Uppercase XN-- prefix',
               'пример.рф', IDNToUnicode('XN--e1afmkfd.xn--p1ai'));
  // Mixed case, including the payload: the label is lowercased before
  // decoding, so the basic part comes out in lowercase (IDNA ToUnicode
  // behavior)
  AssertEquals('Mixed-case Xn-- label with payload',
               'münchen.com', IDNToUnicode('Xn--Mnchen-3ya.com'));
end;

procedure TTestIDN.TestFailedLabelKept;
var
  aResult: string;
begin
  // A label that fails to decode must be kept verbatim, not silently
  // dropped: 'test.xn--!!' must round-trip to itself
  aResult := IDNToUnicode('test.xn--!!');
  AssertEquals('Undecodable label is kept', 'test.xn--!!', aResult);
end;

procedure TTestIDN.TestIDNCasefoldMVP;
begin
  // Roadmap vector: uppercase Cyrillic folds to lowercase before encoding
  AssertEquals('Uppercase Cyrillic folds', 'xn--e1afmkfd.xn--p1ai',
    UnicodeToIDN('ПРИМЕР.рф'));

  // Uppercase and lowercase forms encode identically
  AssertEquals('Cyrillic casefold equivalence', UnicodeToIDN('пример.рф'),
    UnicodeToIDN('ПРИМЕР.рф'));

  // Yo (U+0401) folds to lowercase yo (U+0451) and round-trips to the
  // lowercase form
  AssertEquals('Yo folds to lowercase yo', UnicodeToIDN('ёёё.рф'),
    UnicodeToIDN('ЁЁЁ.рф'));
  AssertEquals('Yo round-trip', 'ёёё.рф',
    IDNToUnicode(UnicodeToIDN('ЁЁЁ.рф')));

  // Basic Greek uppercase folds (U+0391..U+03A9, +$20)
  AssertEquals('Greek casefold equivalence', UnicodeToIDN('ωμεγα.gr'),
    UnicodeToIDN('ΩΜΕΓΑ.gr'));

  // ASCII folds
  AssertEquals('ASCII folds', 'example.com', UnicodeToIDN('EXAMPLE.COM'));

  // MVP limitation: Latin-1 Ü (U+00DC) is outside the folded ranges and
  // passes through as-is. Only the ASCII letters fold, so 'MÜNCHEN'
  // encodes to 'xn--mnchen-psa': the extended part matches Python's
  // punycode of the U+00DC code point, the basic part is the folded ASCII
  AssertEquals('Latin-1 Ü is not folded by the MVP', 'xn--mnchen-psa.com',
    UnicodeToIDN('MÜNCHEN.com'));
end;

procedure TTestIDN.TestIDNAltSeparators;
const
  SepFF0E = #$EF#$BC#$8E; // U+FF0E FULLWIDTH FULL STOP
  Sep3002 = #$E3#$80#$82; // U+3002 IDEOGRAPHIC FULL STOP
  SepFF61 = #$EF#$BD#$81; // U+FF61 HALFWIDTH IDEOGRAPHIC FULL STOP
begin
  // All three Unicode separators act as the ASCII full stop (Stage 5);
  // the roadmap vector: 'пример．рф' must split into two labels
  AssertEquals('U+FF0E acts as a label separator', 'xn--e1afmkfd.xn--p1ai',
    UnicodeToIDN('пример' + SepFF0E + 'рф'));
  AssertEquals('U+3002 acts as a label separator', 'xn--e1afmkfd.xn--p1ai',
    UnicodeToIDN('пример' + Sep3002 + 'рф'));
  AssertEquals('U+FF61 acts as a label separator', 'xn--e1afmkfd.xn--p1ai',
    UnicodeToIDN('пример' + SepFF61 + 'рф'));

  // Round-trip: the decoded form uses the ASCII full stop
  AssertEquals('Separators decode to the ASCII full stop', 'пример.рф',
    IDNToUnicode(UnicodeToIDN('пример' + SepFF0E + 'рф')));

  // The decode direction deliberately does not map separators: a foreign
  // label that never went through the encoder is kept verbatim
  AssertEquals('Decode keeps a foreign separator verbatim',
    'пример' + SepFF0E + 'рф', IDNToUnicode('пример' + SepFF0E + 'рф'));
end;

procedure TTestIDN.TestIDNForbiddenASCII;
const
  // The forbidden list of fpidn.pas (UseSTD3ASCIIRules-lite), duplicated
  // here on purpose: the test pins the behavior, not the constant
  ForbiddenTestChars: array[0..9] of Char =
    ('<', '>', '"', '/', '\', '?', '#', '@', ':', '|');
var
  aOut: string;
  i: Integer;
begin
  // Roadmap vector: 'exa mple.com' is rejected (Try*-contract: False with
  // the output guaranteed empty)
  AssertFalse('Space in a label fails', TryUnicodeToIDN('exa mple.com', aOut));
  AssertEquals('Failed encode leaves output empty', EmptyStr, aOut);
  AssertEquals('Plain wrapper projects the failure to EmptyStr', EmptyStr,
    UnicodeToIDN('exa mple.com'));

  // UseSTD3 applies to non-ASCII labels as well
  AssertFalse('Space inside a Cyrillic label fails',
    TryUnicodeToIDN('т est.com', aOut));
  AssertEquals('Failed encode leaves output empty (2)', EmptyStr, aOut);

  // Every character of the forbidden list
  for i := Low(ForbiddenTestChars) to High(ForbiddenTestChars) do
  begin
    AssertFalse('Forbidden character ''' + ForbiddenTestChars[i] + ''' fails',
      TryUnicodeToIDN('a' + ForbiddenTestChars[i] + 'b.com', aOut));
    AssertEquals('Failed encode leaves output empty (3)', EmptyStr, aOut);
  end;

  // Control bytes (below $21) are forbidden too
  AssertFalse('Control byte fails', TryUnicodeToIDN('a' + #$01 + 'b.com', aOut));
  AssertEquals('Failed encode leaves output empty (4)', EmptyStr, aOut);

  // Allowed ASCII still passes: the hyphen of LDH labels
  AssertTrue('Hyphen is allowed', TryUnicodeToIDN('exa-mple.com', aOut));
  AssertEquals('Hyphen result', 'exa-mple.com', aOut);
end;

procedure TTestIDN.TestIDNLabelLengthLimit;
var
  aOut: string;
begin
  // DNS limit: a label is at most 63 bytes, ASCII labels included
  AssertTrue('A 63-byte ASCII label passes',
    TryUnicodeToIDN(StringOfChar('a', 63) + '.com', aOut));
  AssertEquals('A 63-byte ASCII label passes unchanged',
    StringOfChar('a', 63) + '.com', aOut);
  AssertFalse('A 64-byte ASCII label fails',
    TryUnicodeToIDN(StringOfChar('a', 64) + '.com', aOut));
  AssertEquals('Failed encode leaves output empty', EmptyStr, aOut);

  // Roadmap vector: a label of 70 characters fails; the xn-- encoding of
  // 70 Cyrillic characters is longer than 63 bytes as well
  AssertFalse('A 70-character Cyrillic label fails',
    TryUnicodeToIDN(RepeatUTF8(#$D0#$B0, 70) + '.com', aOut));
  AssertEquals('Failed encode leaves output empty (2)', EmptyStr, aOut);
end;

procedure TTestIDN.TestIDNDomainLengthLimit;
var
  aLabel, aOut: string;
begin
  // DNS limit: the whole domain is at most 253 bytes. Every label below is
  // within the 63-byte label limit, so the failure comes from the total
  aLabel := StringOfChar('a', 61);
  AssertFalse('A 309-byte domain fails',
    TryUnicodeToIDN(aLabel + '.' + aLabel + '.' + aLabel + '.' + aLabel + '.' +
      aLabel, aOut));
  AssertEquals('Failed encode leaves output empty', EmptyStr, aOut);

  // The same labels in a 247-byte domain still pass
  AssertTrue('A 247-byte domain passes',
    TryUnicodeToIDN(aLabel + '.' + aLabel + '.' + aLabel + '.' + aLabel, aOut));
  AssertEquals('A 247-byte domain passes unchanged',
    aLabel + '.' + aLabel + '.' + aLabel + '.' + aLabel, aOut);
end;

initialization

  RegisterTest(TTestPunycode);  
  RegisterTest(TTestIDN);
end.

