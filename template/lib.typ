// ============================================================
//  設計書 共通テンプレート  (Typst / Quarto の typst バックエンド共用)
//  外部パッケージ不要 = 完全オフライン
//  会社様式（再現目標: ルートの portrait.pdf / landscape.pdf / ipo-landscape.pdf）
//   - 全ページ: 本文を囲む外枠
//   - 右上: 枠付き資料番号 + ページ「n / N」
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
//      │        ┌─ FRAME-P-POS.x = 23mm               │
//      │        ↓                                     │
//      │        ┌────────────[資料番号 SD-xxx  1/10]  │ ← 枠の上辺に接地
//      │        │←── FRAME-P-SIZE.width = 178mm ──→│  │   (dy = y - 枠の高さ)
//      │        │                                  │  │
//      │  28mm  │   ← PAGE-P-MARGIN.left = 28mm    │  │  本文は外枠の
//      │ ←───→ │      （枠より 5mm 内側）          │  │  内側 5mm（上下左右）
//      │        │                                  │  │
//      │        │  FRAME-P-SIZE.height = 256mm     │  │
//      │        └──────────────────────────────────┘  │
//      └──────────────────────────────────────────────┘
//
//  縦は上 27mm・下 14mm（297 - 27 - 256）で非対称。
//  左右も非対称で 左 23mm・右 9mm（210 - 23 - 178 = 9）。
//
//  横向き（landscape / ipo）は A4 横 = 297 x 210mm。様式ごと 90°回転する。
//  縦綴じのまま用紙を回して読む配置なので、資料番号を右端に縦置きする。
//
//      0                                                        297mm
//      ┌──────────────────────────────────────────────────────────┐
//      │     ┌─ FRAME-L-POS = (x: 14mm, y: 23mm) 外枠の左上        │
//      │     ↓                                            資  │    │ ← 資料番号は
//      │     ┌──────────────────────────────────────────┐  料  │    │   外枠の右辺に
//      │     │←─ FRAME-L-SIZE.width = 256mm ───────────→│  番  │    │   接して 90°縦置き
//      │     │                                          │  号  │    │   起点 dy =
//      │     │    FRAME-L-SIZE.height = 178mm            │      │    │   上辺 = 外枠上+DOCNUM-L-TOP
//      │     └──────────────────────────────────────────┘      │    │
//      └──────────────────────────────────────────────────────────┘
//
//  資料番号は「外枠の右辺に接する」= FRAME-L-POS.x + FRAME-L-SIZE.width の位置。
//  左右は 14mm・27mm（297 - 14 - 256 = 27）、上下は 23mm・9mm（210 - 23 - 178 = 9）で非対称。
//  これは A4 縦の外枠を時計回りに 90°回転した配置に一致する（左←下, 上←左, 右←上, 下←右）。
//  本文余白は枠より内側で、表向き = PAGE-L-MARGIN、IPO 図 = PAGE-IPO-MARGIN と別値。
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
#let PARA-INDENT = 1em         // 段落先頭の字下げ（1文字ぶん）
#let LIST-INDENT = 1em         // 箇条書きの追加字下げ（見出しレベルぶんに加えて1文字ぶん）
#let FURNITURE-SIZE = 9pt      // 様式の文字（ページ番号）

// 見出しの文字サイズ（h1〜h4）。採番の書式は【3】の set heading を参照。
// 現在は全レベル 10.5pt（本文と同サイズ）。レベルごとに変えたいときは各値を戻す。
#let HEAD-SIZES = (10.5pt, 10.5pt, 10.5pt, 10.5pt)
#let HEAD-INDENT-STEP = 1em    // 見出しの字下げ量。レベル n を (n-1) 段字下げする
                               // （L1=0, L2=1, L3=2 …。1em はその見出しの1文字ぶん）

