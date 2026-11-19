import std/[algorithm, options, strutils]
import note, chord_ast

type
  ChordDisplayStyle* = object
    useTriangleForMajor*: bool
    useHalfDimSymbol*: bool
    useDimCircle*: bool
    minorSymbol*: string
    useUnicodeAccidentals*: bool

  SuffixStyleHint* = enum
    sshNormal = 0
    sshDiminishedOrHalfDim = 1
    sshSus = 2
    sshAddOrAug = 3

  ChordRenderLayout* = object
    root*: string
    suffix*: string
    suffixStyleHint*: SuffixStyleHint
    tensionStack*: seq[string]
    bass*: string      # empty if none, otherwise "/G", "/F#", etc.
    unparsed*: string

proc defaultDisplayStyle*(): ChordDisplayStyle =
  ChordDisplayStyle(
    useTriangleForMajor: true,
    useHalfDimSymbol: true,
    useDimCircle: true,
    minorSymbol: "m",
    useUnicodeAccidentals: false
  )

proc renderLayout*(chord: ParsedChord, style: ChordDisplayStyle = defaultDisplayStyle()): ChordRenderLayout =
  if chord.root.isNone:
    return ChordRenderLayout(root: chord.unparsed, suffixStyleHint: sshNormal)

  let rootText = chord.root.get.formatted(style.useUnicodeAccidentals)
  let bassText =
    if chord.bass.isSome: "/" & chord.bass.get.formatted(style.useUnicodeAccidentals)
    else: ""

  var suffixParts: seq[string] = @[]
  var styleHint = sshNormal
  var remainingTensions = chord.tensions

  # 1. Canonical half-diminished
  if style.useHalfDimSymbol and chord.isCanonicalHalfDiminished:
    suffixParts.add("ø")
    styleHint = sshDiminishedOrHalfDim
    for i in 0 ..< remainingTensions.len:
      if remainingTensions[i].accidental == taFlat and remainingTensions[i].degree == 5:
        remainingTensions.delete(i)
        break
  else:
    # 2. Quality
    case chord.quality
    of cqMajor:
      if chord.isExplicitMajor:
        suffixParts.add(if style.useTriangleForMajor: "∆" else: "maj")
    of cqMinor:
      suffixParts.add(style.minorSymbol)
    of cqMinorMajor:
      suffixParts.add(style.minorSymbol & (if style.useTriangleForMajor: "∆" else: "maj"))
    of cqDiminished:
      suffixParts.add(if style.useDimCircle: "o" else: "dim")
      styleHint = sshDiminishedOrHalfDim
    of cqHalfDiminished:
      suffixParts.add("ø")
      styleHint = sshDiminishedOrHalfDim
    of cqAugmented:
      suffixParts.add("aug")
      styleHint = sshAddOrAug
    of cqPower:
      suffixParts.add("5")

    # 3. Primary extension degree
    if chord.extensionDegree.isSome:
      case chord.extensionDegree.get
      of ceSixth: suffixParts.add("6")
      of ceSeventh: suffixParts.add("7")
      of ceNinth: suffixParts.add("9")
      of ceEleventh: suffixParts.add("11")
      of ceThirteenth: suffixParts.add("13")
      of ceSixNine: suffixParts.add("6/9")

  # 4. Suspension
  if chord.suspension.isSome:
    suffixParts.add($chord.suspension.get)
    if styleHint == sshNormal:
      styleHint = sshSus

  # 5. Additions / omissions
  if chord.additions.len > 0:
    for addition in chord.additions:
      suffixParts.add(addition.formatted(style.useUnicodeAccidentals))
    if styleHint == sshNormal:
      styleHint = sshAddOrAug

  # 6. Tensions & altered stacking (sorted ascending by degree: bottom-to-top)
  remainingTensions.sort(proc (a, b: Tension): int = cmp(a.degree, b.degree))
  var tensionStack: seq[string] = @[]
  for t in remainingTensions:
    tensionStack.add(t.formatted(style.useUnicodeAccidentals, includeParentheses = false))
  if chord.isAltered:
    tensionStack.add("alt")

  ChordRenderLayout(
    root: rootText,
    suffix: suffixParts.join(""),
    suffixStyleHint: styleHint,
    tensionStack: tensionStack,
    bass: bassText,
    unparsed: chord.unparsed
  )

proc plainText*(chord: ParsedChord, style: ChordDisplayStyle = defaultDisplayStyle()): string =
  let layout = renderLayout(chord, style)
  result = layout.root & layout.suffix
  if layout.tensionStack.len > 0:
    result &= layout.tensionStack.join("")
  if layout.bass.len > 0:
    result &= layout.bass
  if layout.unparsed.len > 0:
    result &= layout.unparsed
