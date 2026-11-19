import std/[math, options, strutils]
import note, chord_ast, chord_parser, chord_formatter, score_model

const MaxPages* = 3

type
  ScoreEngine* = object
    state*: ScoreState
    layout*: LayoutConfig
    viewPage*: int
    zoom*: float64
    transpose*: int
    isEditingTitle*: bool
    statusMessage*: string

proc initScoreEngine*(): ScoreEngine =
  ScoreEngine(
    state: initScoreState(),
    layout: defaultLayoutConfig(),
    viewPage: 0,
    zoom: 0.65,
    transpose: 0,
    isEditingTitle: false,
    statusMessage: ""
  )

proc isReadOnly*(e: ScoreEngine): bool {.inline.} =
  e.transpose != 0

proc totalPages*(e: ScoreEngine): int =
  max(1, int(ceil(float64(e.state.slots.len) / float64(e.layout.slotsPerPage))))

proc effectivePdfPageCount*(e: ScoreEngine): int =
  var lastNonEmpty = -1
  for idx, slot in e.state.slots:
    if slot.chordName.strip().len > 0:
      lastNonEmpty = idx
  if lastNonEmpty == -1: 1
  else: (lastNonEmpty div e.layout.slotsPerPage) + 1

proc setTranspose*(e: var ScoreEngine, value: int) =
  e.transpose = max(-11, min(11, value))

proc zoomIn*(e: var ScoreEngine) =
  e.zoom = min(2.0, e.zoom + 0.1)

proc zoomOut*(e: var ScoreEngine) =
  e.zoom = max(0.2, e.zoom - 0.1)

proc resetZoom*(e: var ScoreEngine) =
  e.zoom = 0.65

proc prevPage*(e: var ScoreEngine) =
  if e.viewPage > 0:
    dec e.viewPage
    e.state.activeIndex = e.viewPage * e.layout.slotsPerPage

proc nextPage*(e: var ScoreEngine) =
  let nextP = e.viewPage + 1
  if e.viewPage < e.totalPages - 1:
    e.state.activeIndex = nextP * e.layout.slotsPerPage
    e.viewPage = nextP
  elif e.totalPages < MaxPages:
    for _ in 0 ..< e.layout.slotsPerPage:
      e.state.slots.add(ChordSlot())
    e.state.activeIndex = nextP * e.layout.slotsPerPage
    e.viewPage = nextP

proc syncPageToCursor(e: var ScoreEngine) =
  let cursorPage = e.state.activeIndex div e.layout.slotsPerPage
  if cursorPage != e.viewPage and cursorPage < e.totalPages:
    e.viewPage = cursorPage

proc updateCursorAndSelection(e: var ScoreEngine, nextIndex: int, extendSelection: bool) =
  if extendSelection:
    var anchor = e.state.activeIndex
    if e.state.selection.isSome:
      let sel = e.state.selection.get
      if e.state.activeIndex == sel.startIdx:
        anchor = sel.endIdx
      elif e.state.activeIndex == sel.endIdx:
        anchor = sel.startIdx
    e.state.selection = some(ScoreSelection(startIdx: min(anchor, nextIndex), endIdx: max(anchor, nextIndex)))
  else:
    e.state.selection = some(ScoreSelection(startIdx: nextIndex, endIdx: nextIndex))
  e.state.activeIndex = nextIndex
  e.syncPageToCursor()

proc handleMouseDown*(e: var ScoreEngine, x, y: float64): int =
  ## Returns anchor slot index (>= 0) or -1 if none.
  if e.isReadOnly:
    return -1

  let centerX = e.layout.canvasWidth / 2.0
  if e.viewPage == 0 and y >= 100.0 and y <= 180.0 and abs(x - centerX) < 300.0:
    e.isEditingTitle = true
    return -1

  e.isEditingTitle = false
  let idx = slotIndexAt(x, y, e.viewPage, e.state.slots.len, e.layout)
  if idx >= 0:
    e.state.activeIndex = idx
    e.state.selection = some(ScoreSelection(startIdx: idx, endIdx: idx))
    return idx
  else:
    e.state.selection = none(ScoreSelection)
    return -1

proc handleMouseDrag*(e: var ScoreEngine, anchor: int, x, y: float64) =
  if e.isReadOnly or anchor < 0:
    return
  let idx = slotIndexAt(x, y, e.viewPage, e.state.slots.len, e.layout)
  if idx < 0:
    return
  if e.state.selection.isNone or e.state.selection.get.endIdx != idx:
    e.state.selection = some(ScoreSelection(startIdx: anchor, endIdx: idx))

proc moveCursor*(e: var ScoreEngine, delta: int, extendSelection: bool) =
  if e.isReadOnly:
    if delta < 0: e.prevPage()
    elif delta > 0: e.nextPage()
    return
  let maxIdx = e.state.slots.len - 1
  let nextIdx = max(0, min(maxIdx, e.state.activeIndex + delta))
  e.updateCursorAndSelection(nextIdx, extendSelection)

