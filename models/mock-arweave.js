const http = require('http');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
  const filePath = path.join(__dirname, req.url);

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('File not found');
      return;
    }

    const range = req.headers.range;
    if (!range) {
      res.writeHead(200, {
        'Content-Length': stats.size,
        'Content-Type': 'application/octet-stream',
      });
      fs.createReadStream(filePath).pipe(res);
    } else {
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : stats.size - 1;

      if (start >= stats.size || end >= stats.size || start > end) {
        res.writeHead(416, {
          'Content-Range': `bytes */${stats.size}`,
          'Content-Type': 'text/plain',
        });
        res.end('Requested Range Not Satisfiable');
        return;
      }

      console.log(`File ${filePath}  Range: ${start}-${end}/${stats.size}`);

      const chunkSize = (end - start) + 1;
      res.writeHead(206, {
        'Content-Range': `bytes ${start}-${end}/${stats.size}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunkSize,
        'Content-Type': 'application/octet-stream',
      });
      if (req.method === 'HEAD') {
        res.end();
      } else {
        const fileStream = fs.createReadStream(filePath, { start, end });
        fileStream.pipe(res);
      }
    }
  });
});

const port = 3000;
server.listen(port, () => {
  console.log(`Server is listening on port ${port}`);
});