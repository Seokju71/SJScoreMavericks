import std/[options, strutils]
import note, chord_ast, chord_lexer

type
  ChordParserState = object
    input: string
    tokens: seq[ChordToken]
    idx: int

proc isAtEnd(p: ChordParserState): bool {.inline.} =
  p.idx >= p.tokens.len

proc peek(p: ChordParserState, offset: int = 0): Option[ChordToken] {.inline.} =
  let target = p.idx + offset
  if target < p.tokens.len:
    some(p.tokens[target])
  else:
    none(ChordToken)

proc consume(p: var ChordParserState): Option[ChordToken] {.inline.} =
  if p.idx < p.tokens.len:
    result = some(p.tokens[p.idx])
    inc p.idx
  else:
    result = none(ChordToken)

proc remainingSource(p: ChordParserState): string =
  let cur = p.peek()
  if cur.isNone:
    return ""
  p.input[cur.get.startByte .. ^1]

proc chordExtensionFrom(num: int): Option[ChordExtension] =
  case num
  of 6: some(ceSixth)
  of 7: some(ceSeventh)
  of 9: some(ceNinth)
  of 11: some(ceEleventh)
  of 13: some(ceThirteenth)
  else: none(ChordExtension)

proc isParenthesizedMajorSeventhAhead(p: ChordParserState): bool =
  let t0 = p.peek(0)
  let t1 = p.peek(1)
  t0.isSome and t0.get.kind == tkLeftParen and
  t1.isSome and t1.get.kind == tkMajorKeyword

proc isSlashBassAhead(p: ChordParserState): bool =
  let t0 = p.peek(0)
  let t1 = p.peek(1)
  t0.isSome and t0.get.kind == tkSlash and
  t1.isSome and t1.get.kind == tkNoteLetter

proc parseAccidental(p: var ChordParserState): Accidental =
  let next = p.peek()
  if next.isNone:
    return accNatural
  case next.get.kind
  of tkSharp:
    discard p.consume()
    let next2 = p.peek()
    if next2.isSome and next2.get.kind == tkSharp:
      discard p.consume()
      return accDoubleSharp
    accSharp
  of tkFlat:
    discard p.consume()
    let next2 = p.peek()
    if next2.isSome and next2.get.kind == tkFlat:
      discard p.consume()
      return accDoubleFlat
    accFlat
  else:
    accNatural

proc parsePitchClass(p: var ChordParserState): Option[PitchClass] =
  let tok = p.peek()
  if tok.isNone or tok.get.kind != tkNoteLetter:
    return none(PitchClass)
  let letter = tok.get.noteLetter
  discard p.consume()
  let acc = p.parseAccidental()
  some(initPitchClass(letter, acc))

proc parseQuality(
  p: var ChordParserState,
  quality: var ChordQuality,
  isExplicitMajor: var bool,
  seventhQuality: var Option[SeventhQuality]
) =
  let next = p.peek()
  if next.isNone:
    return
  case next.get.kind
  of tkMinorKeyword:
    discard p.consume()
    let next2 = p.peek()
    if next2.isSome and next2.get.kind == tkMajorKeyword:
      discard p.consume()
      quality = cqMinorMajor
      isExplicitMajor = true
      seventhQuality = some(sqMajor)
    else:
      quality = cqMinor
  of tkMajorKeyword:
    discard p.consume()
    quality = cqMajor
    isExplicitMajor = true
    seventhQuality = some(sqMajor)
  of tkDimKeyword:
    discard p.consume()
    quality = cqDiminished
  of tkHalfDimKeyword:
    discard p.consume()
    quality = cqHalfDiminished
  of tkAugKeyword:
    discard p.consume()
    quality = cqAugmented
  else:
    discard