proc moveMeasure*(e: var ScoreEngine, direction: int, extendSelection: bool) =
  if e.isReadOnly:
    return
  let maxIdx = e.state.slots.len - 1
  let currentMeasure = e.state.activeIndex div e.layout.slotsPerMeasure
  let target = (currentMeasure + direction) * e.layout.slotsPerMeasure
  let nextIdx = max(0, min(maxIdx, target))
  e.updateCursorAndSelection(nextIdx, extendSelection)

proc moveContent*(e: var ScoreEngine, delta: int) =
  if e.isReadOnly:
    return
  let targetIdx = e.state.activeIndex + delta
  if targetIdx < 0 or targetIdx >= e.state.slots.len:
    return
  e.state.slots[targetIdx] = e.state.slots[e.state.activeIndex]
  e.state.slots[e.state.activeIndex] = ChordSlot()
  e.state.activeIndex = targetIdx
  e.state.selection = some(ScoreSelection(startIdx: targetIdx, endIdx: targetIdx))
  e.syncPageToCursor()

proc deleteChar*(e: var ScoreEngine) =
  if e.isReadOnly or e.state.activeIndex >= e.state.slots.len:
    return
  if e.state.slots[e.state.activeIndex].chordName.len > 0:
    let s = e.state.slots[e.state.activeIndex].chordName
    e.state.slots[e.state.activeIndex].chordName = s[0 ..< s.len - 1]
  else:
    e.state.activeIndex = max(0, e.state.activeIndex - 1)
    e.state.selection = some(ScoreSelection(startIdx: e.state.activeIndex, endIdx: e.state.activeIndex))
    e.syncPageToCursor()

proc deleteSelection*(e: var ScoreEngine) =
  if e.isReadOnly or e.state.selection.isNone:
    return
  let r = e.state.selection.get.normalizedRange
  for i in r.lo .. min(r.hi, e.state.slots.len - 1):
    e.state.slots[i].chordName = ""

proc toggleSyncopation*(e: var ScoreEngine) =
  if e.isReadOnly or e.state.activeIndex >= e.state.slots.len:
    return
  e.state.slots[e.state.activeIndex].isSyncopated = not e.state.slots[e.state.activeIndex].isSyncopated

proc copySelection*(e: var ScoreEngine) =
  if e.state.selection.isNone:
    return
  let r = e.state.selection.get.normalizedRange
  let upper = min(r.hi, e.state.slots.len - 1)
  if r.lo > upper:
    return
  e.state.clipboard = e.state.slots[r.lo .. upper]

proc pasteClipboard*(e: var ScoreEngine) =
  if e.isReadOnly or e.state.clipboard.len == 0:
    return
  let startIdx = e.state.activeIndex
  var targetIdx = startIdx
  for slot in e.state.clipboard:
    if targetIdx >= e.state.slots.len:
      break
    e.state.slots[targetIdx] = slot
    inc targetIdx
  e.state.selection = some(ScoreSelection(startIdx: startIdx, endIdx: max(startIdx, targetIdx - 1)))
  e.state.activeIndex = min(e.state.slots.len - 1, targetIdx)
  e.syncPageToCursor()

proc appendChordChar*(e: var ScoreEngine, ch: char) =
  if e.isReadOnly or e.state.activeIndex >= e.state.slots.len:
    return
  if e.state.slots[e.state.activeIndex].chordName.len == 0:
    let upper = toUpperAscii(ch)
    if not parseNoteLetter(upper).ok:
      return
    e.state.slots[e.state.activeIndex].chordName.add(upper)
  else:
    e.state.slots[e.state.activeIndex].chordName.add(ch)
  e.state.selection = some(ScoreSelection(startIdx: e.state.activeIndex, endIdx: e.state.activeIndex))

proc loadJSON*(e: var ScoreEngine, jsonText: string, fileName: string): bool =
  try:
    e.state = decodeScoreJSON(jsonText)
    e.viewPage = 0
    e.transpose = 0
    e.statusMessage = "Loaded " & fileName
    true
  except CatchableError as err:
    e.statusMessage = "Failed to load JSON: " & err.msg
    false

proc saveJSON*(e: var ScoreEngine, fileName: string): string =
  e.statusMessage = "Saved " & fileName
  encodePrettyScoreJSON(e.state)

proc renderChordForSlot*(e: ScoreEngine, globalIndex: int, transposeOverride: int): ChordRenderLayout =
  if globalIndex < 0 or globalIndex >= e.state.slots.len:
    return ChordRenderLayout()
  let raw = e.state.slots[globalIndex].chordName
  if raw.len == 0:
    return ChordRenderLayout()
  let parsed = parseChord(raw)
  let transposed = if transposeOverride != 0: parsed.transposed(transposeOverride) else: parsed
  renderLayout(transposed)
