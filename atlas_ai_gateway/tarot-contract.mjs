import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { exact } from './contract.mjs';

const bytes = readFileSync(new URL('../atlas_contribution_app/assets/tarot-prompt-v1.json', import.meta.url));
export const tarotPrompt = JSON.parse(bytes);
export const tarotPromptHash = createHash('sha256').update(bytes).digest('hex');
export const tarotContextVersion = 'atlas-tarot-context-v1';
const catalog = new Map(JSON.parse(readFileSync(new URL('../atlas_contribution_app/assets/tarot/catalog-v1.json', import.meta.url))).map(card => [card.id, card]));

export function validateTarotContext(context) {
  exact(context, ['version', 'language', 'spread', 'cards']);
  if (context.version !== tarotContextVersion || context.language !== 'tr' || !['daily', 'three'].includes(context.spread)) throw new Error('invalid_tarot');
  const positions = context.spread === 'three' ? ['Geçmiş', 'Şimdi', 'Olası Yön'] : ['Günlük Odak'];
  if (!Array.isArray(context.cards) || context.cards.length !== positions.length) throw new Error('invalid_tarot');
  const ids = new Set();
  context.cards.forEach((card, i) => {
    exact(card, ['id', 'name', 'position', 'orientation', 'themes']);
    const canonical = catalog.get(card.id);
    if (!canonical || ids.has(card.id) || card.name !== canonical.ad || card.position !== positions[i] || !['upright', 'reversed'].includes(card.orientation)) throw new Error('invalid_tarot');
    ids.add(card.id);
    const themes = canonical[card.orientation === 'reversed' ? 'ters_temalar' : 'duz_temalar'];
    if (JSON.stringify(card.themes) !== JSON.stringify(themes)) throw new Error('invalid_tarot');
  });
}

export function tarotMessages(context, noThink) {
  return [{ role: 'system', content: tarotPrompt.system },
    { role: 'user', content: `${tarotPrompt[context.spread]}\n${JSON.stringify(context)}${noThink ? '\n/no_think' : ''}` }];
}

export function tarotQualityError(text, finish, context) {
  const words = typeof text === 'string' && text.trim() ? text.trim().split(/\s+/u).length : 0;
  if (finish !== 'stop' || words < (context.spread === 'three' ? 40 : 20) || words > 900) return 'incomplete';
  return /<\/?think|analysis:|reasoning:|```|\b(system|assistant)\s*:/iu.test(text) ? 'reasoning' : null;
}