// ---- 縦ページ（ポートレート）----
// 本文は外枠の内側 5mm に流し込む（外枠と本文の間隔を上下左右で 5mm に統一）。
//   左 = 外枠左23 + 5 = 28 / 右 = 210 - (外枠右201 - 5) = 14
//   上 = 外枠上27 + 5 = 32 / 下 = 297 - (外枠下283 - 5) = 19
#let PAGE-P-MARGIN = (left: 28mm, right: 14mm, top: 32mm, bottom: 19mm)  // 本文の余白
#let FRAME-P-POS = (x: 23mm, y: 27mm)                    // 外枠の左上（上端を 20→27mm に下げた）
#let FRAME-P-SIZE = (width: 178mm, height: 256mm)        // 外枠の大きさ（高さ 268→256mm、12mm 縮小）

// ---- 資料番号の欄（見た目は縦横で共通、寸法・位置は縦横で分離）----
#let DOCNUM-INSET = (x: 3.5mm, y: 1.65mm) // 資料番号枠の内側の余白（y が枠の高さを決める）
#let DOCNUM-SIZE = 14pt                   // 枠内の文字サイズ（これも枠の高さに効く）
// 上記の組合せで枠の高さ（A4横では幅）は約 7mm（Yu Gothic 実測）。
#let DOCNUM-PAGE-GAP = 5mm                // 資料枠とページ番号 n / N の間隔
//   ↑ これを増やすとページ番号欄が外枠の縁側へ寄る（外枠との隙間が縮む）。
#let DOCNUM-PAGE-DIGITS = 4               // ページ番号 n / N の想定最大桁数
#let DOCNUM-PAGE-WIDTH = 20mm             // ページ番号欄の幅（右寄せ・固定幅）。
// 欄を固定幅＋右寄せにし、総数 N を DIGITS 桁ぶんの幅へ右空白詰め（数字幅の空白）する
// ことで "/" の位置と欄の右端を安定させ、"/" と総数の間隔も一定にする。
// 欄の右端は資料枠のすぐ右で外枠内に収まる。
// 資料枠の幅・位置（縦横で独立して調整できるよう分離）:
#let DOCNUM-P-WIDTH = 45mm                // A4縦: 資料枠の幅
#let DOCNUM-P-LEFT  = 105mm               // A4縦: 外枠の左端から資料枠の左端まで
// A4横: 資料枠は 90°回転して置くので、この「幅」は用紙上では高さ方向になる。
// 45mm = A4縦の DOCNUM-P-WIDTH と一致 → 縦を 90°回転した姿にそろう。
#let DOCNUM-L-WIDTH = 45mm                // A4横: 資料枠の幅（回転後は高さ）

// ---- 横ページ（landscape / IPO 共通の様式）----
#let FRAME-L-POS = (x: 14mm, y: 23mm)
#let FRAME-L-SIZE = (width: 256mm, height: 178mm)
#let DOCNUM-L-TOP = 105mm   // 外枠の上端から資料枠の上端まで（回転後の上辺位置）

// ---- 横ページの本文余白 ----
// landscape も外枠の内側 5mm に統一（A4縦の PAGE-P-MARGIN を時計回りに 90°回転した値）。
//   左 = 外枠左14 + 5 = 19 / 右 = 297 - (外枠右270 - 5) = 32
//   上 = 外枠上23 + 5 = 28 / 下 = 210 - (外枠下201 - 5) = 14
//   （left←下, top←左, right←上, bottom←右 の対応で縦と一致）
// IPO は枠いっぱいを使う別値（PAGE-IPO-MARGIN）で、ここは変更しない。
#let PAGE-L-MARGIN = (left: 19mm, right: 32mm, top: 28mm, bottom: 14mm)
// IPO は表示領域を広く取るため左右を外枠の内側 3mm まで詰める（上は 5mm）。
// 左右は fr 列で本文幅に追従するのでここで決まるが、下辺（表の下端）は
// IPO-BODY-ROW（固定高さ）で決まる → 下の隙間は IPO-BOTTOM-GAP 側で調整する。
// bottom は表の下辺をクリップしないための余白（隙間量そのものは決めない）。
//   左 = 外枠左14 + 3 = 17 / 右 = 297 - (外枠右270 - 3) = 30 / 上 = 外枠上23 + 5 = 28
#let PAGE-IPO-MARGIN = (left: 17mm, right: 30mm, top: 28mm, bottom: 9mm)

