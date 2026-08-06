// ============================================================
//  book の各章 HTML の図表番号を PDF と同じ「章.節.項…-連番」に振り直す。
//  接頭辞は見出しの深さ（レベル1〜5）に追従する（例 図 3-1 / 図 3.2-1 / 図 3.2.1-1）。
//
//  なぜ後処理なのか:
//    Quarto の図表採番（crossref）は **すべての Lua フィルタより後段**で走る。
//    pre-quarto / post-quarto のどちらで見ても、この時点では表に id も
//    キャプションも付いておらず、参照は未解決の Cite のままである。
//    つまりフィルタでは上書きできないため、生成された HTML を直す。
//
//  book 固有の事情が2つある:
//    1) 連番は文書全体で決まるので、まず全章を book の並び順に走査して番号を
//       確定し（パス1）、そのあと全ファイルの参照を解決する（パス2）。
//    2) 相互参照は他の章ファイルを指す（href="../02-architecture.html#fig-x"）。
//       href の #フラグメントだけを見て全体マップを引けばよい。
//
//  Quarto が出す形は規則的で、次の2箇所だけ書き換えれば足りる:
//    キャプション: <figcaption ... id="fig-arch-caption-XXX">図&nbsp;1.1: 説明</figcaption>
//    相互参照    : <a href="...#fig-arch" class="quarto-xref">図&nbsp;<span>1.1</span></a>
//
//  節番号は Quarto が見出しに付ける data-number="3.3.2" から取る。
//  なお NBSP は book 出力では実体参照 &nbsp;、単一 HTML 出力では生の U+00A0 と
//  形が違う。どちらでも拾えるように SP で両対応にしてある。
// ============================================================
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2] || '_book';

// 章順は _quarto.yml の chapters をそのまま使う（並びを二重管理しない）。
// chapters は「- パス.qmd」が1行1件で並ぶだけなので、簡易パースで足りる。
const conf = fs.readFileSync('_quarto.yml', 'utf8');
const block = conf.match(/^\s*chapters:\s*$([\s\S]*?)^\S/m)
  || conf.match(/^\s*chapters:\s*$([\s\S]*)/m);
const order = [...(block?.[1] ?? '').matchAll(/^\s*-\s*(\S+\.qmd)\s*$/gm)]
  .map((m) => m[1].replace(/\.qmd$/, '.html'));
if (order.length === 0) {
  console.error('_quarto.yml の chapters を読めませんでした');
  process.exit(1);
}

const SP = String.raw`(?:\s|&nbsp;)*`;
// 章番号は本文の章タイトル <h1 class="title"><span class="chapter-number">3</span>…
// から取る。data-number は節見出し（h2 以降）にしか付かないため、章直下（節なし）の
// 図表では章番号が拾えず 0 になってしまう。サイドバー／パンくずにも chapter-number は
// あるが、それらは <h1 class="title"> に包まれないので誤って拾うことはない。
// 番号なし章（{.unnumbered}）は chapter-number を持たず、章番号 0（例 図 0-1）になる。
const CHAP = String.raw`<h1 class="title">(?:<span class="chapter-number">(\d+)</span>)?`;
const HEAD = String.raw`<h[2-6][^>]*\bdata-number="([\d.]+)"`;
const CAP = String.raw`<figcaption[^>]*\bid="((?:fig|tbl)-[^"]*?)-caption-[^"]*"[^>]*>${SP}(図|表)${SP}[\d.]+:${SP}`;
const CAP_TAIL = new RegExp(String.raw`(図|表)${SP}[\d.]+:${SP}$`);
// 分割表(.tbl/.split-table)のキャプション div（design-doc.lua が各パートの上に置く）。
// 先頭パート(data-split-first)で1つの表番号を確定し、続くパートも同じ番号を共有する。
// 番号は本文の表と同じ連番列に載せる（走査順に採番）。
// class は "split-caption" の後ろに Quarto が id 付き要素へ付与する " anchored" 等が
// 続くことがあるので、追加クラスを許容する（class="split-caption …"）。
const SPLIT = String.raw`<div class="split-caption[^"]*"([^>]*)>([\s\S]*?)</div>`;

const numberOf = new Map();   // floatId -> "図 3.3-1"
const staged = new Map();     // file -> { html, repl }

