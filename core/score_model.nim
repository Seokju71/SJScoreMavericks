import std/[json, math, options]

const SlotsPerPage* = 192 # 12 rows * 4 measures * 4 slots

type
  ChordSlot* = object
    chordName*: string
    isSyncopated*: bool

  FontConfig* = object
    chordFont*: string
    symbolFont*: string

  ScoreSelection* = object
    startIdx*: int
    endIdx*: int

  ScoreState* = object
    slots*: seq[ChordSlot]
    activeIndex*: int
    title*: string
    fontConfig*: FontConfig
    selection*: Option[ScoreSelection]
    clipboard*: seq[ChordSlot]

  LayoutConfig* = object
    canvasWidth*: float64
    canvasHeight*: float64
    marginTop*: float64
    marginLeft*: float64
    rowGap*: float64
    staveHeight*: float64
    rows*: int
    measuresPerRow*: int
    slotsPerMeasure*: int

  SlotCoordinate* = object
    x*: float64
    y*: float64

proc defaultFontConfig*(): FontConfig =
  FontConfig(chordFont: "PetalumaScript", symbolFont: "Petaluma")

proc defaultLayoutConfig*(): LayoutConfig =
  LayoutConfig(
    canvasWidth: 1080.0,
    canvasHeight: 1525.0,
    marginTop: 250.0,
    marginLeft: 115.0,
    rowGap: 95.0,
    staveHeight: 40.0,
    rows: 12,
    measuresPerRow: 4,
    slotsPerMeasure: 4
  )

proc initScoreState*(): ScoreState =
  var slots = newSeq[ChordSlot](SlotsPerPage)
  ScoreState(
    slots: slots,
    activeIndex: 0,
    title: "Untitled Score",
    fontConfig: defaultFontConfig(),
    selection: none(ScoreSelection),
    clipboard: @[]
  )

proc normalizedRange*(sel: ScoreSelection): tuple[lo: int, hi: int] {.inline.} =
  (min(sel.startIdx, sel.endIdx), max(sel.startIdx, sel.endIdx))

proc slotsPerRow*(cfg: LayoutConfig): int {.inline.} =
  cfg.measuresPerRow * cfg.slotsPerMeasure

proc slotsPerPage*(cfg: LayoutConfig): int {.inline.} =
  cfg.rows * cfg.slotsPerRow

proc contentWidth*(cfg: LayoutConfig): float64 {.inline.} =
  cfg.canvasWidth - (cfg.marginLeft * 2.0)

proc slotWidth*(cfg: LayoutConfig): float64 {.inline.} =
  cfg.contentWidth / float64(cfg.slotsPerRow)

proc measureWidth*(cfg: LayoutConfig): float64 {.inline.} =
  cfg.contentWidth / float64(cfg.measuresPerRow)

proc rowY*(rowIndex: int, cfg: LayoutConfig = defaultLayoutConfig()): float64 {.inline.} =
  cfg.marginTop + (float64(rowIndex) * cfg.rowGap)

proc slotCoords*(localIndex: int, cfg: LayoutConfig = defaultLayoutConfig()): SlotCoordinate =
  let clamped = max(0, min(cfg.slotsPerPage - 1, localIndex))
  let rowIndex = clamped div cfg.slotsPerRow
  let colIndex = clamped mod cfg.slotsPerRow
  SlotCoordinate(
    x: cfg.marginLeft + (float64(colIndex) * cfg.slotWidth),
    y: cfg.marginTop + (float64(rowIndex) * cfg.rowGap)
  )

proc slotIndexAt*(
  x, y: float64,
  pageIndex: int,
  totalSlots: int,
  cfg: LayoutConfig = defaultLayoutConfig()
): int =
  ## Returns global slot index, or -1 if out of bounds.
  var matchedRow = -1
  for r in 0 ..< cfg.rows:
    let rY = rowY(r, cfg)
    if y >= rY - 100.0 and y <= rY + 50.0:
      matchedRow = r
      break
  if matchedRow < 0:
    return -1

  let relativeX = x - cfg.marginLeft
  if relativeX < 0.0 or relativeX > cfg.contentWidth:
    return -1

  let col = min(cfg.slotsPerRow - 1, int(floor(relativeX / cfg.slotWidth)))
  let idx = (pageIndex * cfg.slotsPerPage) + (matchedRow * cfg.slotsPerRow) + col
  if idx < 0 or idx >= totalSlots:
    return -1
  idx

proc decodeScoreJSON*(jsonText: string): ScoreState =
  let root = parseJson(jsonText)
  if root.kind != JObject:
    raise newException(ValueError, "Root JSON must be an object")

  var state = ScoreState(
    slots: @[],
    activeIndex: 0,
    title: "Untitled Score",
    fontConfig: defaultFontConfig(),
    selection: none(ScoreSelection),
    clipboard: @[]
  )

  if root.hasKey("title") and root["title"].kind == JString:
    state.title = root["title"].getStr()

  if root.hasKey("activeIndex") and root["activeIndex"].kind == JInt:
    state.activeIndex = root["activeIndex"].getInt()

  if root.hasKey("fontConfig") and root["fontConfig"].kind == JObject:
    let fc = root["fontConfig"]
    if fc.hasKey("chordFont") and fc["chordFont"].kind == JString:
      state.fontConfig.chordFont = fc["chordFont"].getStr()
    if fc.hasKey("symbolFont") and fc["symbolFont"].kind == JString:
      state.fontConfig.symbolFont = fc["symbolFont"].getStr()

  if root.hasKey("slots") and root["slots"].kind == JArray:
    for item in root["slots"]:
      if item.kind == JObject:
        let cname = if item.hasKey("chordName") and item["chordName"].kind == JString:
          item["chordName"].getStr()
        else:
          ""
        let sync = if item.hasKey("isSyncopated") and item["isSyncopated"].kind == JBool:
          item["isSyncopated"].getBool()
        else:
          false
        state.slots.add(ChordSlot(chordName: cname, isSyncopated: sync))

  if state.slots.len == 0:
    state.slots = newSeq[ChordSlot](SlotsPerPage)

  if state.activeIndex < 0 or state.activeIndex >= state.slots.len:
    state.activeIndex = 0

  state

proc encodePrettyScoreJSON*(state: ScoreState): string =
  var slotsArr = newJArray()
  for slot in state.slots:
    var obj = newJObject()
    obj["chordName"] = %slot.chordName
    if slot.isSyncopated:
      obj["isSyncopated"] = %true
    slotsArr.add(obj)

  var fcObj = newJObject()
  fcObj["chordFont"] = %state.fontConfig.chordFont
  fcObj["symbolFont"] = %state.fontConfig.symbolFont

  var root = newJObject()
  root["activeIndex"] = %state.activeIndex
  root["fontConfig"] = fcObj
  root["slots"] = slotsArr
  root["title"] = %state.title
  pretty(root, indent = 2)
