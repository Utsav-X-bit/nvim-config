import { createHash } from 'node:crypto';
import { lstatSync, mkdirSync, realpathSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { basename, join } from 'node:path';

const root = realpathSync(process.argv[2]);
const artifactDir = join(root, '.cph');
const maxBytes = 8 * 1024 * 1024;
const batches = new Map();
const emit = (event, fields = {}) => console.log(JSON.stringify({ event, ...fields }));
const slug = (text) => text.normalize('NFKD').replace(/\p{M}/gu, '').replace(/[^a-z0-9-]+/gi, '_').replace(/^_+|_+$/g, '').slice(0, 100);
const hash = (text, algorithm) => createHash(algorithm).update(text).digest('hex');
const letter = (index) => index < 26 ? String.fromCharCode(65 + index) : letter(Math.floor(index / 26) - 1) + letter(index % 26);

function destination(task, index) {
  const { hostname, pathname } = new URL(task.url);
  const [judge, round] = task.group.split(/ - (.*)/s);
  const platform = slug(judge).toLowerCase() || slug(hostname);
  const label = task.name.match(/^([A-Z]\d{0,3})\s*[.\-:–—]\s+/i)?.[1];
  const cf = /(^|\.)codeforces\.(com|es|ml|net)$/.test(hostname);
  const cfContest = /\/(?:contest|gym)\/(\d+)(?:\/problem\/([A-Z]\d{0,3}))?(?:\/problems)?\/?$/i;
  const cfPractice = pathname.match(/^\/problemset\/(?:problem|gymProblem)\/(\d+)\/([A-Z]\d{0,3})\/?$/i);
  const [, contestId, problemId] = (cf ? pathname.match(cfContest) :
    hostname === 'atcoder.jp' ? pathname.match(/^\/contests\/([\w-]+)\/tasks\/[\w-]+_([A-Z]\d{0,3})\/?$/i) :
    hostname === 'www.codechef.com' || hostname === 'codechef.com' ? pathname.match(/^\/(?!practice\/|problems\/)([\w-]+)\/problems\/[\w-]+\/?$/i) :
    pathname.match(/\/(?:contests?|gym)\/([\w-]+)(?:\/|$)/i)) ?? [];

  if (contestId || task.batch.size > 1) {
    const roundId = slug(contestId ?? cfPractice?.[1] ?? round ?? '') || task.batch.id;
    const key = (problemId ?? label ?? cfPractice?.[2])?.toUpperCase();
    const stem = key ?? (task.batch.size > 1 ? letter(index) : slug(task.name) || 'A');
    return [join(root, 'contest', `${platform}_${roundId}`), `${stem}.cpp`];
  }
  const id = cf && cfPractice ? `${cfPractice[1]}${cfPractice[2].toUpperCase()}` : hash(hostname + pathname, 'sha256').slice(0, 8);
  return [join(root, 'practice'), `${platform}_${id}_${slug(task.name) || 'problem'}.cpp`];
}

function createSource(folder, filename, task) {
  for (const dir of [folder, artifactDir]) {
    mkdirSync(dir, { recursive: true });
    if (realpathSync(dir) !== dir) throw new Error(`Not writing through a symlink: ${dir}`);
  }
  const srcPath = join(folder, filename);
  try {
    const limits = [
      Number.isFinite(task.timeLimit) && task.timeLimit > 0 ? `${task.timeLimit} ms` : '',
      Number.isFinite(task.memoryLimit) && task.memoryLimit > 0 ? `${task.memoryLimit} MB` : '',
    ].filter(Boolean).join(' | ');
    const lines = [task.name, task.group, task.url, limits]
      .map((value) => value.replace(/\s+/g, ' ').trim().replaceAll('*/', '* /'))
      .filter(Boolean);
    writeFileSync(srcPath, `/*\n * ${lines.join('\n * ')}\n */\n\n`, { flag: 'wx' });
    return { path: srcPath, created: true };
  } catch (error) {
    if (error.code !== 'EEXIST' || !lstatSync(srcPath).isFile()) throw error;
  }
  return { path: srcPath, created: false };
}

function importTask(task) {
  const { url, name, group, batch, tests } = task ?? {};
  if (typeof name !== 'string' || !name.trim() || typeof group !== 'string' ||
      typeof url !== 'string' || !/^https?:\/\//i.test(url) || !URL.canParse(url) ||
      typeof batch?.id !== 'string' || !/^[a-z0-9-]{1,64}$/i.test(batch.id) ||
      !Number.isInteger(batch.size) || batch.size < 1 || batch.size > 500 ||
      !Array.isArray(tests) || !tests.every((test) => typeof test?.input === 'string' && typeof test.output === 'string')) {
    throw new Error('Invalid Competitive Companion task');
  }
  const batchState = batches.get(batch.id) ?? { files: new Set() };
  const [folder, filename] = destination(task, batchState.files.size);
  const { path, created } = createSource(folder, filename, task);
  const metadata = join(artifactDir, `.${basename(path)}_${hash(path, 'md5')}.prob`);
  emit('import', { path, metadata, task, created, open: batchState.files.size === 0 });
  batchState.files.add(path);
  clearTimeout(batchState.timer);
  if (batchState.files.size >= batch.size) {
    batches.delete(batch.id);
  } else {
    batchState.timer = setTimeout(() => batches.delete(batch.id), 120_000).unref();
    batches.set(batch.id, batchState);
  }
}

const server = createServer({ requestTimeout: 15_000, headersTimeout: 10_000 }, async (req, res) => {
  const origin = req.headers.origin;
  const size = Number(req.headers['content-length']);
  if (req.method !== 'POST' || req.url !== '/' ||
      !/^application\/json(?:;|$)/i.test(req.headers['content-type'] ?? '') ||
      (origin && !/^(?:chrome|moz)-extension:\/\//.test(origin))) {
    res.writeHead(403).end();
    return;
  }
  if (!Number.isSafeInteger(size) || size < 1 || size > maxBytes) {
    res.writeHead(413, { Connection: 'close' }).end();
    return;
  }
  try {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    importTask(JSON.parse(Buffer.concat(chunks).toString('utf8')));
    res.writeHead(200).end();
  } catch (error) {
    emit('error', { message: error.message });
    res.writeHead(error.code ? 500 : 400).end();
  }
});
server.on('error', (error) => {
  emit('error', { message: error.code === 'EADDRINUSE' ? 'Port 27121 is busy. Close VS Code or the other listener, then run :CPListen.' : error.message });
  process.exitCode = 1;
  process.stdin.pause();
});
server.listen(27121, '127.0.0.1', () => emit('ready'));
process.stdin.resume();
process.stdin.on('end', () => server.close());
