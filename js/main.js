
const Compiler = require("./compiler.js");
const fs = require("fs");

var filename = process.argv[2];
var data = fs.readFileSync(filename);

var pos = 0;
function nextByte () {
  if (pos >= data.length) { return null; }
  return data.readUInt8(pos++);
}

var writeLine;
var outfile;

if (process.argv[3]) {
  var filename = process.argv[3];
  outfile = fs.openSync(filename, "w");
  writeLine = function (line) { fs.writeSync(outfile, line + "\n"); }
} else {
  writeLine = function (line) { console.log(line); }
}

var compiler = new Compiler(nextByte, writeLine);

compiler.parse();

compiler.compile();

if (outfile !== undefined) {
  fs.closeSync(outfile);
}

