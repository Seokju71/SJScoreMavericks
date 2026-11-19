import std/unicode
import note

type
  ChordTokenKind* = enum
    tkNoteLetter
    tkSharp
    tkFlat
    tkMajorKeyword
    tkMinorKeyword
    tkDimKeyword
    tkHalfDimKeyword
    tkAugKeyword
    tkSusKeyword
    tkAddKeyword
    tkOmitKeyword
    tkAltKeyword
    tkNumber
    tkSlash
    tkLeftParen
    tkRightParen
    tkComma
    tkWhitespace
    tkUnknown

  ChordToken* = object
    kind*: ChordTokenKind
    noteLetter*: NoteLetter
    numValue*: int
    startByte*: int
    endByte*: int

proc isAsciiWhitespace(ch: char): bool {.inline.} =
  ch in {' ', '\t', '\n', '\r', '\v', '\f'}

proc isAsciiDigit(ch: char): bool {.inline.} =
  ch in {'0'..'9'}

proc matchPrefix(input: string, cursor: var int, kw: string): bool =
  if cursor + kw.len > input.len:
    return false
  for i in 0 ..< kw.len:
    if input[cursor + i] != kw[i]:
      return false
  cursor += kw.len
  true

proc tokenizeChord*(input: string): seq[ChordToken] =
  result = @[]
  var cursor = 0
  let n = input.len

  while cursor < n:
    let start = cursor
    let ch = input[cursor]

    # 1. Whitespace
    if ch.isAsciiWhitespace:
      inc cursor
      while cursor < n and input[cursor].isAsciiWhitespace:
        inc cursor
      result.add(ChordToken(kind: tkWhitespace, startByte: start, endByte: cursor))
      continue

    # 2. Multi-character keywords (longest-match first)
    if matchPrefix(input, cursor, "halfdim") or matchPrefix(input, cursor, "hdim"):
      result.add(ChordToken(kind: tkHalfDimKeyword, startByte: start, endByte: cursor))
      continue
    if matchPrefix(input, cursor, "major") or matchPrefix(input, cursor, "maj"):
      result.add(ChordToken(kind: tkMajorKeyword, startByte: start, endByte: cursor))
      continue
    if matchPrefix(input, cursor, "minor") or matchPrefix(input, cursor, "min"):
      result.add(ChordToken(kind: tkMinorKeyword, startByte: start, endByte: cursor))
      continue
    if matchPrefix(input, cursor, "dim"):
      result.add(ChordToken(kind: tkDimKeyword, startByte: start, endByte: cursor))
      continue
    if matchPrefix(input, cursor, "aug"):
      result.add(ChordToken(kind: tkAugKeyword, startByte: start, endByte: cursor))
      continue
    if matchPrefix(input, cursor, "sus"):
      result.add(ChordToken(kind: tkSusKeyword, startByte: start, endByte: cursor))
      continue
    if matchPrefix(input, cursor, "add"):
      result.add(ChordToken(kind: tkAddKeyword, startByte: start, endByte: cursor))
      continue
    if matchPrefix(input, cursor, "omit") or matchPrefix(input, cursor, "no"):
      result.add(ChordToken(kind: tkOmitKeyword, startByte: start, endByte: cursor))
      continue
    if matchPrefix(input, cursor, "alt"):
      result.add(ChordToken(kind: tkAltKeyword, startByte: start, endByte: cursor))
      continue

    # 3. Numbers (multi-digit ASCII integers)
    if ch.isAsciiDigit:
      var val = 0
      while cursor < n and input[cursor].isAsciiDigit:
        val = val * 10 + (ord(input[cursor]) - ord('0'))
        inc cursor
      result.add(ChordToken(kind: tkNumber, numValue: val, startByte: start, endByte: cursor))
      continue

    # 4. Single-character ASCII note letters (A-G)
    let nl = parseNoteLetter(ch)
    if nl.ok:
      inc cursor
      result.add(ChordToken(kind: tkNoteLetter, noteLetter: nl.letter, startByte: start, endByte: cursor))
      continue

    # 5. Single-character UTF-8 / ASCII symbols
    var r: Rune
    fastRuneAt(input, cursor, r, doInc = true)
    let code = int(r)
    let kind =
      case code
      of ord('#'), 0x266F: tkSharp          # #, ♯
      of ord('b'), 0x266D: tkFlat           # b, ♭
      of 0x2206, 0x0394, ord('M'): tkMajorKeyword  # ∆, Δ, M
      of ord('m'), ord('-'): tkMinorKeyword
      of ord('o'), 0x00B0: tkDimKeyword     # o, °
      of 0x00F8, 0x00D8: tkHalfDimKeyword   # ø, Ø
      of ord('+'): tkAugKeyword
      of ord('/'): tkSlash
      of ord('('): tkLeftParen
      of ord(')'): tkRightParen
      of ord(','): tkComma
      else: tkUnknown

    result.add(ChordToken(kind: kind, startByte: start, endByte: cursor))