// ---- IPO 図の枠割り ----
// 上段（機能名/処理名）: ラベル幅・値幅・ラベル幅・残り
#let IPO-TITLE-COLS = (24mm, 72mm, 24mm, 1fr)
#let IPO-TITLE-ROW = 8.5mm
// 下段（入力/処理/出力）: 列比。処理欄に mermaid を置くので中央を広く取る。
// **この比は design-doc.css の .ipo-frame の grid-template-columns と揃えること**
// （HTML 側の見た目が PDF とずれる）。
#let IPO-COLS = (1fr, 4.9fr, 1.1fr)
#let IPO-HEAD-ROW = 8mm     // 「入力/処理/出力」の見出し行の高さ
#let IPO-INSET = (x: 2.5mm, y: 2mm)
#let IPO-HEAD-TRACKING = 3pt
// 上段と下段の table を隙間なく繋ぐ。罫線1本ぶん（0.6pt）重ねる。
#let IPO-STACK-OVERLAP = -0.6pt
// 本体の高さは固定だが、値を直書きせず「表の下辺が外枠の下辺から IPO-BOTTOM-GAP だけ
// 内側に来る」よう逆算する。表の上辺 = PAGE-IPO-MARGIN.top なので、上マージンを
// 変えても下の隙間は保たれる（PAGE-IPO-MARGIN.bottom は下辺をクリップしないための
// 余白で、隙間量そのものは決めない）。
#let IPO-BOTTOM-GAP = 3mm   // 外枠の下辺と IPO 枠の下辺の隙間
#let IPO-BODY-ROW = (
  FRAME-L-POS.y + FRAME-L-SIZE.height - IPO-BOTTOM-GAP
    - PAGE-IPO-MARGIN.top - IPO-TITLE-ROW - IPO-HEAD-ROW - IPO-STACK-OVERLAP
)

// ============================================================
//  【2】様式パーツ（外枠・資料番号）
// ============================================================

// 様式メタ。design-doc() が設定し、横向きページの様式描画が読む。
// state を使うのは、landscape()/ipo() が design-doc() の引数を直接見られない
// （別の呼び出しなので）ため。
#let _doc-number = state("design-doc-number", "")
// 直前の見出しレベルに応じた本文の字下げ段数（L1=0, L2=1, L3=2 …）。
// 各 show heading が更新し、show par が本文段落の左字下げに使う。
#let _sec-indent = state("design-sec-indent", 0)

// 数字の後ろに数字幅の空白（U+2007）を足して指定桁ぶんの幅に揃える（右空白詰め）。
// ASCII 空白と違い Typst で連続空白が畳まれず、tabular 数字と組めば
// 「/」と総数の間隔が桁数によらず一定になる（総数は「/」直後に左寄せ）。
#let _pad-num(n, digits) = {
  let s = str(n)
  s + "\u{2007}" * calc.max(0, digits - s.len())
}

