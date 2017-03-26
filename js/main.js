
const compiler = require("./compiler.js");
const fs = require("fs");

var filename = process.argv[2];
var buffer = fs.readFileSync(filename);

var parsed = compiler.parse(buffer);
var result = compiler.compile(parsed);

if (process.argv[3]) {
  var filename = process.argv[3];
  outfile = fs.writeFileSync(filename, result);
} else {
  console.log(result)
}
