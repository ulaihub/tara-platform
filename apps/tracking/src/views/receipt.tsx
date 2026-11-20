import type { FC } from 'hono/jsx';
import type { PublicReceipt } from '../api.js';
import { formatAmount, formatClock, formatDate } from '../format.js';
import type { ReceiptStrings } from '../i18n.js';

/**
 * « Vérifier un reçu » (maquette Web-Verifier-Recu) : bouclier vert et ce qui est imprimé
 * sur le papier si le code signé est bon ; bouclier rouge sinon. Rien d'autre n'est montré.
 */
export const ReceiptPage: FC<{ receipt: PublicReceipt | null; t: ReceiptStrings }> = ({
  receipt,
  t,
}) => {
  const valid = receipt !== null;
  const when = (iso: string) => t.at(formatDate(iso), formatClock(iso));
  return (
    <div class="verify">
      <section class={valid ? 'seal ok' : 'seal bad'} role="status">
        <span class="shield" aria-hidden="true">
          <span class="halo" />
          <span class="disc">
            <svg width="42" height="42" viewBox="0 0 24 24">
              <path d="M12 3l7 3v5c0 4.5-3 8.3-7 10-4-1.7-7-5.5-7-10V6z" />
            </svg>
          </span>
        </span>
        <h1>{valid ? t.validTitle : t.invalidTitle}</h1>
        <p>{valid ? t.validBody : t.invalidBody}</p>
      </section>
      {receipt ? (
        <dl class="card facts">
          <div>
            <dt>{t.number}</dt>
            <dd>{t.numberValue(receipt.reference)}</dd>
          </div>
          <div>
            <dt>{t.issued}</dt>
            <dd>{when(receipt.issuedAt)}</dd>
          </div>
          {receipt.senderName ? (
            <div>
              <dt>{t.sender}</dt>
              <dd>{receipt.senderName}</dd>
            </div>
          ) : null}
          <div>
            <dt>{t.recipient}</dt>
            <dd>
              {[receipt.recipientName, receipt.dropoffNeighborhood].filter(Boolean).join(' · ')}
            </dd>
          </div>
          <div>
            <dt>{t.fee}</dt>
            <dd>
              {formatAmount(receipt.fee)} · {receipt.feePaid ? t.paid : t.unpaid}
            </dd>
          </div>
          {receipt.deliveredAt ? (
            <div>
              <dt>{t.delivered}</dt>
              <dd>{when(receipt.deliveredAt)}</dd>
            </div>
          ) : receipt.status === 'CANCELLED' ? (
            <div>
              <dt>{t.cancelled}</dt>
              <dd>–</dd>
            </div>
          ) : null}
          {receipt.collectedForSender ? (
            <div>
              <dt>{t.collected}</dt>
              <dd>{formatAmount(receipt.collectedForSender)}</dd>
            </div>
          ) : null}
        </dl>
      ) : null}
      <p class="hint">{t.note}</p>
    </div>
  );
};
