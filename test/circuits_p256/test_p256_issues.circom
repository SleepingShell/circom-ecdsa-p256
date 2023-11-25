pragma circom 2.1.5;

//include "../../circuits/p256_utils.circom";
//include "../../circuits/bigint.circom";
//include "../../circuits/bigint_4x64_mult.circom";
include "../../circuits/circom-pairing/circuits/bigint.circom";

template TestPrimeRed() {
  signal input in[10];
  signal output out[4];

  component reduce_component = PrimeReduce(64, 4, 6, [18446744073709551615,4294967295,0,18446744069414584321], 64);
  reduce_component.in <== in;
  out <== reduce_component.out;
  log("===output===");
  for (var i = 0; i < 4; i++) {
    log(out[i]);
  }
}

template TestPrimeRed32() {
  signal input in[8];
  signal output out[8];

  component reduce_component = PrimeReduce(32, 8, 0, [4294967295, 4294967295, 4294967295, 0, 0, 0, 1, 4294967295], 32);
  reduce_component.in <== in;
  out <== reduce_component.out;
  log("===output===");
  for (var i = 0; i < 8; i++) {
    log(out[i]);
  }
}

component main = TestPrimeRed();