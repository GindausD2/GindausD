import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import { createHandler } from './handler.mjs';
import { pathToFileURL } from 'node:url';

export function createMaxServer({ handle = createHandler() } = {}) {
return createServer(async (req, res) => {
  const controller = new AbortController();
  res.on('close', () => { if (!res.writableEnded) controller.abort(); });
  try {
    const request = new Request('http://localhost' + req.url, { method: req.method, headers: req.headers, body: ['GET', 'HEAD'].includes(req.method) ? undefined : Readable.toWeb(req), duplex: 'half', signal: controller.signal });
    const response = await handle(request);
    res.writeHead(response.status, Object.fromEntries(response.headers));
    if (!response.body) return res.end();
    for await (const chunk of response.body) {
      if (controller.signal.aborted) break;
      if (!res.write(chunk)) await new Promise(resolve => {
        const finish = () => { res.off('drain', finish); res.off('close', finish); resolve(); };
        res.once('drain', finish); res.once('close', finish);
      });
      if (controller.signal.aborted) break;
    }
    res.end();
  } catch { if (!res.headersSent) res.writeHead(500); res.end(); }
});
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  createMaxServer().listen(Number(process.env.PORT || 8787), '0.0.0.0', () => console.log('Max backend listening'));
}
