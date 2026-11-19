type
  NoteLetter* = enum
    nlC = "C"
    nlD = "D"
    nlE = "E"
    nlF = "F"
    nlG = "G"
    nlA = "A"
    nlB = "B"

  Accidental* = enum
    accNatural = ""
    accSharp = "#"
    accFlat = "b"
    accDoubleSharp = "##"
    accDoubleFlat = "bb"

  SpellingPreference* = enum
    spPopJazz
    spSharp
    spFlat

  PitchClass* = object
    letter*: NoteLetter
    accidental*: Accidental

proc baseSemitone*(letter: NoteLetter): int =
  case letter
  of nlC: 0
  of nlD: 2
  of nlE: 4
  of nlF: 5
  of nlG: 7
  of nlA: 9
  of nlB: 11

proc parseNoteLetter*(ch: char): tuple[ok: bool, letter: NoteLetter] =
  case ch
  of 'C': (true, nlC)
  of 'D': (true, nlD)
  of 'E': (true, nlE)
  of 'F': (true, nlF)
  of 'G': (true, nlG)
  of 'A': (true, nlA)
  of 'B': (true, nlB)
  else: (false, nlC)

proc semitoneOffset*(acc: Accidental): int =
  case acc
  of accNatural: 0
  of accSharp: 1
  of accFlat: -1
  of accDoubleSharp: 2
  of accDoubleFlat: -2

proc symbol*(acc: Accidental, useUnicode: bool = false): string =
  if not useUnicode:
    return $acc
  case acc
  of accNatural: ""
  of accSharp: "♯"
  of accFlat: "♭"
  of accDoubleSharp: "𝄪"
  of accDoubleFlat: "𝄫"

proc initPitchClass*(letter: NoteLetter, accidental: Accidental = accNatural): PitchClass =
  PitchClass(letter: letter, accidental: accidental)

proc semitone*(pc: PitchClass): int =
  let raw = (pc.letter.baseSemitone + pc.accidental.semitoneOffset) mod 12
  if raw < 0: raw + 12 else: raw

const PopJazzScale: array[12, PitchClass] = [
  PitchClass(letter: nlC, accidental: accNatural),
  PitchClass(letter: nlD, accidental: accFlat),
  PitchClass(letter: nlD, accidental: accNatural),
  PitchClass(letter: nlE, accidental: accFlat),
  PitchClass(letter: nlE, accidental: accNatural),
  PitchClass(letter: nlF, accidental: accNatural),
  PitchClass(letter: nlF, accidental: accSharp),
  PitchClass(letter: nlG, accidental: accNatural),
  PitchClass(letter: nlA, accidental: accFlat),
  PitchClass(letter: nlA, accidental: accNatural),
  PitchClass(letter: nlB, accidental: accFlat),
  PitchClass(letter: nlB, accidental: accNatural),
]

const SharpScale: array[12, PitchClass] = [
  PitchClass(letter: nlC, accidental: accNatural),
  PitchClass(letter: nlC, accidental: accSharp),
  PitchClass(letter: nlD, accidental: accNatural),
  PitchClass(letter: nlD, accidental: accSharp),
  PitchClass(letter: nlE, accidental: accNatural),
  PitchClass(letter: nlF, accidental: accNatural),
  PitchClass(letter: nlF, accidental: accSharp),
  PitchClass(letter: nlG, accidental: accNatural),
  PitchClass(letter: nlG, accidental: accSharp),
  PitchClass(letter: nlA, accidental: accNatural),
  PitchClass(letter: nlA, accidental: accSharp),
  PitchClass(letter: nlB, accidental: accNatural),
]

const FlatScale: array[12, PitchClass] = [
  PitchClass(letter: nlC, accidental: accNatural),
  PitchClass(letter: nlD, accidental: accFlat),
  PitchClass(letter: nlD, accidental: accNatural),
  PitchClass(letter: nlE, accidental: accFlat),
  PitchClass(letter: nlE, accidental: accNatural),
  PitchClass(letter: nlF, accidental: accNatural),
  PitchClass(letter: nlG, accidental: accFlat),
  PitchClass(letter: nlG, accidental: accNatural),
  PitchClass(letter: nlA, accidental: accFlat),
  PitchClass(letter: nlA, accidental: accNatural),
  PitchClass(letter: nlB, accidental: accFlat),
  PitchClass(letter: nlB, accidental: accNatural),
]

proc pitchClassFromSemitone*(semitone: int, preference: SpellingPreference = spPopJazz): PitchClass =
  let idx = ((semitone mod 12) + 12) mod 12
  case preference
  of spPopJazz: PopJazzScale[idx]
  of spSharp: SharpScale[idx]
  of spFlat: FlatScale[idx]

proc transposed*(pc: PitchClass, semitones: int, preference: SpellingPreference = spPopJazz): PitchClass =
  if semitones == 0:
    return pc
  let shifted = (pc.semitone + semitones) mod 12
  let normalized = if shifted < 0: shifted + 12 else: shifted
  pitchClassFromSemitone(normalized, preference)

proc formatted*(pc: PitchClass, useUnicodeAccidental: bool = false): string =
  $pc.letter & pc.accidental.symbol(useUnicodeAccidental)