// --- パス1: 章順に走査して番号を確定する ---
for (const rel of order) {
  const file = path.join(root, rel);
  const html = fs.readFileSync(file, 'utf8');
  const scan = new RegExp(`${CHAP}|${HEAD}|${CAP}|${SPLIT}`, 'g');
  let chap = 0;
  // いま処理中の見出しの番号（data-number）。章直下（節なし）は空文字。
  // 図表番号は PDF と同じく見出しの深さ「章.節.項…」（最大レベル5）に追従する。
  let secKey = '';
  const seq = new Map();      // "図|3.3.2" -> 連番
  const repl = [];            // [start, end, 置換文字列]
  let splitLabel = '';        // いま処理中の分割表グループの共有ラベル
  // 図表番号の接頭辞: 節なし（章直下 = h1）は「3.0」ではなく章のみ「3」。
  const prefixOf = () => (secKey === '' ? `${chap}` : secKey);

  for (let m; (m = scan.exec(html)) !== null; ) {
    if (m[0].startsWith('<h1')) {               // 章タイトル（章番号を確定・節を戻す）
      chap = Number(m[1]) || 0;
      secKey = '';
      continue;
    }
    if (m[2]) {                                 // 節以下の見出し
      // data-number="3.3.2" をそのまま接頭辞に使う（レベル5まで、以降は切る）。
      const parts = m[2].split('.').slice(0, 5);
      chap = Number(parts[0]) || 0;
      secKey = parts.join('.');
      continue;
    }
    if (m[5] !== undefined) {                   // 分割表のキャプション div
      const attrs = m[5];
      const inner = m[6];
      if (/data-split-first="true"/.test(attrs)) {
        // 先頭パート = ここで表番号を1つ確定（本文の表と同じ「表」列の連番）
        const prefix = prefixOf();
        const key = `表|${prefix}`;
        const n = (seq.get(key) || 0) + 1;
        seq.set(key, n);
        splitLabel = `表 ${prefix}-${n}`;
        // data-ref があれば id→番号を登録し、@tbl-x の参照（design-doc.lua が
        // 出す <a class="quarto-xref">）を pass2 で本文の表と同じ経路で解決させる。
        const refm = attrs.match(/data-ref="([^"]+)"/);
        if (refm) numberOf.set(refm[1], splitLabel);
      }
      // 続くパートも先頭と同じ番号。キャプション先頭に前置する（本文「（i／M）…」は残す）。
      const label = splitLabel || '表 ?';
      repl.push([m.index, m.index + m[0].length,
        `<div class="split-caption"${attrs}>${label}　${inner}</div>`]);
      continue;
    }
    const [floatId, kind] = [m[3], m[4]];
    const prefix = prefixOf();
    const key = `${kind}|${prefix}`;
    const n = (seq.get(key) || 0) + 1;
    seq.set(key, n);
    const label = `${kind} ${prefix}-${n}`;
    numberOf.set(floatId, label);
    // マッチした「図&nbsp;1.1: 」の部分だけを差し替える（キャプション本文は残す）
    repl.push([m.index, m.index + m[0].length, m[0].replace(CAP_TAIL, `${label}　`)]);
  }
  staged.set(file, { html, repl });
}

// --- パス2: キャプションを差し替え、全ファイルの参照を確定した番号に揃える ---
let refCount = 0;
let missing = 0;
for (const [file, { html, repl }] of staged) {
  let out = html;
  // 後ろから差し替えて位置ずれを避ける
  for (let i = repl.length - 1; i >= 0; i -= 1) {
    const [s, e, text] = repl[i];
    out = out.slice(0, s) + text + out.slice(e);
  }
  out = out.replace(
    /(<a href="[^"]*#((?:fig|tbl)-[^"]+)"[^>]*class="[^"]*quarto-xref[^"]*"[^>]*>)([\s\S]*?)(<\/a>)/g,
    (whole, open, id, _text, close) => {
      const label = numberOf.get(id);
      if (!label) { missing += 1; return whole; }
      refCount += 1;
      return `${open}${label}${close}`;
    });
  // 見出し参照(@sec-x): Quarto 既定の「チャプター 5 / セクション 5.3」を、番号＋章/節の
  // 後置表記へ。番号にドットが無い（＝章）→「5章」、ドットあり（＝節以下）→「5.3節」。
  // 言語に依存しないよう、番号の前の語（チャプター/セクション等）は捨てて番号だけ使う。
  out = out.replace(
    /(<a href="[^"]*#sec-[^"]+"[^>]*class="[^"]*quarto-xref[^"]*"[^>]*>)<span>[^0-9<]*([\d.]+)<\/span>(<\/a>)/g,
    (whole, open, num, close) => {
      const suffix = num.includes('.') ? '節' : '章';
      refCount += 1;
      return `${open}<span>${num}${suffix}</span>${close}`;
    });
  fs.writeFileSync(file, out);
}

console.log(`OK -> ${root} (図表 ${numberOf.size} 件 / 参照 ${refCount} 件を章.節.項…-連番に変換)`);
if (missing > 0) {
  console.error(`警告: 解決できない相互参照が ${missing} 件あります（id の綴りを確認）`);
  process.exit(1);
}
