import std/[options, unittest]
import note, chord_ast, chord_parser, chord_formatter, score_model

suite "SJScoreCore Nim Port Tests":
  test "1. Basic triads and accidentals":
    let c = parseChord("C")
    check c.isComplete
    check c.root == some(initPitchClass(nlC))
    check c.quality == cqMajor
    check not c.isExplicitMajor

    let fSharpMinor = parseChord("F#m")
    check fSharpMinor.isComplete
    check fSharpMinor.root == some(initPitchClass(nlF, accSharp))
    check fSharpMinor.quality == cqMinor

    let bbDashMinor = parseChord("Bb-")
    check bbDashMinor.isComplete
    check bbDashMinor.root == some(initPitchClass(nlB, accFlat))
    check bbDashMinor.quality == cqMinor

    let power = parseChord("E5")
    check power.isComplete
    check power.quality == cqPower
    check plainText(power) == "E5"

  test "2. Major 7th and Minor-Major 7th":
    for input in ["Cmaj7", "Cmajor7", "C∆7", "CM7"]:
      let parsed = parseChord(input)
      check parsed.isComplete
      check parsed.quality == cqMajor
      check parsed.isExplicitMajor
      check parsed.extensionDegree == some(ceSeventh)
      check parsed.seventhQuality == some(sqMajor)
      check plainText(parsed) == "C∆7"

    let cmaj = parseChord("Cmaj")
    check cmaj.isComplete
    check cmaj.isExplicitMajor
    check cmaj.extensionDegree.isNone
    check plainText(cmaj) == "C∆"

    for input in ["Cm∆7", "Cm(maj7)", "Cminmaj7", "C-∆7"]:
      let parsed = parseChord(input)
      check parsed.isComplete
      check parsed.quality == cqMinorMajor
      check parsed.extensionDegree == some(ceSeventh)
      check parsed.seventhQuality == some(sqMajor)
      check plainText(parsed) == "Cm∆7"

  test "3. Diminished and Half-Diminished":
    for input in ["Dm7b5", "D-7b5", "Dm7(b5)", "Dhdim", "Dhalfdim", "Dø"]:
      let parsed = parseChord(input)
      check parsed.isComplete
      check parsed.isCanonicalHalfDiminished
      let layout = renderLayout(parsed)
      check layout.root == "D"
      check layout.suffix == "ø"
      check layout.suffixStyleHint == sshDiminishedOrHalfDim
      check layout.tensionStack.len == 0

    let bDim7 = parseChord("Bdim7")
    check bDim7.isComplete
    check bDim7.quality == cqDiminished
    check bDim7.extensionDegree == some(ceSeventh)
    check bDim7.seventhQuality == some(sqDiminished)
    check plainText(bDim7) == "Bo7"

  test "4. Suspensions and Additions":
    let c7sus4 = parseChord("C7sus4")
    check c7sus4.isComplete
    check c7sus4.extensionDegree == some(ceSeventh)
    check c7sus4.suspension == some(sus4)
    let layout = renderLayout(c7sus4)
    check layout.suffix == "7sus4"
    check layout.suffixStyleHint == sshSus
    check layout.tensionStack.len == 0

    let cAdd9 = parseChord("Cadd9")
    check cAdd9.isComplete
    check cAdd9.additions == @[ChordAddition(kind: cakAdd, accidental: taNatural, degree: 9)]
    let addLayout = renderLayout(cAdd9)
    check addLayout.suffix == "add9"
    check addLayout.suffixStyleHint == sshAddOrAug

    let cOmit3 = parseChord("Cno3")
    check cOmit3.isComplete
    check cOmit3.additions == @[ChordAddition(kind: cakOmit, accidental: taNatural, degree: 3)]

  test "5. 6/9 vs Slash Bass and Bass Separation":
    let c69 = parseChord("C6/9")
    check c69.isComplete
    check c69.extensionDegree == some(ceSixNine)
    check c69.bass.isNone
    check plainText(c69) == "C6/9"

    let c6OverG = parseChord("C6/G")
    check c6OverG.isComplete
    check c6OverG.extensionDegree == some(ceSixth)
    check c6OverG.bass == some(initPitchClass(nlG))

    let coOverG = parseChord("Co/G")
    let coLayout = renderLayout(coOverG)
    check coLayout.root == "C"
    check coLayout.suffix == "o"
    check coLayout.suffixStyleHint == sshDiminishedOrHalfDim
    check coLayout.bass == "/G"

    let susOverG = parseChord("Csus4/G")
    let susLayout = renderLayout(susOverG)
    check susLayout.suffix == "sus4"
    check susLayout.suffixStyleHint == sshSus
    check susLayout.bass == "/G"

  test "6. Complex Tensions and Altered Chords":
    let g7 = parseChord("G7(b9,#11,b13)")
    check g7.isComplete
    check g7.root == some(initPitchClass(nlG))
    check g7.extensionDegree == some(ceSeventh)
    check g7.tensions.len == 3
    check g7.tensions[0] == Tension(accidental: taFlat, degree: 9, isParenthesized: true)
    check g7.tensions[1] == Tension(accidental: taSharp, degree: 11, isParenthesized: true)
    check g7.tensions[2] == Tension(accidental: taFlat, degree: 13, isParenthesized: true)

    let layout = renderLayout(g7)
    check layout.suffix == "7"
    check layout.tensionStack == @["b9", "#11", "b13"]

    let alt = parseChord("G7alt")
    check alt.isComplete
    check alt.isAltered
    check renderLayout(alt).tensionStack == @["alt"]

  test "7. Fault-Tolerant Live Typing":
    let empty = parseChord("")
    check empty.root.isNone
    check empty.unparsed == ""

    let cma = parseChord("Cma")
    check not cma.isComplete
    check cma.root == some(initPitchClass(nlC))
    check cma.unparsed == "a"
    check plainText(cma) == "Cma"

    let trailingSlash = parseChord("C7/")
    check not trailingSlash.isComplete
    check trailingSlash.bass.isNone
    check trailingSlash.unparsed == "/"
    check plainText(trailingSlash) == "C7/"

    let trailingAdd = parseChord("Cadd")
    check not trailingAdd.isComplete
    check trailingAdd.additions.len == 0
    check trailingAdd.unparsed == "add"
    check plainText(trailingAdd) == "Cadd"

    let unclosedParen = parseChord("C7(b9")
    check unclosedParen.isComplete
    check unclosedParen.tensions == @[Tension(accidental: taFlat, degree: 9, isParenthesized: true)]

    let unknown = parseChord("XYZ")
    check unknown.root.isNone
    check unknown.unparsed == "XYZ"

  test "8. AST Transposition":
    let original = parseChord("Cmaj7/E")
    let upTwo = original.transposed(2)
    check upTwo.root == some(initPitchClass(nlD))
    check upTwo.bass == some(initPitchClass(nlF, accSharp))
    check plainText(upTwo) == "D∆7/F#"

    let back = upTwo.transposed(-2)
    check back.root.get.semitone == original.root.get.semitone
    check back.bass.get.semitone == original.bass.get.semitone

    let c69Up = parseChord("C6/9").transposed(2)
    check plainText(c69Up) == "D6/9"
    check c69Up.bass.isNone

    let cUpOneSharp = parseChord("C").transposed(1, spSharp)
    let cUpOneFlat = parseChord("C").transposed(1, spFlat)
    check cUpOneSharp.root.get.formatted() == "C#"
    check cUpOneFlat.root.get.formatted() == "Db"

  test "9. Web App JSON Compatibility and Layout Calculator":
    let sampleWebJSON = """
    {
      "slots": [
        { "chordName": "Cmaj7" },
        { "chordName": "Am7", "isSyncopated": true },
        { "chordName": "Dm7b5/Ab" },
        { "chordName": "G7(b9,#11)" }
      ],
      "activeIndex": 0,
      "title": "Autumn Leaves"
    }
    """
    let state = decodeScoreJSON(sampleWebJSON)
    check state.title == "Autumn Leaves"
    check state.fontConfig == defaultFontConfig()
    check state.slots.len == 4
    check state.slots[1].isSyncopated == true

    var rendered: seq[string] = @[]
    for slot in state.slots:
      rendered.add(plainText(parseChord(slot.chordName)))
    check rendered == @["C∆7", "Am7", "Dø/Ab", "G7b9#11"]

    let first = slotCoords(0)
    check abs(first.x - 115.0) < 0.001
    check abs(first.y - 250.0) < 0.001

    let secondRowFirst = slotCoords(16)
    check abs(secondRowFirst.x - 115.0) < 0.001
    check abs(secondRowFirst.y - 345.0) < 0.001

    let hit = slotIndexAt(120.0, 240.0, 0, 192)
    check hit == 0
