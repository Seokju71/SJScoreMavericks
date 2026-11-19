import std/options
import note

type
  ChordQuality* = enum
    cqMajor
    cqMinor
    cqDiminished
    cqHalfDiminished
    cqAugmented
    cqMinorMajor
    cqPower

  ChordExtension* = enum
    ceSixth = 6
    ceSeventh = 7
    ceNinth = 9
    ceEleventh = 11
    ceThirteenth = 13
    ceSixNine = 69

  SeventhQuality* = enum
    sqDominant
    sqMajor
    sqDiminished

  Suspension* = enum
    sus2 = "sus2"
    sus4 = "sus4"
    sus = "sus"

  TensionAccidental* = enum
    taNatural = ""
    taFlat = "b"
    taSharp = "#"

  Tension* = object
    accidental*: TensionAccidental
    degree*: int
    isParenthesized*: bool

  ChordAdditionKind* = enum
    cakAdd
    cakOmit

  ChordAddition* = object
    kind*: ChordAdditionKind
    accidental*: TensionAccidental
    degree*: int

  ParsedChord* = object
    raw*: string
    root*: Option[PitchClass]
    quality*: ChordQuality
    isExplicitMajor*: bool
    extensionDegree*: Option[ChordExtension]
    seventhQuality*: Option[SeventhQuality]
    suspension*: Option[Suspension]
    additions*: seq[ChordAddition]
    tensions*: seq[Tension]
    isAltered*: bool
    bass*: Option[PitchClass]
    unparsed*: string

proc symbol*(acc: TensionAccidental, useUnicode: bool = false): string =
  if not useUnicode:
    return $acc
  case acc
  of taNatural: ""
  of taFlat: "♭"
  of taSharp: "♯"

proc formatted*(t: Tension, useUnicodeAccidental: bool = false, includeParentheses: bool = false): string =
  let core = t.accidental.symbol(useUnicodeAccidental) & $t.degree
  if includeParentheses and t.isParenthesized:
    return "(" & core & ")"
  core

proc formatted*(a: ChordAddition, useUnicodeAccidental: bool = false): string =
  let prefix = if a.kind == cakAdd: "add" else: "omit"
  prefix & a.accidental.symbol(useUnicodeAccidental) & $a.degree

proc isComplete*(c: ParsedChord): bool =
  c.root.isSome and c.unparsed.len == 0

proc isCanonicalHalfDiminished*(c: ParsedChord): bool =
  if c.quality == cqHalfDiminished:
    return true
  if c.quality == cqMinor and
     c.extensionDegree == some(ceSeventh) and
     c.seventhQuality == some(sqDominant):
    for t in c.tensions:
      if t.accidental == taFlat and t.degree == 5:
        return true
  false

proc transposed*(c: ParsedChord, semitones: int, preference: SpellingPreference = spPopJazz): ParsedChord =
  if semitones == 0 or c.root.isNone:
    return c
  result = c
  result.root = some(c.root.get.transposed(semitones, preference))
  if c.bass.isSome:
    result.bass = some(c.bass.get.transposed(semitones, preference))
