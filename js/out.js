function main () {
  var _lbl = 0;
  var reg_0;
  var reg_1;
  var reg_2;
  var reg_3;
  var reg_4;
  var reg_5;
  var reg_6;
  var reg_7;
  var reg_8;
  var reg_9;
  var reg_10;
  var reg_11;
  var reg_12;
  var reg_13;
  var reg_14;
  var reg_15;
  var reg_16;
  var reg_17;
  var reg_18;
  var reg_19;
  var reg_20;
  var reg_21;
  var reg_22;
  while (_lbl !== null) {
  switch (_lbl) {
  case 0:
    reg_1 = 5
    reg_0 = reg_1;
  case 1:
    reg_2 = reg_0 > 0;
    if (!reg_2) {
      _lbl = 4; break;
    }
    reg_4 = " bottles"
    reg_3 = reg_4;
    reg_6 = 1
    reg_5 = reg_0 == reg_6;
    if (!reg_5) {
      _lbl = 2; break;
    }
    reg_7 = " bottle"
    reg_3 = reg_7;
    _lbl = 3; break;
  case 2:
  case 3:
    reg_9 = String(0);
    reg_8 = reg_9;
    reg_11 = reg_8 + reg_3;
    reg_12 = " of beer on the wall"
    reg_10 = reg_11 + reg_12;
    console.log(reg_10);
    reg_14 = reg_8 + reg_3;
    reg_15 = " of beer"
    reg_13 = reg_14 + reg_15;
    console.log(reg_13);
    reg_16 = "Take one down, pass it around"
    console.log(reg_16);
    reg_17 = reg_0 - 1;
    reg_0 = reg_17;
    reg_20 = String(0);
    reg_19 = reg_20 + reg_3;
    reg_21 = " of beer on the wall"
    reg_18 = reg_19 + reg_21;
    console.log(reg_18);
    reg_22 = ""
    console.log(reg_22);
    _lbl = 1; break;
  case 4:
    _lbl = null; break;
  }}
  return [];
}
main();
