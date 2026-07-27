// ============================================================
//  設計書 共通テンプレート  (Typst / Quarto の typst バックエンド共用)
//  外部パッケージ不要 = 完全オフライン
//  会社様式（再現目標: ルートの portrait.pdf / landscape.pdf / ipo-landscape.pdf）
//   - 全ページ: 本文を囲む外枠
//   - 右上: 枠付き「資料番号」ラベル + 番号 + ページ「n / N」
//   - 下部中央: 社名（文字間広め）
//   - 横向きページ: 様式ごと 90°回転（縦綴じのまま回して読む配置）
//   - ipo() : IPO図（機能名/処理名 + 入力/処理/出力 の定型表）
// ============================================================

// ============================================================
//  【1】調整パラメータ
//
//  様式の微調整は原則ここだけを触れば済むようにしてある。
//  下の関数群は、この節の定数を参照するだけ。
//
//  寸法の考え方（A4 縦 = 210 x 297mm）:
//
//      0                                              210mm
//      ┌──────────────────────────────────────────────┐
//      │        ┌─ FRAME-P-POS.x = 15mm               │
//      │        ↓                                     │
//      │        ┌────────────[資料番号 SD-xxx  1/10]  │ ← 枠の上辺に接地
//      │        │←── FRAME-P-SIZE.width = 180mm ──→│  │   (dy = y - 枠の高さ)
//      │        │                                  │  │
//      │  24mm  │   ← PAGE-P-MARGIN.x = 24mm       │  │  本文は枠より
//      │ ←───→ │      （枠より 9mm 内側）          │  │  9mm 内側に入る
//      │        │                                  │  │
//      │        │  FRAME-P-SIZE.height = 268mm     │  │
//      │        └──────────────────────────────────┘  │
//      │                 ソ フ ト 開 発 株 式 会 社      │ ← footer
//      └──────────────────────────────────────────────┘
//
//  縦は上 20mm・下 9mm（297 - 20 - 268）で非対称。原紙がそうなっている。
//  左右は 15mm ずつで対称（210 - 15 - 180 = 15）。
//
//  横向き（landscape / ipo）は A4 横 = 297 x 210mm。様式ごと 90°回転する。
//  資料番号は「外枠の右辺に接する」= FRAME-L-POS.x + FRAME-L-SIZE.width の位置。
// ============================================================

// ---- フォント ----
// 実運用は Noto CJK を前提。無い環境では Yu Gothic → MS PGothic に落ちる
// （字形確認は Noto を入れて行うこと）。
#let JP-SANS = ("Noto Sans CJK JP", "Yu Gothic", "MS PGothic")
#let JP-SERIF = ("Noto Serif CJK JP", "Yu Mincho", "MS PMincho")

// ---- 線 ----
#let BORDER = rgb("#b0b0b0")   // 本文中の表罫線（様式ではなく中身の罫線）
#let FRAME = 0.8pt + black     // 様式の外枠。太さを変えるならここ
#let RULE = 0.6pt + black      // 資料番号の枠・IPO 図の罫線

// ---- 本文の体裁 ----
#let BODY-SIZE = 10.5pt        // 本文の文字サイズ
#let BODY-LEADING = 0.9em      // 行間
#let FURNITURE-SIZE = 9pt      // 様式の文字（社名・ページ番号）
#let COMPANY-TRACKING = 6pt    // 社名の字間。原紙が広めなので開けてある

// 見出しの文字サイズ（h1〜h4）。採番の書式は【3】の set heading を参照。
#let HEAD-SIZES = (16pt, 13pt, 11.5pt, 10.5pt)

// ---- 縦ページ（ポートレート）----
#let PAGE-P-MARGIN = (x: 24mm, top: 28mm, bottom: 24mm)  // 本文の余白
#let FRAME-P-POS = (x: 15mm, y: 20mm)                    // 外枠の左上
#let FRAME-P-SIZE = (width: 180mm, height: 268mm)        // 外枠の大きさ
#let FOOTER-DESCENT = 70%                                // 社名を下げる量

// ---- 資料番号の欄（縦横で共通の見た目）----
#let DOCNUM-INSET = (x: 3.5mm, y: 1.8mm)  // 「資料番号」枠の内側の余白
#let DOCNUM-SIZE = 10pt                   // 枠内の文字サイズ
#let DOCNUM-TRACKING = 1pt                // 「資料番号」の字間
#let DOCNUM-GAP = 3.5mm                   // 「資料番号」と番号の間隔
#let DOCNUM-PAGE-GAP = 3mm                // 枠とページ番号 n / N の間隔

