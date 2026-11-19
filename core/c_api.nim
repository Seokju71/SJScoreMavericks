import std/options
import chord_formatter, score_model, score_engine

proc NimMain() {.importc.}

var gInitialized = false

proc sj_core_init*() {.exportc, cdecl.} =
  if not gInitialized:
    NimMain()
    gInitialized = true

type
  SJLayoutMetrics* {.exportc.} = object
    canvasWidth*: cdouble
    canvasHeight*: cdouble
    marginTop*: cdouble
    marginLeft*: cdouble
    rowGap*: cdouble
    staveHeight*: cdouble
    rows*: cint
    measuresPerRow*: cint
    slotsPerMeasure*: cint
    slotsPerRow*: cint
    slotsPerPage*: cint
    slotWidth*: cdouble
    measureWidth*: cdouble

  SJChordLayoutC* {.exportc.} = object
    hasChord*: cint
    isSyncopated*: cint
    isSelected*: cint
    isActiveCursor*: cint
    root*: cstring
    suffix*: cstring
    suffixStyleHint*: cint
    bass*: cstring
    unparsed*: cstring
    tensionCount*: cint
    tensions*: array[8, cstring]

  SJEngineHandle* = ptr ScoreEngine

proc allocCString(s: string): cstring =
  let buf = cast[ptr UncheckedArray[char]](alloc0(s.len + 1))
  if s.len > 0:
    copyMem(buf, unsafeAddr s[0], s.len)
  cast[cstring](buf)

proc sj_free_string*(s: cstring) {.exportc, cdecl.} =
  if s != nil:
    dealloc(cast[pointer](s))

proc sj_free_chord_layout*(layout: ptr SJChordLayoutC) {.exportc, cdecl.} =
  if layout == nil: return
  sj_free_string(layout.root)
  sj_free_string(layout.suffix)
  sj_free_string(layout.bass)
  sj_free_string(layout.unparsed)
  for i in 0 ..< min(int(layout.tensionCount), 8):
    sj_free_string(layout.tensions[i])
  layout.root = nil
  layout.suffix = nil
  layout.bass = nil
  layout.unparsed = nil
  layout.tensionCount = 0

proc sj_engine_new*(): SJEngineHandle {.exportc, cdecl.} =
  sj_core_init()
  let h = create(ScoreEngine)
  h[] = initScoreEngine()
  h

proc sj_engine_free*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil:
    `=destroy`(h[])
    dealloc(h)

proc sj_engine_get_layout*(h: SJEngineHandle, outMetrics: ptr SJLayoutMetrics) {.exportc, cdecl.} =
  if h == nil or outMetrics == nil: return
  let cfg = h[].layout
  outMetrics.canvasWidth = cfg.canvasWidth
  outMetrics.canvasHeight = cfg.canvasHeight
  outMetrics.marginTop = cfg.marginTop
  outMetrics.marginLeft = cfg.marginLeft
  outMetrics.rowGap = cfg.rowGap
  outMetrics.staveHeight = cfg.staveHeight
  outMetrics.rows = cint(cfg.rows)
  outMetrics.measuresPerRow = cint(cfg.measuresPerRow)
  outMetrics.slotsPerMeasure = cint(cfg.slotsPerMeasure)
  outMetrics.slotsPerRow = cint(cfg.slotsPerRow)
  outMetrics.slotsPerPage = cint(cfg.slotsPerPage)
  outMetrics.slotWidth = cfg.slotWidth
  outMetrics.measureWidth = cfg.measureWidth

proc sj_engine_slot_coords*(h: SJEngineHandle, localIndex: cint, outX: ptr cdouble, outY: ptr cdouble) {.exportc, cdecl.} =
  if h == nil: return
  let c = slotCoords(int(localIndex), h[].layout)
  if outX != nil: outX[] = c.x
  if outY != nil: outY[] = c.y

proc sj_engine_row_y*(h: SJEngineHandle, rowIndex: cint): cdouble {.exportc, cdecl.} =
  if h == nil: return 0.0
  rowY(int(rowIndex), h[].layout)

proc sj_engine_get_title*(h: SJEngineHandle): cstring {.exportc, cdecl.} =
  if h == nil: return allocCString("")
  allocCString(h[].state.title)

proc sj_engine_set_title*(h: SJEngineHandle, title: cstring) {.exportc, cdecl.} =
  if h == nil or title == nil: return
  h[].state.title = $title

proc sj_engine_get_status*(h: SJEngineHandle): cstring {.exportc, cdecl.} =
  if h == nil: return allocCString("")
  allocCString(h[].statusMessage)

proc sj_engine_set_status*(h: SJEngineHandle, msg: cstring) {.exportc, cdecl.} =
  if h == nil or msg == nil: return
  h[].statusMessage = $msg

proc sj_engine_get_view_page*(h: SJEngineHandle): cint {.exportc, cdecl.} =
  if h == nil: return 0
  cint(h[].viewPage)

proc sj_engine_get_total_pages*(h: SJEngineHandle): cint {.exportc, cdecl.} =
  if h == nil: return 1
  cint(h[].totalPages)

proc sj_engine_get_max_pages*(): cint {.exportc, cdecl.} =
  cint(MaxPages)