// ---- 資料番号の欄 + ページ番号 n / N ----
// 縦ページでは右上に水平、横ページでは右端に 90°回転して置かれる。
// 中身は同じなのでこの1つを使い回す。ラベル文字は付けず、番号だけを枠内に置く。
//   [SD-2026-001]  3 / 10
//    └─ 枠あり ─┘  └ 枠なし
// ページ番号欄は固定幅＋右寄せ。総数 N を DOCNUM-PAGE-DIGITS 桁ぶんへ右空白詰めし、
// tabular 数字にすることで "/" の位置・"/" と総数の間隔を安定させる（4桁まで対応）。
// 総ページ数は counter(page).final() で組版後に確定するため context が要る。
#let _docnum-strip(doc-number, box-width: auto) = context {
  set text(font: JP-SANS, size: FURNITURE-SIZE)
  let total = counter(page).final().first()
  stack(dir: ltr, spacing: DOCNUM-PAGE-GAP,
    box(width: box-width, stroke: RULE, inset: DOCNUM-INSET,
      align(center, text(size: DOCNUM-SIZE)[#doc-number])),
    // ページ番号は枠外。固定幅の欄に右寄せで置き、上下 inset を枠と揃える。
    box(width: DOCNUM-PAGE-WIDTH, inset: (y: DOCNUM-INSET.y),
      align(right, text(number-width: "tabular")[
        #counter(page).display("1") / #_pad-num(total, DOCNUM-PAGE-DIGITS)
      ])),
  )
}

// ---- 横向きページの様式（枠・資料番号を 90°回転で配置） ----
// 縦綴じのまま用紙を回して読む配置なので、資料番号を右端に縦置きする。
// 資料番号の枠は外枠の右辺に接する（原紙準拠）ため、x は
// 「外枠の左端 + 外枠の幅」で求める。外枠を動かせば資料番号も追従する。
#let _side-furniture = context {
  place(top + left, dx: FRAME-L-POS.x, dy: FRAME-L-POS.y,
    rect(width: FRAME-L-SIZE.width, height: FRAME-L-SIZE.height, stroke: FRAME))
  place(top + left, dx: FRAME-L-POS.x + FRAME-L-SIZE.width,
    dy: FRAME-L-POS.y + DOCNUM-L-TOP,
    rotate(90deg, reflow: true,
      _docnum-strip(_doc-number.get(), box-width: DOCNUM-L-WIDTH)))
}

// ============================================================
//  【3】文書全体のセットアップ（本文はポートレート）
//
//  Quarto から使うときは typst-show.typ がフロントマターを引数に渡す。
//  素の Typst から使うときは #show: design-doc.with(...) と書く。
// ============================================================
#let design-doc(
  title: "設計書", subtitle: "", author: "",
  doc-number: "",
  doc-revision: "",                    // 改訂記号（A〜Z / NC）。既定は空。資料番号の末尾に結合
  cover: false,                        // 表紙（タイトルページ）を出すか。既定は出さない
  toc: false, toc-title: "目 次", toc-depth: 3,
  body,
) = {
  set document(title: title, author: author)
  // 資料番号は「番号 + 改訂記号」を結合して表示する（改訂記号が空なら番号のみ）。
  // 横ページは _doc-number state 経由、縦ページは下の背景で doc-id を直接使う。
  let doc-id = doc-number + doc-revision
  _doc-number.update(doc-id)
  set page(
    paper: "a4",
    margin: PAGE-P-MARGIN,
    header: none,
    footer: none,
    // 外枠と資料番号は「背景」層に描く。本文の流し込みに影響させないため。
    // 資料番号は枠の下辺が外枠の上辺にちょうど接するように置く（原紙準拠）。
    // そのために measure() で実際の高さを測り、枠の上辺からその分だけ引く。
    // ＝ 資料番号の文字サイズや inset を変えても接地は自動で保たれる。
    background: context {
      let strip = _docnum-strip(doc-id, box-width: DOCNUM-P-WIDTH)
      let h = measure(strip).height
      place(top + left, dx: FRAME-P-POS.x, dy: FRAME-P-POS.y,
        rect(width: FRAME-P-SIZE.width, height: FRAME-P-SIZE.height,
          stroke: FRAME))
      // 資料枠は外枠の左端から DOCNUM-P-LEFT の位置に左端を合わせる（左端基準）。
      place(top + left, dx: FRAME-P-POS.x + DOCNUM-P-LEFT, dy: FRAME-P-POS.y - h, strip)
    },
  )
  set text(font: JP-SANS, size: BODY-SIZE, lang: "ja")
  // 段落の先頭を1文字字下げ。all: true で見出し直後の段落も字下げする（和文の作法）。
  set par(justify: true, leading: BODY-LEADING,
    first-line-indent: (amount: PARA-INDENT, all: true))
  // 本文段落を、直前の見出しレベルと同じ位置から始める（見出し配下の本文をレベルぶん
  // 字下げ）。字下げ段数は _sec-indent（各 show heading が更新）。見出し自身は各
  // show heading の inset で字下げ済み。表・図キャプションなど段落でない要素や
  // セル内の段落には影響しない（top-level の段落だけがこの show に掛かる）。
  show par: it => context { pad(left: _sec-indent.get() * HEAD-INDENT-STEP, it) }
  // 箇条書き（list/enum）は見出しレベルぶんに加えて さらに LIST-INDENT（1文字）字下げする
  // （段落の先頭字下げと頭を揃える）。表・IPO セル内のリストには効かない（top-level のみ）。
  show list: it => context { pad(left: _sec-indent.get() * HEAD-INDENT-STEP + LIST-INDENT, it) }
  show enum: it => context { pad(left: _sec-indent.get() * HEAD-INDENT-STEP + LIST-INDENT, it) }

  // 章番号の自動採番。レベル1だけ末尾にドットを付ける（"1." / "1.1" / "1.1.1"）。
  // 付録を A.1 にしたい等はここを差し替える。
  set heading(numbering: (..n) => {
    let nums = n.pos()
    if nums.len() == 1 { numbering("1.", nums.at(0)) }
    else { numbering("1.1.1.1", ..nums) }
  })
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
  // 左インセットで見出しをレベルごとに字下げ（L1=0, L2=1, L3=2 …段）。
  // 図表カウンタのリセットは h1/h2 だけに掛ける（h3 以降で戻すと
  // 「章.節-連番」の連番が節の途中で 1 に戻ってしまう）。
  show heading.where(level: 1): it => {
    reset-floats()
    _sec-indent.update(0)
    set text(size: HEAD-SIZES.at(0), weight: "bold")
    block(above: 1.4em, below: 0.8em, inset: (left: 0 * HEAD-INDENT-STEP), it)
  }
  show heading.where(level: 2): it => {
    reset-floats()
    _sec-indent.update(1)
    set text(size: HEAD-SIZES.at(1), weight: "bold")
    block(above: 1.1em, below: 0.6em, inset: (left: 1 * HEAD-INDENT-STEP), it)
  }
  show heading.where(level: 3): it => {
    _sec-indent.update(2)
    set text(size: HEAD-SIZES.at(2), weight: "bold")
    block(above: 1em, below: 0.5em, inset: (left: 2 * HEAD-INDENT-STEP), it)
  }
  show heading.where(level: 4): it => {
    _sec-indent.update(3)
    set text(size: HEAD-SIZES.at(3), weight: "bold")
    block(above: 0.9em, below: 0.4em, inset: (left: 3 * HEAD-INDENT-STEP), it)
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

  // ---- タイトルページ（cover: true のときだけ出す。既定は出さない）----
  // 見出し（heading）にはしない。h1 にすると章カウンタを消費し、
  // 目次にも項目として載ってしまう。
  // 表紙を出さないときは pagebreak も打たない（先頭の空ページを避けるため）。
  if cover {
    align(center + horizon)[
      #text(font: JP-SANS, size: 24pt, weight: "bold", title)
      #v(6pt)
      #if subtitle != "" { text(size: 13pt, fill: rgb("#666"), subtitle) }
      #v(24pt)
      #text(size: 11pt, fill: rgb("#666"), author)
    ]
    pagebreak()
  }

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
//  全部横になる。header/footer を none にするのは、横ページのページ番号を
//  _side-furniture が回転して描くため（二重に出さない）。
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
