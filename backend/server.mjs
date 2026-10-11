import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import { createHandler } from './handler.mjs';
const handle = createHandler();
const server = createServer(async (req, res) => {
  const controller = new AbortController();
  res.on('close', () => { if (!res.writableEnded) controller.abort(); });
  try {
    const request = new Request('http://localhost' + req.url, { method: req.method, headers: req.headers, body: ['GET', 'HEAD'].includes(req.method) ? undefined : Readable.toWeb(req), duplex: 'half', signal: controller.signal });
    const response = await handle(request);
    res.writeHead(response.status, Object.fromEntries(response.headers));
    if (!response.body) return res.end();
    for await (const chunk of response.body) { if (!res.write(chunk)) await new Promise(resolve => { res.once('drain', resolve); res.once('close', resolve); }); if (controller.signal.aborted) break; }
    res.end();
  } catch { if (!res.headersSent) res.writeHead(500); res.end(); }
});
server.listen(Number(process.env.PORT || 8787), '0.0.0.0', () => console.log('Max backend listening'));
