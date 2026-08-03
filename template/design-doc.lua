-- ============================================================
--  設計書様式用 Quarto/Pandoc フィルタ（typst 出力用）
--  執筆者が qmd で使える記法を lib.typ の様式機能に対応付ける:
--   1) ```mermaid フェンス → 出力先で振る舞いを変える:
--        - PDF(typst) と 配布 HTML(MERMAID_SVG=1) … mermaid-cli で SVG 化して画像に
--          置換（diagrams/ に内容ハッシュでキャッシュ。ブラウザは setup 生成の
--          template/puppeteer.json、または EXECUTABLE_BROWSER の Chrome/Edge。node 要）
--        - 執筆者プレビュー HTML(既定) … Quarto 同梱 mermaid でクライアント描画（node 不要）
--   2) ::: {.landscape} div → #landscape[...]（横向きページ）
--   3) ::: {.ipo} div → #ipo(...)（IPO図。最初の見出し = 機能名 / 処理名、
--      入力/処理/出力（Input/Process/Output 可）の見出しで3列に分割）
--   4) ::: {.merge-rows} div → 中の表で縦に連続する同じ値のセルを rowspan 結合
--   5) すべての表の列幅を本文幅いっぱいに正規化（内容量に比例して配分）
-- ============================================================

-- book プロジェクトでは、フィルタ実行時の CWD が「いま処理している章ファイルの
-- ディレクトリ」になる（章の階層ごとに変わる）。したがって相対パスは使えず、
-- 執筆フォルダ（プロジェクトルート）の絶対パスが要る。環境変数に依存せず自力で
-- 求めるので、VSCode の Quarto 拡張や素の `quarto render` でもそのまま動く。
--   ROOT  … 執筆フォルダ（プロジェクトルート）。図の出力先 diagrams/ の親。
--   TMPL  … template/。mermaid-cli（node_modules）・設定・ブラウザ設定の置き場。
-- 解決の優先順位:
--   ROOT: DOC_ROOT env → quarto.project.directory → QUARTO_PROJECT_DIR env → '.'
--   TMPL: TEMPLATE_ROOT env → ROOT/../template
local function _norm(p) return (p or ''):gsub('\\', '/'):gsub('/+$', '') end
local ROOT = _norm(os.getenv('DOC_ROOT'))
if ROOT == '' then ROOT = _norm(quarto and quarto.project and quarto.project.directory) end
if ROOT == '' then ROOT = _norm(os.getenv('QUARTO_PROJECT_DIR')) end
if ROOT == '' then ROOT = '.' end
local TMPL = _norm(os.getenv('TEMPLATE_ROOT'))
if TMPL == '' then TMPL = ROOT .. '/../template' end
local MMDC = TMPL .. '/node_modules/@mermaid-js/mermaid-cli/src/cli.js'
local MMDC_CONF = TMPL .. '/mermaid-config.json'
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
  -- puppeteer 設定（既存 Edge/Chrome を流用。Chromium はダウンロードしない）。
  -- 優先順位:
  --   1) EXECUTABLE_BROWSER env があれば、その実行ファイルで一時設定を書く（明示指定）
  --   2) setup が template/ に書いた puppeteer.json があればそれを使う（拡張・env なし）
  --   3) どちらも無ければ {}（mmdc 同梱 Chromium を試す。無ければ下でエラー）
  local pp
  local browser = os.getenv('EXECUTABLE_BROWSER') or ''
  if browser ~= '' then
    pp = DIAG .. '/puppeteer.json'
    local pf = assert(io.open(pp, 'w'))
    pf:write('{"executablePath": "' .. browser:gsub('\\', '/') .. '"}')
    pf:close()
  elseif file_exists(TMPL .. '/puppeteer.json') then
    pp = TMPL .. '/puppeteer.json'
  else
    pp = DIAG .. '/puppeteer.json'
    local pf = assert(io.open(pp, 'w')); pf:write('{}'); pf:close()
  end
  os.execute('node "' .. MMDC .. '" -i "' .. mmd .. '" -o "' .. svg ..
    '" -b transparent -c "' .. MMDC_CONF .. '" -p "' .. pp .. '"')
  if not file_exists(svg) then
    error('mermaid の変換に失敗しました: ' .. mmd ..
      '\n  ブラウザ設定を確認してください（Chrome/Edge が必要）。' ..
      '\n  ルートから `./template/setup.sh <執筆フォルダ>` を実行するか、' ..
      '\n  EXECUTABLE_BROWSER=<chrome/msedge の実行ファイル> を指定してください。')
  end
  return rel
end

-- mermaid をベクター SVG に焼くのは PDF(typst) と、配布 HTML（build-html.sh が
-- MERMAID_SVG=1 を渡す）。図を PDF と一致させ、Quarto の figure 採番に載せるため。
-- 既定の HTML（＝執筆者の quarto preview）は node を使わずクライアント描画にする。
local WANT_SVG = (FORMAT == 'typst') or (os.getenv('MERMAID_SVG') == '1')

-- クライアント描画用に、Quarto 同梱の mermaid ランタイム（native ```{mermaid} と
-- 同じ mermaid.min.js / init / css）を一度だけ注入する。QUARTO_SHARE_PATH は
-- Quarto が render 時にフィルタへ渡す。init は pre.mermaid-js を拾って SVG 化する。
local mermaid_runtime_injected = false
local function inject_mermaid_runtime()
  if mermaid_runtime_injected then return end
  mermaid_runtime_injected = true
  local base = _norm(os.getenv('QUARTO_SHARE_PATH')) .. '/formats/html/mermaid/'
  quarto.doc.add_html_dependency({
    name = 'quarto-diagram',
    scripts = { base .. 'mermaid.min.js', base .. 'mermaid-init.js' },
    stylesheets = { base .. 'mermaid.css' },
  })