// ---- 横ページ（landscape / IPO 共通の様式）----
#let FRAME-L-POS = (x: 15mm, y: 15mm)
#let FRAME-L-SIZE = (width: 262mm, height: 180mm)
#let COMPANY-L-X = 2.5mm    // 左端に縦書きする社名の位置
#let DOCNUM-L-Y = 115mm     // 右端の資料番号の高さ（回転後の起点）

// ---- 横ページの本文余白 ----
// landscape は表を主に置くので左右をやや広く、IPO は枠いっぱいを使う。
#let PAGE-L-MARGIN = (left: 30mm, right: 32mm, top: 22mm, bottom: 22mm)
#let PAGE-IPO-MARGIN = (left: 24mm, right: 30mm, top: 20mm, bottom: 20mm)

// ---- IPO 図の枠割り ----
// 上段（機能名/処理名）: ラベル幅・値幅・ラベル幅・残り
#let IPO-TITLE-COLS = (24mm, 72mm, 24mm, 1fr)
#let IPO-TITLE-ROW = 8.5mm
// 下段（入力/処理/出力）: 列比。処理欄に mermaid を置くので中央を広く取る。
// **この比は design-doc.css の .ipo-frame の grid-template-columns と揃えること**
// （HTML 側の見た目が PDF とずれる）。
#let IPO-COLS = (1fr, 4.9fr, 1.1fr)
#let IPO-HEAD-ROW = 8mm     // 「入力/処理/出力」の見出し行の高さ
#let IPO-BODY-ROW = 150mm   // 本体の高さ。増やすと枠が下にはみ出すので注意
#let IPO-INSET = (x: 2.5mm, y: 2mm)
#let IPO-HEAD-TRACKING = 3pt
// 上段と下段の table を隙間なく繋ぐ。罫線1本ぶん（0.6pt）重ねる。
#let IPO-STACK-OVERLAP = -0.6pt

// ============================================================
//  【2】様式パーツ（外枠・資料番号・社名）
// ============================================================

// 様式メタ。design-doc() が設定し、横向きページの様式描画が読む。
// state を使うのは、landscape()/ipo() が design-doc() の引数を直接見られない
// （別の呼び出しなので）ため。
#let _doc-number = state("design-doc-number", "")
#let _company = state("design-company", "ソフト開発株式会社")

// ---- 「資料番号」欄 + ページ番号 n / N ----
// 縦ページでは右上に水平、横ページでは右端に 90°回転して置かれる。
// 中身は同じなのでこの1つを使い回す。
//   [資料番号  SD-2026-001]  3 / 10
//    └── 枠あり ──────────┘  └ 枠なし
// 総ページ数は counter(page).final() で組版後に確定するため context が要る。
#let _docnum-strip(doc-number) = context {
  set text(font: JP-SANS, size: FURNITURE-SIZE)
  let total = counter(page).final().first()
  stack(dir: ltr, spacing: DOCNUM-PAGE-GAP,
    box(stroke: RULE, inset: DOCNUM-INSET,
      text(size: DOCNUM-SIZE)[
        #text(tracking: DOCNUM-TRACKING, "資料番号")#h(DOCNUM-GAP)#doc-number
      ]),
    // ページ番号は枠外。上下 inset を枠と揃えて文字のベースラインを合わせる。
    box(inset: (y: DOCNUM-INSET.y), [#counter(page).display("1") / #total]),
  )
}

// ---- 横向きページの様式（枠・社名・資料番号を 90°回転で配置） ----
// 縦綴じのまま用紙を回して読む配置なので、社名が左端に縦、資料番号が右端に縦。
// 資料番号の枠は外枠の右辺に接する（原紙準拠）ため、x は
// 「外枠の左端 + 外枠の幅」で求める。外枠を動かせば資料番号も追従する。
#let _side-furniture = context {
  place(top + left, dx: FRAME-L-POS.x, dy: FRAME-L-POS.y,
    rect(width: FRAME-L-SIZE.width, height: FRAME-L-SIZE.height, stroke: FRAME))
  place(left + horizon, dx: COMPANY-L-X, rotate(90deg, reflow: true,
    text(font: JP-SANS, size: FURNITURE-SIZE,
      tracking: COMPANY-TRACKING, _company.get())))
  place(top + left, dx: FRAME-L-POS.x + FRAME-L-SIZE.width, dy: DOCNUM-L-Y,
    rotate(90deg, reflow: true, _docnum-strip(_doc-number.get())))
}

