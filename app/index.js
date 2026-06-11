// app/index.js
const http = require('http');
const server = http.createServer((req, res) => {
  res.end('Hello DevOps003! 我的第一个ECS服务跑通了！🎉\n');
});
server.listen(3000, () => console.log('服务启动成功，监听3000端口'));
