/**
 * Générateur PDF minimal, sans dépendance : pages A4, texte en Helvetica (polices standard
 * du format PDF, codage WinAnsi pour les accents), traits. Suffisant pour des relevés
 * tabulaires, et sans code tiers à surveiller.
 */

const PAGE_WIDTH = 595.28;
const PAGE_HEIGHT = 841.89;

/** Largeurs Helvetica (millièmes d'em) des caractères des montants ; 556 par défaut. */
const WIDTHS: Record<string, number> = {
  ' ': 278,
  ',': 278,
  '.': 278,
  '-': 333,
  '+': 584,
  F: 611,
  C: 722,
  A: 667,
};

/** Caractères hors Latin-1 ramenés à leur code WinAnsi (ou à un équivalent). */
const WIN_ANSI: Record<string, number> = {
  '€': 0x80,
  '‚': 0x82,
  '„': 0x84,
  '…': 0x85,
  '‘': 0x91,
  '’': 0x92,
  '“': 0x93,
  '”': 0x94,
  '•': 0x95,
  '–': 0x96,
  '—': 0x97,
  œ: 0x9c,
  Œ: 0x8c,
  ' ': 0x20,
  ' ': 0x20,
};

function encode(text: string): Buffer {
  const bytes: number[] = [];
  for (const char of text) {
    const mapped = WIN_ANSI[char];
    const code = char.codePointAt(0) ?? 0x3f;
    const byte = mapped ?? (code >= 0x20 && code <= 0xff ? code : 0x3f);
    // Parenthèses et barre oblique inverse sont échappées dans une chaîne PDF.
    if (byte === 0x28 || byte === 0x29 || byte === 0x5c) bytes.push(0x5c);
    bytes.push(byte);
  }
  return Buffer.from(bytes);
}

export function textWidth(text: string, size: number): number {
  let units = 0;
  for (const char of text) units += WIDTHS[char] ?? 556;
  return (units / 1000) * size;
}

export interface TextOptions {
  size?: number;
  bold?: boolean;
  /** Alignement à droite sur x. */
  alignRight?: boolean;
  gray?: boolean;
}

export class PdfDocument {
  private readonly pages: Buffer[][] = [];
  private current: Buffer[] = [];

  constructor() {
    this.addPage();
  }

  get width(): number {
    return PAGE_WIDTH;
  }

  get height(): number {
    return PAGE_HEIGHT;
  }

  addPage(): void {
    this.current = [];
    this.pages.push(this.current);
  }

  /** Texte dont la ligne de base est à `y` (origine en haut de page). */
  text(x: number, y: number, value: string, options: TextOptions = {}): void {
    const size = options.size ?? 9;
    const left = options.alignRight ? x - textWidth(value, size) : x;
    const color = options.gray ? '0.45 g ' : '0 g ';
    this.current.push(
      Buffer.from(
        `BT ${color}/${options.bold ? 'F2' : 'F1'} ${size} Tf ${left.toFixed(2)} ${(PAGE_HEIGHT - y).toFixed(2)} Td (`,
        'latin1',
      ),
      encode(value),
      Buffer.from(') Tj ET\n', 'latin1'),
    );
  }

  line(x1: number, y1: number, x2: number, y2: number, width = 0.5): void {
    this.current.push(
      Buffer.from(
        `${width} w 0.6 G ${x1.toFixed(2)} ${(PAGE_HEIGHT - y1).toFixed(2)} m ${x2.toFixed(2)} ${(PAGE_HEIGHT - y2).toFixed(2)} l S\n`,
        'latin1',
      ),
    );
  }

  /** Assemble le fichier : objets, table des références croisées, en-queue. */
  render(): Buffer {
    const objects: Buffer[] = [];
    const pageIds: number[] = [];
    // 1 catalogue, 2 arbre des pages, 3-4 polices, puis page et contenu pour chaque page.
    const fontRegular = 3;
    const fontBold = 4;
    this.pages.forEach((_, index) => pageIds.push(5 + index * 2));
    objects[1] = Buffer.from('<< /Type /Catalog /Pages 2 0 R >>', 'latin1');
    objects[2] = Buffer.from(
      `<< /Type /Pages /Kids [${pageIds.map((id) => `${id} 0 R`).join(' ')}] /Count ${pageIds.length} >>`,
      'latin1',
    );
    objects[fontRegular] = Buffer.from(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
      'latin1',
    );
    objects[fontBold] = Buffer.from(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
      'latin1',
    );
    this.pages.forEach((content, index) => {
      const pageId = 5 + index * 2;
      const contentId = pageId + 1;
      const stream = Buffer.concat(content);
      objects[pageId] = Buffer.from(
        `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${PAGE_WIDTH} ${PAGE_HEIGHT}] ` +
          `/Resources << /Font << /F1 ${fontRegular} 0 R /F2 ${fontBold} 0 R >> >> /Contents ${contentId} 0 R >>`,
        'latin1',
      );
      objects[contentId] = Buffer.concat([
        Buffer.from(`<< /Length ${stream.length} >>\nstream\n`, 'latin1'),
        stream,
        Buffer.from('\nendstream', 'latin1'),
      ]);
    });

    const chunks: Buffer[] = [Buffer.from('%PDF-1.4\n%\xe2\xe3\xcf\xd3\n', 'latin1')];
    let offset = chunks[0]?.length ?? 0;
    const offsets: number[] = [];
    for (let id = 1; id < objects.length; id += 1) {
      const body = objects[id] ?? Buffer.from('null', 'latin1');
      const chunk = Buffer.concat([
        Buffer.from(`${id} 0 obj\n`, 'latin1'),
        body,
        Buffer.from('\nendobj\n', 'latin1'),
      ]);
      offsets[id] = offset;
      chunks.push(chunk);
      offset += chunk.length;
    }
    const xref = [
      'xref',
      `0 ${objects.length}`,
      '0000000000 65535 f ',
      ...offsets.slice(1).map((value) => `${String(value).padStart(10, '0')} 00000 n `),
      'trailer',
      `<< /Size ${objects.length} /Root 1 0 R >>`,
      'startxref',
      String(offset),
      '%%EOF',
      '',
    ].join('\n');
    chunks.push(Buffer.from(xref, 'latin1'));
    return Buffer.concat(chunks);
  }
}
