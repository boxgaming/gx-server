const http = require('node:http');

const hostname = '127.0.0.1';
const port = process.env.PORT || 8080;

const data = {};
const lb = {};

const server = http.createServer((req, res) => {
  console.log("URL: " + req.url);
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');

  /*if (req.url.startsWith("/v0/scs/")) {
    scs(req.url.substring(8), req, res);
    //console.log(req.method + ":" + req.url);
  }
  else */
  if (req.url.startsWith("/v0/lb")) {
    leaderboard(req, res);
  }
  else {
    res.end('Coming soon...\n');
  }

  function leaderboard(req, res) {
    console.log("leaderboard: " + req.url);
    console.log("method: " + req.method);
    console.log("headers");
    for (h in req.headers) {
      console.log(" -> " + h + ": " + req.headers[h]);
    }
    let origin = req.headers["origin"];
    if (origin == "http://localhost:8888" || origin == "https://qbjs.org") {
      res.setHeader("Access-Control-Allow-Origin", origin);
      res.setHeader("Access-Control-Allow-Headers", "Content-Type,X-GID");
    }
    else {
      res.end("");
      return;
    }
    if (req.url.endsWith("/register")) {
      let id = crypto.randomUUID();
      lb[id] = [];
      res.end(id);
    }
    else if (req.method == "GET") {
      console.log("GET section ------------------------");
      let gid = req.headers["x-gid"];
      console.log(gid);
      let board = lb[gid];
      if (board) {
        board.sort((a, b) => b.score - a.score);
        res.end(JSON.stringify(board));
      }
      else {
        res.end("{}");
      }
    }
    else if (req.method == "POST") {
      console.log("POST section ------------------------");
      let gid = req.headers["x-gid"];
      console.log(gid);
      let board = lb[gid];
      console.log("board:" + board)
      if (board) {
        let body = [];
        req.on("data", chunk => {
          body += chunk;
        })
        .on('end', () => {
          console.log("body:" + body);
          try {
            let s = JSON.parse(body);
            board.push(s);
            req.end("OK");
          }
          catch (e) {
            console.log(e);
            res.end("");
          }
          //body = Buffer.concat(body);
        });
      }
      else {
        res.end("");
      }
    }
    else {
      res.end("");
    }
  }

  function scs(action, req, res) {
    console.log(action);
    res.setHeader("Access-Control-Allow-Origin", "http://localhost:8888");
    if (action.startsWith("register")) {
      let id = crypto.randomUUID();
      data[id] = new Uint8Array(0);
      res.end(id);
    }
    else {
      let body = [];
      req.on("data", chunk => {
          body.push(chunk);
        })
        .on('end', () => {
          console.log("body:" + body);
          body = Buffer.concat(body);
          if (req.method == "POST") {
            data[action] = body;
            res.end("OK");
          }
          else {
            let result = data[action];
            console.log(result);
            if (result == undefined) {
              result = "";
            }
            res.setHeader("Content-Type", "application/octet-stream");
            res.setHeader("Content-Length", result.length);
            res.end(result);
        }
      });
    }
  }
});

server.listen(port, hostname, () => {
  console.log(`Server running at http://${hostname}:${port}/`);
});