-- ============================================================
--  設計書様式用 Quarto/Pandoc フィルタ（typst 出力用）
--  執筆者が qmd で使える記法を lib.typ の様式機能に対応付ける:
--   1) ```mermaid フェンス → mermaid-cli で SVG 化して画像に置換
--      （diagrams/ に内容ハッシュでキャッシュ。ブラウザは EXECUTABLE_BROWSER）
--   2) ::: {.landscape} div → #landscape[...]（横向きページ）
--   3) ::: {.ipo} div → #ipo(...)（IPO図。最初の見出し = 機能名 / 処理名、
--      入力/処理/出力（Input/Process/Output 可）の見出しで3列に分割）
--   4) ::: {.merge-rows} div → 中の表で縦に連続する同じ値のセルを rowspan 結合
--   5) すべての表の列幅を本文幅いっぱいに正規化（内容量に比例して配分）
-- ============================================================

-- book プロジェクトでは、フィルタ実行時の CWD が「いま処理している章ファイルの
-- ディレクトリ」になる（章の階層ごとに変わる）。したがって相対パスは使えない。
-- ビルドスクリプトが DOC_ROOT にプロジェクトルートの絶対パスを渡す。
local ROOT = (os.getenv('DOC_ROOT') or '.'):gsub('\\', '/'):gsub('/$', '')
local MMDC = ROOT .. '/node_modules/@mermaid-js/mermaid-cli/src/cli.js'
local MMDC_CONF = ROOT .. '/mermaid-config.json'
local DIAG = ROOT .. '/diagrams'

-- SVG の実体は DIAG（絶対パス）に置くが、AST に載せるパスは章ファイルからの
-- 相対でなければ Quarto が解決できない。CWD の深さぶん ../ を積む。
local function diag_rel()
  local cwd = (pandoc.system.get_working_directory() or ''):gsub('\\', '/')
  if cwd:sub(1, #ROOT) ~= ROOT then return 'diagrams' end
  local up = ''
  for _ in cwd:sub(#ROOT + 1):gsub('^/', ''):gmatch('[^/]+') do up = up .. '../' end
  return up .. 'diagrams'
end

local function file_exists(p)
  local f = io.open(p, 'r')
  if f then f:close(); return true end
  return false
end

local function render_mermaid(code)
  local hash = pandoc.utils.sha1(code):sub(1, 8)
  local svg = DIAG .. '/mmd-' .. hash .. '.svg'
  local rel = diag_rel() .. '/mmd-' .. hash .. '.svg'
  if file_exists(svg) then return rel end
  pandoc.system.make_directory(DIAG, true)
  local mmd = DIAG .. '/mmd-' .. hash .. '.mmd'
  local f = assert(io.open(mmd, 'w')); f:write(code); f:close()
  -- puppeteer 設定（既存 Edge/Chromium の流用）
  local pp = DIAG .. '/puppeteer.json'
  local browser = os.getenv('EXECUTABLE_BROWSER') or ''
  local pf = assert(io.open(pp, 'w'))
  if browser ~= '' then
    pf:write('{"executablePath": "' .. browser:gsub('\\', '/') .. '"}')
  else
    pf:write('{}')
  end
  pf:close()
  os.execute('node "' .. MMDC .. '" -i "' .. mmd .. '" -o "' .. svg ..
    '" -b transparent -c "' .. MMDC_CONF .. '" -p "' .. pp .. '"')
  if not file_exists(svg) then
    error('mermaid の変換に失敗しました: ' .. mmd)
  end
  return rel
end

function CodeBlock(el)
  if el.classes:includes('mermaid') then
    local svg = render_mermaid(el.text)
    local img = pandoc.Image({}, svg, '', pandoc.Attr('', {}, { { 'width', '90%' } }))
    return pandoc.Para({ img })
  end
end

-- ============================================================
--  {.merge-rows}: 縦に連続する同じ値のセルを rowspan で結合する。
--
--  結合するのは「その列が上の行と同じ値」かつ「左側の列がすべて結合済み」の
--  ときだけ。大分類→中分類→小分類の階層に一致し、「必須」列の ○ が偶然
--  続いただけ、のような意図しない結合を防ぐ。
--
--  キャプション行の属性（: cap {#tbl-x .merge-rows}）は Quarto 本体が先に
--  消費してしまい pre-quarto フィルタでも Table に届かないため、
--  .landscape / .ipo と同じく div で囲む方式にしている。
-- ============================================================

-- 既に結合のある表・行ごとに列数が違う表は触らない（安全側に倒す）
local function is_plain_grid(rows, ncol)
  for _, row in ipairs(rows) do
    if #row.cells ~= ncol then return false end
    for _, c in ipairs(row.cells) do
      if c.row_span ~= 1 or c.col_span ~= 1 then return false end
    end
  end
  return true
end

local function merge_body(rows)
  local n = #rows
  if n == 0 then return end
  local ncol = #rows[1].cells
  if not is_plain_grid(rows, ncol) then return end

  -- セル内容を文字列化（書式の違いは無視し、見た目のテキストで判定する）
  local txt = {}
  for i = 1, n do
    txt[i] = {}
    for c = 1, ncol do
      txt[i][c] = pandoc.utils.stringify(pandoc.Div(rows[i].cells[c].contents))
    end
  end

  -- merged[i][c] = 行 i の列 c を上の行に吸収するか
  local merged = {}
  for i = 1, n do
    merged[i] = {}
    for c = 1, ncol do
      merged[i][c] = i > 1
        and txt[i][c] ~= ''            -- 空セルは結合しない
        and txt[i][c] == txt[i - 1][c]
        and (c == 1 or merged[i][c - 1])
    end
  end

  -- 行を組み直す（吸収された位置のセルは取り除く必要がある）
  for i = 1, n do
    local cells = {}
    for c = 1, ncol do
      if not merged[i][c] then
        local span, k = 1, i + 1
        while k <= n and merged[k][c] do span = span + 1; k = k + 1 end
        local cell = rows[i].cells[c]
        cell.row_span = span
        cells[#cells + 1] = cell
      end
    end
    rows[i].cells = pandoc.List(cells)
  end
end

local COLKEY = {
  ['入力'] = 'input', ['input'] = 'input',
  ['処理'] = 'process', ['process'] = 'process',
  ['出力'] = 'output', ['output'] = 'output',
}

-- HTML 出力では typst の生ブロックは捨てられてしまうため、
-- .landscape / .ipo は div 構造として組み立てる（執筆者の記法は変えない）。
local IS_HTML = FORMAT == 'html'

local function html_div(cls, blocks)
  return pandoc.Div(blocks, pandoc.Attr('', { cls }))
end

local function html_cell(cls, text)
  return html_div(cls, { pandoc.Plain({ pandoc.Str(text) }) })
end

function Div(el)
  if el.classes:includes('merge-rows') then
    -- div 自体は残さない（block が挟まると図表の中央寄せが崩れるため）
    return pandoc.walk_block(el, { Table = function(t)
      for _, b in ipairs(t.bodies) do merge_body(b.body) end
      return t
    end }).content
  end

  if el.classes:includes('landscape') then
    -- HTML は紙面が無いので横向きにする意味がない。div のまま残し、
    -- 幅広の表は CSS 側で横スクロールさせる。
    if IS_HTML then return el end
    local out = pandoc.Blocks({ pandoc.RawBlock('typst', '#landscape[') })
    out:extend(el.content)
    out:insert(pandoc.RawBlock('typst', ']'))
    return out
  end

  if el.classes:includes('ipo') then
    local func, proc = '', ''
    local titleSeen = false
    local cols = {
      input = pandoc.Blocks({}),
      process = pandoc.Blocks({}),
      output = pandoc.Blocks({}),
    }
    local cur = nil
    for _, b in ipairs(el.content) do
      if b.t == 'Header' then
        local txt = pandoc.utils.stringify(b.content):gsub('／', '/')
        local key = COLKEY[txt:lower()]
        if key then
          cur = key
        elseif not titleSeen then
          func = txt:match('^(.-)%s*/') or txt
          proc = txt:match('/%s*(.*)$') or ''
          titleSeen = true
        end
      elseif cur then
        cols[cur]:insert(b)
      end
    end
    -- HTML: 紙面の定型枠を div 構造で組み立てる（CSS 側で3列に配置）
    if IS_HTML then
      return pandoc.Div({
        pandoc.Div({
          html_cell('ipo-title-label', '機能名'),
          html_cell('ipo-title-value', func),
          html_cell('ipo-title-label', '処理名'),
          html_cell('ipo-title-value', proc),
        }, pandoc.Attr('', { 'ipo-title' })),
        pandoc.Div({
          html_cell('ipo-head', '入力'),
          html_cell('ipo-head', '処理'),
          html_cell('ipo-head', '出力'),
          html_div('ipo-col', cols.input),
          html_div('ipo-col', cols.process),
          html_div('ipo-col', cols.output),
        }, pandoc.Attr('', { 'ipo-frame' })),
      }, pandoc.Attr('', { 'ipo' }))
    end

    -- 列の中身が図1枚だけなら欄いっぱいに収める（Typst のみ）
    for k, blocks in pairs(cols) do
      if #blocks == 1 and blocks[1].t == 'Para' and #blocks[1].content == 1
          and blocks[1].content[1].t == 'Image' then
        cols[k] = pandoc.Blocks({ pandoc.RawBlock('typst',
          '#align(center, image("' .. blocks[1].content[1].src ..
          '", width: 100%, height: 138mm, fit: "contain"))') })
      end
    end
    local out = pandoc.Blocks({ pandoc.RawBlock('typst',
      '#ipo(\n  function-name: "' .. func ..
      '",\n  process-name: "' .. proc .. '",\n  input: [') })
    out:extend(cols.input)
    out:insert(pandoc.RawBlock('typst', '],\n  process: ['))
    out:extend(cols.process)
    out:insert(pandoc.RawBlock('typst', '],\n  output: ['))
    out:extend(cols.output)
    out:insert(pandoc.RawBlock('typst', '],\n)'))
    return out
  end
end

-- ============================================================
--  表の幅を本文幅いっぱいに正規化する。
--
--  Pandoc は Markdown の罫線（|---|）が十分に長いときだけ相対列幅を出力し、
--  短いと幅なし（Typst の auto 幅）になる。その結果、表ごとに幅と寄せが
--  バラバラになり「執筆者が罫線を何文字引いたか」で見た目が変わってしまう。
--  そこで全ての表に明示的な相対幅を与え、常に本文幅いっぱいに揃える。
--  Vivliostyle 版（table { width: 100% }）とも見た目が一致する。
--
--  列幅は各列の最大表示幅に比例させる（全角=2, 半角=1）。等幅にすると
--  「必須」のような短い列が広くなりすぎるため。
-- ============================================================

local function disp_width(s)
  local w = 0
  for _, cp in utf8.codes(s) do w = w + ((cp > 0x2E7F) and 2 or 1) end
  return w
end

local function cell_width(cell)
  return disp_width(pandoc.utils.stringify(pandoc.Div(cell.contents)))
end

function Table(t)
  local ncol = #t.colspecs
  if ncol == 0 then return nil end

  -- 各列の最大表示幅を集める（結合セルは列幅の根拠にしない）
  local maxw = {}
  for c = 1, ncol do maxw[c] = 1 end
  local function scan(rows)
    for _, row in ipairs(rows) do
      local c = 1
      for _, cell in ipairs(row.cells) do
        if cell.col_span == 1 and c <= ncol then
          local w = cell_width(cell)
          if w > maxw[c] then maxw[c] = w end
        end
        c = c + cell.col_span
      end
    end
  end
  for _, r in ipairs(t.head.rows) do scan({ r }) end
  for _, b in ipairs(t.bodies) do scan(b.body) end

  -- 極端な偏りを抑えてから正規化する
  local total = 0
  for c = 1, ncol do
    if maxw[c] > 40 then maxw[c] = 40 end   -- 長文列が支配しないよう頭打ち
    if maxw[c] < 4 then maxw[c] = 4 end     -- 短い列がつぶれないよう下限
    total = total + maxw[c]
  end

  for c = 1, ncol do
    t.colspecs[c] = { t.colspecs[c][1], maxw[c] / total }
  end
  return t
end
