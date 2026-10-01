import { mkdir, readFile, writeFile, rename } from 'node:fs/promises';
import { join } from 'node:path';
import { createHash } from 'node:crypto';

// Separate from transient jobs; never included in research exports.
export function reportStore(directory) {
  let tail = Promise.resolve();
  return (owner, body) => {
    const operation = tail.then(async () => {
      if (!body || Object.keys(body).sort().join(',') !== 'id,reason,text,version' ||
          body.version !== 1 || !/^[a-f0-9-]{36}$/.test(body.id) ||
          !['harmful', 'misleading', 'other'].includes(body.reason) ||
          typeof body.text !== 'string' || !body.text.trim() || body.text.length > 12000) {
        throw new Error('invalid_report');
      }
      await mkdir(directory, { recursive: true });
      const key = createHash('sha256').update(owner + ':' + body.id).digest('hex');
      const filename = join(directory, key + '.json');
      try {
        const previous = JSON.parse(await readFile(filename, 'utf8'));
        if (JSON.stringify(previous.report) !== JSON.stringify(body)) throw new Error('report_conflict');
        return;
      } catch (error) { if (error.code !== 'ENOENT') throw error; }
      const temporary = filename + '.pending';
      await writeFile(temporary, JSON.stringify({ receivedAt: new Date().toISOString(), report: body }), { mode: 0o600 });
      await rename(temporary, filename);
    });
    tail = operation.catch(() => {});
    return operation;
  };
}