// ============================================================
//  【3】文書全体のセットアップ（本文はポートレート）
//
//  Quarto から使うときは typst-show.typ がフロントマターを引数に渡す。
//  素の Typst から使うときは #show: design-doc.with(...) と書く。
// ============================================================
#let design-doc(
  title: "設計書", subtitle: "", author: "",
  doc-number: "", company: "ソフト開発株式会社",
  toc: false, toc-title: "目 次", toc-depth: 3,
  body,
) = {
  set document(title: title, author: author)
  _doc-number.update(doc-number)
  _company.update(company)
  set page(
    paper: "a4",
    margin: PAGE-P-MARGIN,
    header: none,
    footer: align(center, text(font: JP-SANS, size: FURNITURE-SIZE,
      tracking: COMPANY-TRACKING, company)),
    footer-descent: FOOTER-DESCENT,
    // 外枠と資料番号は「背景」層に描く。本文の流し込みに影響させないため。
    // 資料番号は枠の下辺が外枠の上辺にちょうど接するように置く（原紙準拠）。
    // そのために measure() で実際の高さを測り、枠の上辺からその分だけ引く。
    // ＝ 資料番号の文字サイズや inset を変えても接地は自動で保たれる。
    background: context {
      let strip = _docnum-strip(doc-number)
      let h = measure(strip).height
      place(top + left, dx: FRAME-P-POS.x, dy: FRAME-P-POS.y,
        rect(width: FRAME-P-SIZE.width, height: FRAME-P-SIZE.height,
          stroke: FRAME))
      // 右端も外枠に揃える。top+right 基準なので dx は負で内側へ。
      place(top + right, dx: -FRAME-P-POS.x, dy: FRAME-P-POS.y - h, strip)
    },
  )
  set text(font: JP-SANS, size: BODY-SIZE, lang: "ja")
  set par(justify: true, leading: BODY-LEADING)

  // 章番号の自動採番（付録を A.1 にしたい等はここを差し替えるだけ）
  set heading(numbering: "1.1.1")
  // 章（level 1）・節（level 2）の先頭で図表カウンタを 0 に戻す。
  // → 図表番号は「章.節-連番」で、連番は節ごとにリセットされる。
  // （関数にして毎回新しい update を発行する。値を使い回すと1回しか発火しない）
  // 対象 kind: image/table は素の Typst（jp-figure/jp-table）、
  // quarto-float-* は Quarto qmd フローの図表。両フローで動くよう全て 0 に戻す。
  let reset-floats() = {
    for k in (image, table, "quarto-float-fig", "quarto-float-tbl") {
      counter(figure.where(kind: k)).update(0)
    }
  }
  // 見出しの体裁。サイズは HEAD-SIZES、前後の空きは下の above/below。
  // 図表カウンタのリセットは h1/h2 だけに掛ける（h3 以降で戻すと
  // 「章.節-連番」の連番が節の途中で 1 に戻ってしまう）。
  show heading.where(level: 1): it => {
    reset-floats()
    set text(size: HEAD-SIZES.at(0), weight: "bold")
    block(above: 1.4em, below: 0.8em, it)
  }
  show heading.where(level: 2): it => {
    reset-floats()
    set text(size: HEAD-SIZES.at(1), weight: "bold")
    block(above: 1.1em, below: 0.6em, it)
  }
  show heading.where(level: 3): it => {
    set text(size: HEAD-SIZES.at(2), weight: "bold")
    block(above: 1em, below: 0.5em, it)
  }
  show heading.where(level: 4): it => {
    set text(size: HEAD-SIZES.at(3), weight: "bold")
    block(above: 0.9em, below: 0.4em, it)
  }

  // 図表番号の接頭辞「章.節」を、指定位置の見出しカウンタから組み立てる。
  let section-prefix(loc) = {
    let heads = counter(heading).at(loc)
    numbering("1.1", heads.at(0, default: 0), heads.at(1, default: 0))
  }

  // 図・表の日本語キャプションと採番（「図 3.2-1」＝ 章.節-連番）
  set figure.caption(separator: [　])
  show figure.where(kind: table): set figure.caption(position: top)
  set figure(numbering: n => context section-prefix(here()) + "-" + str(n))
  // 参照(@fig-x)も本体と同じ番号にする。必ず対象図表の location で counter を読む
  // （参照位置で評価すると節番号がずれるため）。
  show ref: it => {
    let el = it.element
    if el != none and el.func() == figure {
      let loc = el.location()
      let n = counter(figure.where(kind: el.kind)).at(loc).first()
      link(loc, [#el.supplement #section-prefix(loc)-#n])
    } else { it }
  }

  // ---- タイトルページ ----
  // 見出し（heading）にはしない。h1 にすると章カウンタを消費し、
  // 目次にも項目として載ってしまう。
  align(center + horizon)[
    #text(font: JP-SANS, size: 24pt, weight: "bold", title)
    #v(6pt)
    #if subtitle != "" { text(size: 13pt, fill: rgb("#666"), subtitle) }
    #v(24pt)
    #text(size: 11pt, fill: rgb("#666"), author)
  ]
  pagebreak()

  // 目次（toc: true のとき）。章番号・ページ番号・リーダー線は outline が自動生成する。
  if toc {
    show outline.entry.where(level: 1): set block(above: 1.2em)
    outline(
      title: text(size: 16pt, weight: "bold", toc-title),
      depth: toc-depth, indent: 2em,
    )
    pagebreak()
  }

  body
}

// ---- 図ヘルパー（相互参照用ラベルは呼び出し側で <fig-xxx> を付ける） ----
#let jp-figure(content, caption: "") = figure(
  content, caption: caption, kind: image, supplement: [図],
)
#let jp-table(content, caption: "") = figure(
  content, caption: caption, kind: table, supplement: [表],
)