proc parsePrimaryExtension(
  p: var ChordParserState,
  quality: var ChordQuality,
  isExplicitMajor: bool,
  extensionDegree: var Option[ChordExtension],
  seventhQuality: var Option[SeventhQuality]
) =
  let tok = p.peek()
  if tok.isNone or tok.get.kind != tkNumber:
    return
  let num = tok.get.numValue

  if num == 5 and quality == cqMajor and not isExplicitMajor:
    discard p.consume()
    quality = cqPower
    return

  if num == 6:
    discard p.consume()
    let t0 = p.peek(0)
    let t1 = p.peek(1)
    if t0.isSome and t0.get.kind == tkSlash and
       t1.isSome and t1.get.kind == tkNumber and t1.get.numValue == 9:
      discard p.consume() # '/'
      discard p.consume() # '9'
      extensionDegree = some(ceSixNine)
    else:
      extensionDegree = some(ceSixth)
    return

  let ext = chordExtensionFrom(num)
  if ext.isSome:
    discard p.consume()
    extensionDegree = ext
    if seventhQuality.isNone:
      seventhQuality = some(if quality == cqDiminished: sqDiminished else: sqDominant)

proc parseSuspension(p: var ChordParserState): Option[Suspension] =
  let tok = p.peek()
  if tok.isNone or tok.get.kind != tkSusKeyword:
    return none(Suspension)
  discard p.consume()
  let next = p.peek()
  if next.isSome and next.get.kind == tkNumber:
    if next.get.numValue == 2:
      discard p.consume()
      return some(sus2)
    elif next.get.numValue == 4:
      discard p.consume()
      return some(sus4)
  some(sus)

proc parseTensionAccidental(p: var ChordParserState): TensionAccidental =
  let next = p.peek()
  if next.isNone:
    return taNatural
  case next.get.kind
  of tkFlat:
    discard p.consume()
    taFlat
  of tkSharp, tkAugKeyword:
    discard p.consume()
    taSharp
  of tkMinorKeyword:
    let next1 = p.peek(1)
    if next1.isSome and next1.get.kind == tkNumber:
      discard p.consume()
      taFlat
    else:
      taNatural
  else:
    taNatural

proc parseAddition(p: var ChordParserState): Option[ChordAddition] =
  let saved = p.idx
  let tok = p.peek()
  if tok.isNone:
    return none(ChordAddition)
  var kind: ChordAdditionKind
  case tok.get.kind
  of tkAddKeyword: kind = cakAdd
  of tkOmitKeyword: kind = cakOmit
  else: return none(ChordAddition)
  discard p.consume()

  let acc = p.parseTensionAccidental()
  let degTok = p.peek()
  if degTok.isNone or degTok.get.kind != tkNumber:
    p.idx = saved
    return none(ChordAddition)
  discard p.consume()
  some(ChordAddition(kind: kind, accidental: acc, degree: degTok.get.numValue))

proc parseTension(p: var ChordParserState, isParenthesized: bool): Option[Tension] =
  let saved = p.idx
  let acc = p.parseTensionAccidental()
  let degTok = p.peek()
  if degTok.isNone or degTok.get.kind != tkNumber:
    p.idx = saved
    return none(Tension)

  let degree = degTok.get.numValue
  let isValid =
    case degree
    of 5: acc != taNatural
    of 9, 11, 13: true
    else: false

  if not isValid:
    p.idx = saved
    return none(Tension)

  discard p.consume()
  some(Tension(accidental: acc, degree: degree, isParenthesized: isParenthesized))

proc parseParenthesizedGroup(
  p: var ChordParserState,
  suspension: var Option[Suspension],
  additions: var seq[ChordAddition],
  tensions: var seq[Tension],
  isAltered: var bool
): bool =
  let first = p.peek()
  if first.isNone or first.get.kind != tkLeftParen:
    return false
  let saved = p.idx
  discard p.consume() # '('

  var parsedAny = false
  while not p.isAtEnd and p.peek().get.kind != tkRightParen:
    if p.peek().get.kind == tkComma:
      discard p.consume()
      continue

    let susOpt = p.parseSuspension()
    if susOpt.isSome:
      suspension = susOpt
      parsedAny = true
      continue

    let addOpt = p.parseAddition()
    if addOpt.isSome:
      additions.add(addOpt.get)
      parsedAny = true
      continue

    if p.peek().get.kind == tkAltKeyword:
      discard p.consume()
      isAltered = true
      parsedAny = true
      continue

    let tenOpt = p.parseTension(isParenthesized = true)
    if tenOpt.isSome:
      tensions.add(tenOpt.get)
      parsedAny = true
      continue

    p.idx = saved
    return false

  if not parsedAny:
    p.idx = saved
    return false

  let closing = p.peek()
  if closing.isSome and closing.get.kind == tkRightParen:
    discard p.consume()
  true

