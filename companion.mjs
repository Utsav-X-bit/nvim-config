import { createHash } from 'node:crypto';
import { lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { basename, dirname, join } from 'node:path';
import { createInterface } from 'node:readline';

const root = realpathSync(process.argv[2]);
const artifactDir = join(root, '.cph');
const maxBytes = 8 * 1024 * 1024;
const batches = new Map();
const pending = new Map();
let sequence = 0;
const emit = (event, fields = {}) => console.log(JSON.stringify({ event, ...fields }));
const slug = (text) => text.normalize('NFKD').replace(/\p{M}/gu, '').replace(/[^a-z0-9-]+/gi, '_').replace(/^_+|_+$/g, '').slice(0, 100);
const hash = (text, algorithm) => createHash(algorithm).update(text).digest('hex');
const letter = (index) => index < 26 ? String.fromCharCode(65 + index) : letter(Math.floor(index / 26) - 1) + letter(index % 26);
const problemLabel = (name) => name?.match(/^([A-Z]\d*)\s*[.\-:–—]\s+/i)?.[1]?.toUpperCase();

function problemUrl(url, name) {
  const { hostname, pathname } = new URL(url);
  const path = pathname.replace(/\/+$/, '');
  if (/(^|\.)codeforces\.(com|es|ml|net)$/.test(hostname)) {
    const contest = path.match(/\/(contest|gym)\/(\d+)(?:\/problem\/([A-Z]\d*))?(?:\/problems)?$/i);
    const practice = path.match(/^\/problemset\/(problem|gymProblem)\/(\d+)\/([A-Z]\d*)$/i);
    const part = contest ?? practice;
    if (part) {
      const [, kind, id, urlLabel] = part;
      const label = urlLabel?.toUpperCase() ?? problemLabel(name);
      const pool = /gym/i.test(kind) ? 'gym' : 'contest';
      return { platform: 'codeforces', contestId: contest && id, practiceId: practice && id,
        label, key: `codeforces/${pool}/${id}/${label ?? String(name ?? '')}` };
    }
    return { platform: 'codeforces', key: `codeforces${path}` };
  }
  if (hostname === 'atcoder.jp') {
    const task = path.match(/^\/contests\/([\w-]+)\/tasks\/([\w-]+)$/);
    if (task) {
      const [, contestId, problemId] = task;
      const suffix = problemId.split('_').at(-1);
      return { platform: 'atcoder', contestId, label: /^(?:[a-z]\d*|\d+)$/i.test(suffix) ? suffix.toUpperCase() : undefined,
        key: `atcoder/${contestId}/${problemId}` };
    }
  }
  if (hostname === 'codechef.com' || hostname === 'www.codechef.com') {
    const task = path.match(/^\/(?:(\w[\w-]*)\/)?(?:problems|submit)\/([\w-]+)$/i);
    if (task) {
      const [, contestId, problemId] = task;
      return { platform: 'codechef', contestId: contestId && !/^practice$/i.test(contestId) ? contestId.toUpperCase() : undefined,
        key: `codechef/${problemId.toUpperCase()}` };
    }
  }
  return { contestId: path.match(/\/(?:contests?|gym)\/([\w-]+)(?:\/|$)/i)?.[1], key: hostname + path };
}

const metadataPath = (path) => join(artifactDir, `.${basename(path)}_${hash(path, 'md5')}.prob`);

function existingSource(key, folder) {
  const matches = [];
  const legacy = [];
  for (const entry of readdirSync(artifactDir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.prob')) continue;
    const metadata = join(artifactDir, entry.name);
    let saved;
    try {
      saved = JSON.parse(readFileSync(metadata, 'utf8'));
      if (problemUrl(saved.url, saved.name).key !== key) continue;
    } catch {
      continue;
    }
    const path = saved.srcPath;
    if (typeof path !== 'string' || !path.startsWith(`${root}/`) || !path.endsWith('.cpp') ||
        metadataPath(path) !== metadata || !lstatSync(path, { throwIfNoEntry: false })?.isFile() ||
        realpathSync(path) !== path) continue;
    if (dirname(path) === folder) matches.push(path);
    else if (!path.startsWith(`${root}/contest/`) && !path.startsWith(`${root}/practice/`)) legacy.push(path);
  }
  const candidates = matches.length ? matches : legacy;
  if (candidates.length > 1) throw new Error('Several existing solutions match this problem: ' + candidates.join(', '));
  return candidates[0];
}

function sourcePath(task) {
  const parsed = problemUrl(task.url, task.name);
  const [judge, round] = task.group.split(/ - (.*)/s);
  const platform = parsed.platform ?? (slug(judge).toLowerCase() || slug(new URL(task.url).hostname));
  const contest = parsed.contestId || task.batch.size > 1;
  const roundId = slug(parsed.contestId ?? parsed.practiceId ?? round ?? '') || task.batch.id;
  const folder = contest ? join(root, 'contest', `${platform}_${roundId}`) : join(root, 'practice');
  const existing = existingSource(parsed.key, folder);
  if (existing) return existing;

  if (!contest) {
    const id = parsed.practiceId ? `${parsed.practiceId}${parsed.label}` : hash(parsed.key, 'sha256').slice(0, 8);
    const path = join(folder, `${platform}_${id}_${slug(task.name) || 'problem'}.cpp`);
    if (lstatSync(metadataPath(path), { throwIfNoEntry: false })) throw new Error(`Cannot determine ownership of ${path}`);
    return path;
  }

  const label = parsed.label ?? (platform !== 'codechef' && problemLabel(task.name));
  if (label) {
    const path = join(folder, `${label}.cpp`);
    if (lstatSync(metadataPath(path), { throwIfNoEntry: false })) throw new Error(`Cannot determine ownership of ${path}`);
    return path;
  }
  for (let i = 0; ; i++) {
    const path = join(folder, `${letter(i)}.cpp`);
    if (!lstatSync(path, { throwIfNoEntry: false }) && !lstatSync(metadataPath(path), { throwIfNoEntry: false })) return path;
  }
}

function createSource(srcPath, task) {
  for (const dir of [dirname(srcPath), artifactDir]) {
    mkdirSync(dir, { recursive: true });
    if (realpathSync(dir) !== dir) throw new Error(`Not writing through a symlink: ${dir}`);
  }
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

async function importTask(task) {
  const { url, name, group, batch, tests } = task ?? {};
  if (typeof name !== 'string' || !name.trim() || typeof group !== 'string' ||
      typeof url !== 'string' || !/^https?:\/\//i.test(url) || !URL.canParse(url) ||
      typeof batch?.id !== 'string' || !/^[a-z0-9-]{1,64}$/i.test(batch.id) ||
      !Number.isInteger(batch.size) || batch.size < 1 || batch.size > 500 ||
      !Array.isArray(tests) || !tests.every((test) => typeof test?.input === 'string' && typeof test.output === 'string')) {
    throw new Error('Invalid Competitive Companion task');
  }
  const batchState = batches.get(batch.id) ?? { files: new Set() };
  mkdirSync(artifactDir, { recursive: true });
  if (realpathSync(artifactDir) !== artifactDir) throw new Error(`Not writing through a symlink: ${artifactDir}`);
  const { path, created } = createSource(sourcePath(task), task);
  const id = ++sequence;
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error('Neovim did not finish saving the import'));
    }, 10_000);
    pending.set(id, (error) => {
      clearTimeout(timer);
      if (error) reject(new Error(error));
      else resolve();
    });
    emit('import', { id, path, metadata: metadataPath(path), task, created, open: batchState.files.size === 0 });
  });
  batchState.files.add(path);
  clearTimeout(batchState.timer);
  if (batchState.files.size >= batch.size) {
    batches.delete(batch.id);
  } else {
    batchState.timer = setTimeout(() => batches.delete(batch.id), 120_000).unref();
    batches.set(batch.id, batchState);
  }
}

let imports = Promise.resolve();

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
    const task = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    const saved = imports.then(() => importTask(task));
    imports = saved.catch(() => {});
    await saved;
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
const replies = createInterface({ input: process.stdin });
replies.on('line', (line) => {
  const { id, error } = JSON.parse(line);
  const done = pending.get(id);
  if (!done) return;
  pending.delete(id);
  done(error);
});
replies.on('close', () => server.close());
