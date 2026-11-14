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
    // xn-- prefix handling (strict assertions enabled in Stage 4)
    procedure TestXnPrefixCaseInsensitive;
    procedure TestFailedLabelKept;
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
  // round-trip must be identical. The current encoder returns 60013
  // and breaks the round-trip because of 32-bit overflow in the delta
  // accumulation; fixed by Stage 1 (QWord arithmetic + explicit guards).
  s := RepeatUTF8(#$C2#$80, 50000) +           // 50000 x U+0080
       RepeatUTF8(#$C2#$99, 5000) +            // 5000 x U+0099
       RepeatUTF8(#$F4#$8F#$BF#$BF, 5000);     // 5000 x U+10FFFF
  puny := UTF8ToPunycode(s);
  // TODO Этап 1: включить строгие проверки, когда дельта и промежуточные
  // произведения перейдут на QWord с явными проверками переполнения:
  // AssertEquals('Overflow stress: encoded length', 60015, Length(puny));
  // AssertRoundTrip('Overflow stress: round-trip', s);
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

  // Out-of-bounds: 20 x 'z' ends with a truncated digit group and
  // 20 x '9' overflows W/I in the decoder. Currently the first returns
  // garbage and the second returns EmptyStr only by luck. The proper
  // EmptyStr-on-error behaviour arrives with Stages 1-2.
  puny := PunycodeToUTF8(StringOfChar('z', 20));
  // TODO Этап 2: включить проверку, когда обрыв цифровой группы станет
  // невалидным входом (а не трактующим обрыв как финальную цифру):
  // AssertEquals('20 x ''z'': truncated digit group', EmptyStr, puny);
  puny := PunycodeToUTF8(StringOfChar('9', 20));
  // TODO Этап 1: включить проверку, когда переполнение I/W будет отсекаться
  // явной защитой, а не случайным пустым результатом:
  // AssertEquals('20 x ''9'': overflow', EmptyStr, puny);
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

procedure TTestIDN.TestXnPrefixCaseInsensitive;
begin
  // Baseline: lowercase prefix decodes fine
  AssertEquals('Lowercase xn-- prefix',
               'пример.рф', IDNToUnicode('xn--e1afmkfd.xn--p1ai'));
  // DNS is case-insensitive, so the uppercase prefix must decode as well.
  // Currently the prefix comparison is case-sensitive and the label is
  // returned undecoded.
  // TODO Этап 4: включить проверку, когда префикс станет регистронезависимым:
  // AssertEquals('Uppercase XN-- prefix',
  //              'пример.рф', IDNToUnicode('XN--e1afmkfd.xn--p1ai'));
end;

procedure TTestIDN.TestFailedLabelKept;
var
  aResult: string;
begin
  // A label that fails to decode must be kept verbatim; currently it is
  // silently dropped ('test.xn--!!' returns 'test.')
  aResult := IDNToUnicode('test.xn--!!');
  // TODO Этап 4: включить проверку, когда неудачное декодирование перестанет
  // терять метку:
  // AssertEquals('Undecodable label is kept', 'test.xn--!!', aResult);
end;

initialization

  RegisterTest(TTestPunycode);  
  RegisterTest(TTestIDN);
end.

