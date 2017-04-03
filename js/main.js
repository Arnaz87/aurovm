
const compiler = require("./compiler.js");
const fs = require("fs");

function manual () {
  console.log("Usage: bin/js <input file> [output file]");
  process.exit();
}

if (process.argv.length < 3) { manual() }
var filename = process.argv[2];

if ( !fs.existsSync(filename) ) {
  console.log(filename + " is not a valid file");
  manual();
}

var buffer = fs.readFileSync(filename);

var parsed = compiler.parse(buffer);
var result = compiler.compile(parsed);

if (process.argv[3]) {
  var filename = process.argv[3];
  outfile = fs.writeFileSync(filename, result);
} else {
  console.log(result)
}
