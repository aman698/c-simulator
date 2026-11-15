import fs from 'node:fs';
import path from 'node:path';
import { ROOT } from '../../server/paths.js';

/**
 * Apply a `--cc <path|gcc|clang>` command-line option by setting process.env.CC
 * (read by server/judge/toolchain.js). On Windows, `gcc`/`clang` resolve to the
 * project-local MSYS2 toolchains installed by scripts/setup_windows_toolchain.js.
 */
export function applyCcOption(argv) {
  const i = argv.indexOf('--cc');
  if (i < 0 || !argv[i + 1]) return;
  const name = argv[i + 1];
  const local = { gcc: ['ucrt64', 'gcc.exe'], clang: ['clang64', 'clang.exe'] }[name];
  if (local && process.platform === 'win32') {
    const p = path.join(ROOT, '.toolchain', 'msys64', local[0], 'bin', local[1]);
    if (fs.existsSync(p)) {
      process.env.CC = p;
      return;
    }
  }
  process.env.CC = name;
}