proc sj_engine_get_effective_pdf_pages*(h: SJEngineHandle): cint {.exportc, cdecl.} =
  if h == nil: return 1
  cint(h[].effectivePdfPageCount)

proc sj_engine_get_slot_count*(h: SJEngineHandle): cint {.exportc, cdecl.} =
  if h == nil: return 0
  cint(h[].state.slots.len)

proc sj_engine_get_zoom*(h: SJEngineHandle): cdouble {.exportc, cdecl.} =
  if h == nil: return 0.65
  h[].zoom

proc sj_engine_zoom_in*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].zoomIn()

proc sj_engine_zoom_out*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].zoomOut()

proc sj_engine_reset_zoom*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].resetZoom()

proc sj_engine_get_transpose*(h: SJEngineHandle): cint {.exportc, cdecl.} =
  if h == nil: return 0
  cint(h[].transpose)

proc sj_engine_set_transpose*(h: SJEngineHandle, value: cint) {.exportc, cdecl.} =
  if h != nil: h[].setTranspose(int(value))

proc sj_engine_is_read_only*(h: SJEngineHandle): cint {.exportc, cdecl.} =
  if h == nil: return 0
  if h[].isReadOnly: 1 else: 0

proc sj_engine_is_editing_title*(h: SJEngineHandle): cint {.exportc, cdecl.} =
  if h == nil: return 0
  if h[].isEditingTitle: 1 else: 0

proc sj_engine_set_editing_title*(h: SJEngineHandle, editing: cint) {.exportc, cdecl.} =
  if h != nil: h[].isEditingTitle = (editing != 0)

proc sj_engine_prev_page*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].prevPage()

proc sj_engine_next_page*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].nextPage()

proc sj_engine_mouse_down*(h: SJEngineHandle, x, y: cdouble): cint {.exportc, cdecl.} =
  if h == nil: return -1
  cint(h[].handleMouseDown(x, y))

proc sj_engine_mouse_drag*(h: SJEngineHandle, anchor: cint, x, y: cdouble) {.exportc, cdecl.} =
  if h != nil: h[].handleMouseDrag(int(anchor), x, y)

proc sj_engine_move_cursor*(h: SJEngineHandle, delta: cint, extendSel: cint) {.exportc, cdecl.} =
  if h != nil: h[].moveCursor(int(delta), extendSel != 0)

proc sj_engine_move_measure*(h: SJEngineHandle, direction: cint, extendSel: cint) {.exportc, cdecl.} =
  if h != nil: h[].moveMeasure(int(direction), extendSel != 0)

proc sj_engine_move_content*(h: SJEngineHandle, delta: cint) {.exportc, cdecl.} =
  if h != nil: h[].moveContent(int(delta))

proc sj_engine_delete_char*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].deleteChar()

proc sj_engine_delete_selection*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].deleteSelection()

proc sj_engine_toggle_syncopation*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].toggleSyncopation()

proc sj_engine_copy_selection*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].copySelection()

proc sj_engine_paste_clipboard*(h: SJEngineHandle) {.exportc, cdecl.} =
  if h != nil: h[].pasteClipboard()

proc sj_engine_append_char*(h: SJEngineHandle, ch: cchar) {.exportc, cdecl.} =
  if h != nil: h[].appendChordChar(char(ch))

proc sj_engine_load_json*(h: SJEngineHandle, jsonStr: cstring, fileName: cstring): cint {.exportc, cdecl.} =
  if h == nil or jsonStr == nil: return 0
  let fname = if fileName != nil: $fileName else: "score.json"
  if h[].loadJSON($jsonStr, fname): 1 else: 0

proc sj_engine_save_json*(h: SJEngineHandle, fileName: cstring): cstring {.exportc, cdecl.} =
  if h == nil: return allocCString("{}")
  let fname = if fileName != nil: $fileName else: "score.json"
  allocCString(h[].saveJSON(fname))

proc sj_engine_get_slot_render*(
  h: SJEngineHandle,
  globalIndex: cint,
  transposeOverride: cint,
  outLayout: ptr SJChordLayoutC
) {.exportc, cdecl.} =
  if h == nil or outLayout == nil: return
  zeroMem(outLayout, sizeof(SJChordLayoutC))

  let idx = int(globalIndex)
  if idx < 0 or idx >= h[].state.slots.len:
    return

  if h[].state.selection.isSome:
    let r = h[].state.selection.get.normalizedRange
    if idx >= r.lo and idx <= r.hi:
      outLayout.isSelected = 1

  if idx == h[].state.activeIndex:
    outLayout.isActiveCursor = 1

  let slot = h[].state.slots[idx]
  if slot.chordName.len == 0:
    return

  outLayout.hasChord = 1
  outLayout.isSyncopated = if slot.isSyncopated: 1 else: 0

  let layout = h[].renderChordForSlot(idx, int(transposeOverride))
  outLayout.root = allocCString(layout.root)
  outLayout.suffix = allocCString(layout.suffix)
  outLayout.suffixStyleHint = cint(ord(layout.suffixStyleHint))
  outLayout.bass = allocCString(layout.bass)
  outLayout.unparsed = allocCString(layout.unparsed)

  let tCount = min(layout.tensionStack.len, 8)
  outLayout.tensionCount = cint(tCount)
  for i in 0 ..< tCount:
    outLayout.tensions[i] = allocCString(layout.tensionStack[i])
