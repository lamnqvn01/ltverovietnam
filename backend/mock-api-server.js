import { createServer } from 'node:http';
import worker from './worker.js';

const port = Number(process.env.PORT || 8787);

const server = createServer(async (incoming, outgoing) => {
  try {
    const request = new Request(new URL(incoming.url || '/', `http://${incoming.headers.host || '127.0.0.1'}`), {
      method: incoming.method || 'GET',
      headers: incoming.headers
    });
    const response = await worker.fetch(request, {});
    outgoing.writeHead(response.status, Object.fromEntries(response.headers));
    outgoing.end(await response.text());
  } catch (error) {
    outgoing.writeHead(500, { 'content-type': 'application/json; charset=utf-8' });
    outgoing.end(JSON.stringify({ error: error.message }));
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Mock API test server: http://127.0.0.1:${port}/api/test/semantic-scholar/papers`);
});