proc parseChord*(input: string): ParsedChord =
  let trimmed = input.strip()
  if trimmed.len == 0:
    return ParsedChord(raw: input, quality: cqMajor, unparsed: "")

  var filtered: seq[ChordToken] = @[]
  for tok in tokenizeChord(input):
    if tok.kind != tkWhitespace:
      filtered.add(tok)

  if filtered.len == 0:
    return ParsedChord(raw: input, quality: cqMajor, unparsed: "")

  var p = ChordParserState(input: input, tokens: filtered, idx: 0)

  # 1. Root
  let rootOpt = p.parsePitchClass()
  if rootOpt.isNone:
    return ParsedChord(raw: input, root: none(PitchClass), quality: cqMajor, unparsed: p.remainingSource())

  var quality = cqMajor
  var isExplicitMajor = false
  var extensionDegree = none(ChordExtension)
  var seventhQuality = none(SeventhQuality)
  var suspension = none(Suspension)
  var additions: seq[ChordAddition] = @[]
  var tensions: seq[Tension] = @[]
  var isAltered = false
  var bass = none(PitchClass)

  # 2. Quality
  p.parseQuality(quality, isExplicitMajor, seventhQuality)

  # Minor-major with parentheses directly after m: Cm(maj7), Cm(∆7)
  if quality == cqMinor and p.isParenthesizedMajorSeventhAhead():
    discard p.consume() # '('
    discard p.consume() # majorKeyword
    quality = cqMinorMajor
    isExplicitMajor = true
    seventhQuality = some(sqMajor)
    let degTok = p.peek()
    if degTok.isSome and degTok.get.kind == tkNumber:
      let ext = chordExtensionFrom(degTok.get.numValue)
      if ext.isSome:
        discard p.consume()
        extensionDegree = ext
    let closing = p.peek()
    if closing.isSome and closing.get.kind == tkRightParen:
      discard p.consume()

  # 3. Primary extension
  p.parsePrimaryExtension(quality, isExplicitMajor, extensionDegree, seventhQuality)

  # 4. Modifiers & Tensions loop
  var madeProgress = true
  while madeProgress and not p.isAtEnd:
    madeProgress = false

    if p.isSlashBassAhead():
      break

    let susOpt = p.parseSuspension()
    if susOpt.isSome:
      suspension = susOpt
      madeProgress = true
      continue

    let addOpt = p.parseAddition()
    if addOpt.isSome:
      additions.add(addOpt.get)
      madeProgress = true
      continue

    if p.peek().get.kind == tkAltKeyword:
      discard p.consume()
      isAltered = true
      madeProgress = true
      continue

    if p.peek().get.kind == tkLeftParen:
      let savedIdx = p.idx
      if p.parseParenthesizedGroup(suspension, additions, tensions, isAltered):
        madeProgress = true
        continue
      else:
        p.idx = savedIdx
        break

    let tenOpt = p.parseTension(isParenthesized = false)
    if tenOpt.isSome:
      tensions.add(tenOpt.get)
      madeProgress = true
      continue

  # 5. Optional Slash Bass
  if p.isSlashBassAhead():
    discard p.consume() # '/'
    bass = p.parsePitchClass()

  # 6. Fault-tolerant unparsed tail
  let unparsed = p.remainingSource()

  ParsedChord(
    raw: input,
    root: rootOpt,
    quality: quality,
    isExplicitMajor: isExplicitMajor,
    extensionDegree: extensionDegree,
    seventhQuality: seventhQuality,
    suspension: suspension,
    additions: additions,
    tensions: tensions,
    isAltered: isAltered,
    bass: bass,
    unparsed: unparsed
  )
