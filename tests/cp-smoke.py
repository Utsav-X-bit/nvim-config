"""Run with python3 ~/.config/nvim/tests/cp-smoke.py while port 27121 is free."""
import hashlib
import http.client
import json
import os
import socket
import subprocess
import tempfile
import time
import uuid
from pathlib import Path


def wait_for(check, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if check():
            return
        time.sleep(0.05)
    raise AssertionError('Timed out: ' + str(check))


def listening():
    with socket.socket() as sock:
        sock.settimeout(0.2)
        return sock.connect_ex(('127.0.0.1', 27121)) == 0


def send(url, name, group, tests, batch_id=None, size=1, origin='moz-extension://companion', status=200):
    task = dict(url=url, name=name, group=group, tests=tests, timeLimit=2000, memoryLimit=256,
                interactive=False, testType='single', input={'type': 'stdin'}, output={'type': 'stdout'},
                languages={'java': {'mainClass': 'Main', 'taskClass': 'TestTask'}},
                batch={'id': batch_id or str(uuid.uuid4()), 'size': size})
    conn = http.client.HTTPConnection('localhost', 27121, timeout=4)
    try:
        conn.request('POST', '/', json.dumps(task), {'Content-Type': 'application/json', 'Origin': origin})
        response = conn.getresponse()
        assert response.status == status, (name, response.status, status)
        response.read()
    finally:
        conn.close()


def smoke(root, server):
    nvim = ['nvim', '--server', str(server)]

    def remote(expr):
        return subprocess.check_output(nvim + ['--remote-expr', expr], text=True, timeout=5)

    def lua(expr):
        return remote(f'luaeval({json.dumps(expr)})')

    def metadata(source):
        return root / '.cph' / f'.{source.name}_{hashlib.md5(os.fsencode(source)).hexdigest()}.prob'

    def read_tests(file):
        return json.loads(metadata(file).read_text())['tests'] if metadata(file).exists() else []

    def buffers():
        return lua('vim.iter(vim.api.nvim_list_bufs()):filter(vim.api.nvim_buf_is_loaded)'
                   ':map(function(b) return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false), "\\n") end):join("\\n")')

    first = root / 'contest/codeforces_98765/A.cpp'
    second = first.with_name('B.cpp')
    samples = [{'input': '4\n', 'output': '8\n'}, {'input': '9\n', 'output': '18\n'}]
    batch = str(uuid.uuid4())
    round_url = 'https://codeforces.com/contest/98765/problem/'
    send(round_url + 'A', 'A. Double', 'Codeforces - Round', samples, batch, 2)
    send(round_url + 'B', 'B. Next', 'Codeforces - Round', samples, batch, 2)
    wait_for(lambda: read_tests(second) and remote('expand("%:p")').strip() == str(first))
    assert first.read_text() == (
        '/*\n * A. Double\n * Codeforces - Round\n'
        f' * {round_url}A\n * 2000 ms | 256 MB\n */\n\n'
    )
    assert json.loads(metadata(first).read_text())['srcPath'] == str(first)
    wait_for(lambda: remote('mode()').strip() == 'i')
    assert remote('line(".") == line("$") && col(".") == 1').strip() == '1'
    subprocess.run(nvim + ['--remote-send', 'cpt<Esc>'], check=True, timeout=5)
    wait_for(lambda: remote('getline("$")').strip() == 'cpt')
    remote('execute("undo")')

    solution = '#include <iostream>\nint main(){int x; std::cin >> x; std::cout << x * 2 << "\\n";}\n'
    first.write_text(solution)
    remote('execute("edit | Pretest run")')
    wait_for(lambda: 'Testcases 2/2' in buffers())
    lua('(function() local s=require("pretest.ui").get_session(); '
        'vim.api.nvim_buf_set_lines(s.bufs.expected,0,-1,false,{"8 ",""}) end)()')
    send(round_url + 'A', 'A. Double', 'Codeforces - Round', samples + [{'input': '11\n', 'output': '22\n'}])
    wait_for(lambda: len(read_tests(first)) == 3)
    assert read_tests(first)[0]['output'] == '8 \n' and first.read_text() == solution
    remote('execute("Pretest run")')
    wait_for(lambda: 'Testcases 3/3' in buffers())

    practice = root / 'practice/codeforces_4A_A_Watermelon.cpp'
    send('https://codeforces.com/problemset/problem/4/A', 'A. Watermelon', 'Codeforces - Round', samples)
    wait_for(lambda: read_tests(practice) and remote('expand("%:p")').strip() == str(practice))
    assert len(read_tests(first)) == 3
    atcoder = root / 'contest/atcoder_abc400/C.cpp'
    send('https://atcoder.jp/contests/abc400/tasks/abc400_c', 'C - Example', 'AtCoder - ABC 400', samples)
    wait_for(lambda: read_tests(atcoder) and remote('expand("%:p")').strip() == str(atcoder))
    wait_for(lambda: remote('mode()').strip() == 'i')
    subprocess.run(nvim + ['--remote-send', '<Esc>'], check=True, timeout=5)
    wait_for(lambda: remote('mode()').strip() == 'n')
    send('https://example.org/problem/1', 'Rejected', 'Test', samples, origin='https://example.org', status=403)
    assert list((root / 'practice').glob('*.cpp')) == [practice]

    remote('execute(' + json.dumps('edit ' + str(first)) + ')')
    (first.parent / 'input.txt').write_text('17\n')
    subprocess.run(nvim + ['--remote-send', '<Space>rr'], check=True, timeout=5)
    wait_for(lambda: any(line.strip() == '34' for line in buffers().splitlines()))
    print('Contest and practice auto-import, in-editor testcase preservation, 3/3 AC, and manual input verified.')


def reopen_existing(root, server):
    nvim = ['nvim', '--server', str(server), '--remote-expr']

    def remote(expr):
        return subprocess.check_output(nvim + [expr], text=True, timeout=5).strip()

    first = root / 'contest/codeforces_98765/A.cpp'
    solution = first.read_bytes()
    prob = root / '.cph' / f'.A.cpp_{hashlib.md5(os.fsencode(first)).hexdigest()}.prob'
    tests = json.loads(prob.read_text())['tests']
    url = 'https://codeforces.com/contest/98765/problem/A'
    wait_for(lambda: remote('&filetype') == 'neo-tree')
    send(url, 'A. Double', 'Codeforces - Round', tests)
    wait_for(lambda: remote('expand("%:p")') == str(first))
    assert remote('mode()') == 'n', 'Reopening an existing solution should not enter Insert mode'
    assert remote('tabpagenr("$")') == '1', 'Import opened a new tab instead of using the editor beside Neo-tree'
    assert remote('count(map(getwininfo(), \'getbufvar(v:val.bufnr, "&filetype")\'), "neo-tree")') == '1'

    # With no available editing window, keep the locked window and open a new tab.
    remote('execute("enew | setlocal winfixbuf")')
    send(url, 'A. Double', 'Codeforces - Round', tests)
    wait_for(lambda: remote('expand("%:p")') == str(first))
    assert remote('tabpagenr("$")') == '2'
    assert first.read_bytes() == solution and json.loads(prob.read_text())['tests'] == tests
    print('Existing problem reopened beside Neo-tree after restart; locked-window fallback preserved code and samples.')


if __name__ == '__main__':
    assert not listening(), 'Stop the existing Competitive Companion listener before testing.'
    config = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='cp-nvim-') as folder:
        home = Path(folder)
        root = home / 'Github/CompetitiveProgramming'
        root.mkdir(parents=True)
        server = home / 'nvim.sock'
        env = os.environ | dict(HOME=folder, XDG_CONFIG_HOME=str(config.parent),
                                XDG_DATA_HOME=os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')),
                                XDG_STATE_HOME=str(home / 'state'), XDG_CACHE_HOME=str(home / 'cache'))
        for cwd, args, check in (
            (root, [], smoke),
            (home, [str(root)], reopen_existing),
        ):
            with (home / 'nvim.log').open('w+') as log:
                editor = subprocess.Popen(['nvim', '--headless', '--listen', str(server), *args], cwd=cwd,
                                          env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=log)
                try:
                    wait_for(listening)
                    check(root, server)
                except Exception:
                    log.seek(0)
                    print(log.read())
                    raise
                finally:
                    if editor.poll() is None:
                        subprocess.run(['nvim', '--server', str(server), '--remote-send',
                                        '<C-\\><C-n><Esc>:qa!<CR>'], capture_output=True, timeout=5)
                        try:
                            editor.wait(timeout=3)
                        except subprocess.TimeoutExpired:
                            editor.terminate()
                            editor.wait(timeout=5)
                    wait_for(lambda: not listening())