end

function CodeBlock(el)
  if el.classes:includes('mermaid') then
    if WANT_SVG then
      local svg = render_mermaid(el.text)
      local img = pandoc.Image({}, svg, '', pandoc.Attr('', {}, { { 'width', '90%' } }))
      return pandoc.Para({ img })
    end
    -- 執筆者プレビュー: Quarto native と同じ <pre class="mermaid mermaid-js"> を出す。
    inject_mermaid_runtime()
    return pandoc.RawBlock('html',
      '<pre class="mermaid mermaid-js">\n' .. el.text .. '\n</pre>')
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

-- 表の列幅計算に使う表示幅（全角=2 / 半角=1）。split-table の幅統一と Table() で共用する。
local function disp_width(s)
  local w = 0
  for _, cp in utf8.codes(s) do w = w + ((cp > 0x2E7F) and 2 or 1) end
  return w
end

local function cell_width(cell)
  return disp_width(pandoc.utils.stringify(pandoc.Div(cell.contents)))
end

-- 表 t の各列の最大表示幅を maxw（1始まり）へ集める。結合セル（col_span>1）は根拠にしない。
local function scan_table_widths(t, ncol, maxw)
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
end

function Div(el)
  if el.classes:includes('merge-rows') then
    -- div 自体は残さない（block が挟まると図表の中央寄せが崩れるため）
    return pandoc.walk_block(el, { Table = function(t)
      for _, b in ipairs(t.bodies) do merge_body(b.body) end
      return t
    end }).content
  end

  if el.classes:includes('split-table') then
    -- ::: {.split-table caption="…"} … 空行区切りの複数パイプ表 … :::
    -- 大きな表を複数パートに割り、同じ表番号を共有しつつキャプションに「（i／M）」を
    -- 付ける。列幅は全パート横断で統一する。M（分割総数）= 内包する表の数。
    --
    -- なぜクラス div（#tbl- を付けない）か:
    --   Quarto は #tbl- 付きの表を、ユーザ Lua フィルタより前に独自ノード
    --   （FloatRefTarget）へ変換してしまい、ここへは届かない。そこで ipo/landscape/
    --   merge-rows と同じくクラス div で受け、採番も自前で行う（ipo と同じ流儀）。
    --   反面、Quarto の図表フロートに載らないため相互参照 @tbl- の対象にはできない
    --   （番号は本文の表と連続する。参照が要る表は分割しない運用）。
    local parts = {}
    for _, b in ipairs(el.content) do
      if b.t == 'Table' then parts[#parts + 1] = b end
    end
    local M = #parts
    if M == 0 then return el.content end
    local caption = el.attributes.caption or ''

    -- 全パート横断で列幅を統一（列数が揃っているときだけ。ずれていたら警告して個別幅のまま）。
    local ncol = #parts[1].colspecs
    local same = ncol > 0
    for _, t in ipairs(parts) do if #t.colspecs ~= ncol then same = false end end
    if same then
      local maxw = {}
      for c = 1, ncol do maxw[c] = 1 end
      for _, t in ipairs(parts) do scan_table_widths(t, ncol, maxw) end
      local total = 0
      for c = 1, ncol do
        if maxw[c] > 40 then maxw[c] = 40 end
        if maxw[c] < 4 then maxw[c] = 4 end
        total = total + maxw[c]
      end
      for _, t in ipairs(parts) do
        for c = 1, ncol do t.colspecs[c] = { t.colspecs[c][1], maxw[c] / total } end
      end
    else
      io.stderr:write('[design-doc] 警告: split-table 内の表で列数が一致しません。' ..
        '列幅の統一をスキップします。\n')
    end

    -- 「（i／M）　」。M==1 のときは付けない（通常の1枚表として扱う）。
    local function tag(i)
      if M < 2 then return '' end
      return '（' .. i .. '／' .. M .. '）　'
    end
    -- typst 文字列（"…"）へ入れるキャプションのエスケープ。
    local function tcap(i)
      return (tag(i) .. caption):gsub('\\', '\\\\'):gsub('"', '\\"')
    end

    local out = pandoc.Blocks({})
    local TBLC = 'counter(figure.where(kind: "quarto-float-tbl"))'
    for i = 1, M do
      if IS_HTML then
        -- HTML: 採番用キャプション div を各パートの上に置く。番号は
        -- postprocess-html.mjs が本文の表と同じ連番で採番し、先頭に前置する。
        -- 先頭パートに data-split-first を付け、そこで1つの表番号を確定させる。
        local first = (i == 1) and ' data-split-first="true"' or ''
        local body = (tag(i) .. caption):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;')
        out:insert(pandoc.RawBlock('html', '<div class="split-caption"' .. first ..
          ' data-part="' .. i .. '" data-total="' .. M .. '">' .. body .. '</div>'))
      elseif i == 1 then
        -- PDF: 先頭で採番カウンタを1つ進め、全パートが同じ番号を表示する（ipo と同じ手法）。
        -- step はカウンタ更新、番号表示は別 context の get で行う（同一 context 内で
        -- step 直後に get すると値が確定しないため、位置的に後段の context で読む）。
        out:insert(pandoc.RawBlock('typst', '#{\n  ' .. TBLC .. '.step()\n  ' ..
          'context align(center, text(font: JP-SANS, size: BODY-SIZE)[表 ' ..
          '#_section-prefix(here())-#' .. TBLC .. '.get().first()　#("' .. tcap(i) .. '")])\n}'))
      else
        out:insert(pandoc.RawBlock('typst', '#pagebreak(weak: true)'))
        out:insert(pandoc.RawBlock('typst',
          '#context align(center, text(font: JP-SANS, size: BODY-SIZE)[表 ' ..
          '#_section-prefix(here())-#' .. TBLC .. '.get().first()　#("' .. tcap(i) .. '")])'))
      end
      out:insert(parts[i])
    end
    return out
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
    -- 記法（div 属性で指定。機能名/処理名/タイトルを別々に扱う）:
    --   ::: {.ipo module="受注管理" caption="受注処理の流れ"}
    --   ## 受注登録        ← 見出し = 処理名
    -- 機能名 = module 属性、処理名 = 最初の見出し、タイトル = caption 属性。
    -- module 省略時は旧記法として見出しを「機能名 / 処理名」で分割する（後方互換）。
    local cap = el.attributes.caption or ''
    local func = el.attributes.module
    local hasModule = (func ~= nil)
    if not hasModule then func = '' end
    local proc = ''
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
          if hasModule then
            proc = txt                                  -- 新記法: 見出し = 処理名
          else
            func = txt:match('^(.-)%s*/') or txt        -- 旧記法: 見出しを分割
            proc = txt:match('/%s*(.*)$') or ''
          end
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
      '",\n  process-name: "' .. proc ..
      '",\n  caption: "' .. cap .. '",\n  input: [') })
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

-- disp_width / cell_width は Div より前（split-table と共用）へ移動済み。

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