// ============================================================
//  【4】landscape() : 中身だけ横向き様式ページにして、終わったら縦に戻す
//
//  末尾の set page(flipped: false) が「戻す」役。これが無いと以降の本文が
//  全部横になる。header/footer を none にするのは、横ページの社名と
//  ページ番号を _side-furniture が回転して描くため（二重に出さない）。
// ============================================================
#let landscape(body) = {
  set page(
    flipped: true,
    margin: PAGE-L-MARGIN,
    header: none, footer: none,
    background: _side-furniture,
  )
  body
  set page(flipped: false)
}

// ============================================================
//  【5】IPO図（横向き様式ページ + 機能名/処理名 + 入力/処理/出力）
//
//  構造は table 2つを縦に積んだだけ:
//    ┌──────┬────────────┬──────┬──────────┐  ← IPO-TITLE-COLS
//    │機能名│ 受注管理   │処理名│ 受注処理 │     高さ IPO-TITLE-ROW
//    ├──────┴┬───────────┴─┬────┴──────────┤
//    │ 入力  │    処理      │     出力      │  ← IPO-HEAD-ROW
//    ├───────┼──────────────┼───────────────┤
//    │       │              │               │
//    │       │  (mermaid)   │               │     高さ IPO-BODY-ROW
//    └───────┴──────────────┴───────────────┘  ← 列比 IPO-COLS
//
//  2つの table の境目は罫線が二重になるので IPO-STACK-OVERLAP で1本ぶん重ねる。
//  自由な結線が要る場合は process に SVG/PlantUML 画像を貼る
//  （項目単位の配線は自動組版では再現しない方針。CLAUDE.md「既知の限界」参照）。
//
//  qmd から使うときは design-doc.lua が ::: {.ipo} div をこの呼び出しに変換する。
//  執筆者がこの関数を直接書くのは素の Typst（main.typ）のときだけ。
// ============================================================
#let ipo(
  function-name: "", process-name: "",
  input: [], process: [], output: [],
) = {
  set page(
    flipped: true,
    margin: PAGE-IPO-MARGIN,
    header: none, footer: none,
    background: _side-furniture,
  )
  set text(font: JP-SANS, size: 10pt)
  // 欄見出し（機能名/処理名/入力/処理/出力）の共通スタイル
  let head(t) = align(center + horizon,
    text(weight: "bold", tracking: IPO-HEAD-TRACKING, t))
  stack(spacing: IPO-STACK-OVERLAP,
    // 上段: 機能名 / 処理名
    table(
      columns: IPO-TITLE-COLS, rows: IPO-TITLE-ROW,
      stroke: RULE, inset: (x: 2mm, y: 0pt),
      head("機能名"), align(horizon, function-name),
      head("処理名"), align(horizon, process-name),
    ),
    // 下段: 入力 / 処理 / 出力
    // 見出しセルだけ inset を 0 にして、head() の中央揃えを効かせる。
    table(
      columns: IPO-COLS, rows: (IPO-HEAD-ROW, IPO-BODY-ROW),
      stroke: RULE, inset: IPO-INSET,
      table.cell(inset: 0pt, head("入力")),
      table.cell(inset: 0pt, head("処理")),
      table.cell(inset: 0pt, head("出力")),
      align(top, input), align(top, process), align(top, output),
    ),
  )
  set page(flipped: false)
}
