import { createRequire } from "module";
import { WebSocketServer } from "ws";
const require = createRequire(import.meta.url);
const fs = require("node:fs");
const http = require("node:http");
const { S3Client, PutObjectCommand, GetObjectCommand } = require("@aws-sdk/client-s3");
const LB_FILE = "leaderboard.json";
require("dotenv").config();

const s3 = new S3Client({
    region: process.env.AWS_REGION,
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    }
});

const hostname = "127.0.0.1";
const port = process.env.PORT || 8080;

let lb = {};
let lbmap = {};
let omap = {};
const allowedOrigins = {};
const DEVID = process.env.DEVID;
allowedOrigins["https://qbjs.org"] = 1;
allowedOrigins["https://boxgaming.github.io"] = 1;
allowedOrigins["http://localhost:8080"] = 1;

const server = http.createServer((req, res) => {
    console.log("URL: " + req.url);
    console.log("Method: " + req.method);
    console.log("Headers:");
    for (var h in req.headers) {
        console.log("    -> " + h + ": " + req.headers[h]);
    }
    console.log("-------------------------------------------------------");
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain');


    if (req.url.startsWith("/v0/gxs.bas")) {
        if (!checkOrigin(req, res)) { return; };

        fs.readFile("gxs-client-v0.bas", function (error, content) {
            if (error) {
                // TODO: probably should do some error handling
            }
            else {
                res.statusCode = 200;
                res.end(content);
            }
        });
    }
    else if (req.url.startsWith("/v0/lb")) {
        leaderboard(req, res);
    }
    else {
        res.end('Coming soon...\n');
    }

    function checkOrigin(req, res) {
        let origin = req.headers["origin"];
        let gid = req.headers["x-gid"];
        let board = lb[gid];
        console.log(origin + ":" + gid + ":" + board);

        if (req.method == "OPTIONS") {
            if (allowedOrigins[origin]) {
                res.setHeader("Access-Control-Allow-Origin", origin);
                res.setHeader("Access-Control-Allow-Headers", "Content-Type,X-GID,X-Restrict-To,X-DID");
            }
            res.end();
            return false;
        }

        if (board && board.restrictOrigin) {
            console.log("GOT HERE! " + board.restrictOrigin);
            if (origin == board.restrictOrigin) {
                res.setHeader("Access-Control-Allow-Origin", origin);
                res.setHeader("Access-Control-Allow-Headers", "Content-Type,X-GID");
            }
            else {
                res.statusCode = 200;
                res.end();
                return false;
            }
        }
        else if (origin == "https://boxgaming.github.io" || origin == "https://qbjs.org" || origin == "http://localhost:8080") {
            res.setHeader("Access-Control-Allow-Origin", origin);
            res.setHeader("Access-Control-Allow-Headers", "Content-Type,X-GID,X-Restrict-To,X-DID");
        }
        else {
            res.statusCode = 200;
            res.end();
            return false;
        }

        return true;
    }

    async function leaderboard(req, res) {
        if (!checkOrigin(req, res)) { console.log("check origin failed"); return; }

        if (req.url.endsWith("/register")) {
            let id = crypto.randomUUID();
            lb[id] = { scores: [] };
            lbmap[id] = {};
            res.end(id);
            console.log("register: " + id);
        }
        else if (req.url.endsWith("/restrict")) {
            let did = req.headers["x-did"];
            if (did != DEVID) {
                res.end();
                return;
            }
            let gid = req.headers["x-gid"];
            let rorigin = req.headers["x-restrict-to"];
            console.log("restrict: " + gid + " : " + rorigin);
            let board = lb[gid];
            if (board && rorigin) {
                board.restrictOrigin = rorigin;
                allowedOrigins[rorigin] = true;
                s3Save(LB_FILE, JSON.stringify(lb));
            }
            res.end();
        }
        else if (req.method == "GET") {
            let gid = req.headers["x-gid"];
            console.log("GET: " + gid);
            let board = lb[gid];
            if (board) {
                board.scores.sort((a, b) => b.score - a.score);
                res.end(JSON.stringify(board.scores));
            }
            else {
                res.end("{}");
            }
        }
        else if (req.method == "POST") {
            let gid = req.headers["x-gid"];
            console.log("POST: " + gid);
            let board = lb[gid];
            if (board) {
                let body = [];
                req.on("data", chunk => {
                    body += chunk;
                })
                    .on('end', () => {
                        try {
                            let s = JSON.parse(body);
                            var entry = lbmap[gid][s.name];
                            if (entry) {
                                if (s.score > entry.score) {
                                    entry.score = s.score;
                                    entry.ts = Date.now();
                                }
                            }
                            else {
                                s.ts = Date.now();
                                board.scores.push(s);
                                lbmap[gid][s.name] = s;
                            }
                            res.end("OK");
                            s3Save(LB_FILE, JSON.stringify(lb));
                        }
                        catch (e) {
                            console.log(e);
                            res.end("");
                        }
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
});


async function s3Save(filename, text) {
    const params = {
        Bucket: process.env.S3_BUCKET,
        Key: process.env.S3_ROOT + filename,
        Body: text,
        ContentType: "text/plain"
    };

    await s3.send(new PutObjectCommand(params));
}

async function s3Load(filename) {
    const params = {
        Bucket: process.env.S3_BUCKET,
        Key: process.env.S3_ROOT + filename
    };

    var response = await s3.send(new GetObjectCommand(params));
    return await response.Body.transformToString();
}

async function init() {
    try {
        var lbtext = await s3Load(LB_FILE);
        lb = JSON.parse(lbtext);
        for (var key in lb) {
            lbmap[key] = {};
            var board = lb[key];
            var scores = [];
            if (board.scores == undefined) {
                lb[key] = { "scores": board };
                scores = lb[key].scores;
            }
            else {
                scores = board.scores;
            }
            if (board.restrictOrigin) {
                allowedOrigins[board.restrictOrigin] = true;
                console.log("Adding origin: " + board.restrictOrigin);
            }
            for (var i = 0; i < scores.length; i++) {
                lbmap[key][scores[i].name] = scores[i];
            }
        }
        console.log(JSON.stringify(lb));
        console.log("--------------------------------------------------------------");
        console.log(JSON.stringify(lbmap));
    }
    catch (e) {
        console.log(e);
    }
}

await init();
server.listen(port, hostname, () => {
    console.log(`Server running at http://${hostname}:${port}/`);
});

const HOST = 1;
const CLIENT = 2;
const MSG_HOST_GAME = 1;
const MSG_JOIN_GAME = 2;
const MSG_HOST_DISCONNECTED = 3;
const MSG_CLIENT_DISCONNECTED = 4;
var sessions = {};

const wss = new WebSocketServer({ server });
wss.on("connection", function connection(ws) {

    ws.on("message", function message(data) {
        var msg = JSON.parse(data);
        if (msg.type == MSG_HOST_GAME) {
            var sid = crypto.randomUUID();
            var cid = crypto.randomUUID();
            ws.ctype = HOST;
            ws.sid = sid;
            ws.cid = cid;
            sessions[sid] = { host: ws, clients: { } };
            sessions[sid].clients[cid] = ws;
            msg.sid = sid;
            msg.cid = cid;
            ws.send(JSON.stringify(msg));
            console.log("New game started: " + sid);
        }
        else if (msg.type == MSG_JOIN_GAME) {
            var session = sessions[msg.sid];
            if (!session) {
                console.log("Session not found: " + msg.sid);
                return;
            }
            var cid = crypto.randomUUID();
            ws.ctype = CLIENT;
            ws.cid = cid;
            ws.sid = msg.sid;
            session.clients[cid] = ws;
            msg.cid = cid;
            ws.send(JSON.stringify(msg));
            session.host.send(JSON.stringify(msg));
            console.log(JSON.stringify(session.clients));
        }
        else {
            var session = sessions[msg.sid];
            if (!session) {
                console.log("Session not found: " + msg.sid);
                return;
            }
            if (msg.to == "HOST") {
                session.host.send(JSON.stringify(msg));
            }
            else {
                for (var cid in session.clients) {
                    if (!msg.to || msg.to == "" || msg.to == cid) {
                        session.clients[cid].send(JSON.stringify(msg));
                    }
                }
            }
        }
    });
    ws.on('close', () => {
        console.log('Client disconnected');
        console.log(ws.sid);
        var session = sessions[ws.sid];
        if (session) {
            var msg = {
                type: MSG_CLIENT_DISCONNECTED,
                sid: ws.sid,
                cid: ws.cid
            }
            if (ws == session.host) { msg.type = MSG_HOST_DISCONNECTED }
            delete session.clients[ws.cid];
            if (Object.keys(session.clients).length < 1) {
                console.log("All clients disconnected, removing session: " + ws.sid);
                delete session[ws.sid];
            }
            else {
                if (msg.type == MSG_HOST_DISCONNECTED) {
                    // promote the next available client to be the host
                    msg.hid = Object.keys(session.clients)[0];
                    session.host = session.clients[msg.hid];
                    session.host.ctype = HOST;
                }
                for (var cid in session.clients) {
                    console.log(JSON.stringify(msg));
                    session.clients[cid].send(JSON.stringify(msg));
                }    
            }
        }
    });
});

