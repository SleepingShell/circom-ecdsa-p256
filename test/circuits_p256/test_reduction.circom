pragma circom 2.1.5;

include "../../circuits_p256/p256_utils.circom";
include "../../circuits_p256/bigint.circom";
include "../../circuits_p256/bigint_4x64_mult.circom";

template CheckCubicModPIsZero2(m) {
    assert(m < 206); // since we deal with up to m+34 bit, potentially negative registers

    signal input in[10];

    log("==CheckCubicMod==");
    for (var i=0; i<10; i++) { // should be at most 200-bit registers
        log(in[i]);
    }

    log(111);

    // the p256 field size in (32,8)-rep
    signal p[8];
    var p_32_8[100] = get_p256_prime(32, 8);
    for (var i=0; i<8; i++) {
        p[i] <== p_32_8[i];
        log(p[i]);
    }


    // now, we compute a positive number congruent to `in` expressible in *8* overflowed registers.
    // for this representation, individual registers are allowed to be negative, but the final number
    // will be nonnegative overall.
    // first, we apply the p256 10-register reduction technique to reduce to *8* registers. this may result
    // in a negative number overall, but preserves congruence mod p.
    // our intermediate result is z = p256reduce(in)
    // second, we add a big multiple of p to z, to ensure that our final result is positive. 
    // since the registers of z are m + 34 bits, its max abs value is 2^(m+34 + 224) + 2^(m+34 + 192) + 2^(m+34 + 160) + ...
    //      < 2^(m+258)
    // so we add p * 2^(m+6) = (2^256-2^224 + eps) * 2^(m+6), which is a bit under 2^(m+262) and larger than |z| < 8 * 2^(m+34 + 224) = 2^(m+34 + 224 + 3) = 2^(m+261)

    // notes:
    // what if we just didn't reduce any registers? like why are we reducing the input at all if all we're doing is long division? then
    //      in < 2^(m + 64*9) + ... < 2^(m + 64*9)*10...

    signal reduced[8];

    component p256Reducer = P256PrimeReduce10Registers(); // (32, 8)
    for (var i = 0; i < 10; i++) {
        p256Reducer.in[i] <== in[i];
    }

    log("=0=");

    for (var i = 0; i < 8; i++) {
        log(p256Reducer.out[i]);
    }

    log(222);

    // var temp2[100] = getProperRepresentation(m + 53, 32, 8, p256Reducer.out);
    // log("===proper2====");
    // var proper2[16];
    // for (var i = 0; i<16; i++) {
    //     proper2[i] = temp2[i];
    //     log(proper2[i]);
    // }
    
    // also compute P as (32, 8) rep to add - multiple should still be the same since value stays same

    // FIXME Seems the 10reduction has 32-bits of overflow...although the reduction output is 2^254 instead of 2^232..
    // But the //max(m+32,..) line seems to indicate that the reduction has 34-bits of overflow
    signal multipleOfP[8];
    for (var i = 0; i < 8; i++) {
        multipleOfP[i] <== p[i] * (1 << (m+6)); // m + 6 + 32 = m+38 bits
    }

    // reduced becomes (32, 8)
    for (var i = 0; i < 8; i++) {
        reduced[i] <== p256Reducer.out[i] + multipleOfP[i]; // max(m+34, m+38) + 1 = m+39 bits
    }

    for (var i = 0; i < 8; i++) {
        log(reduced[i]);
    }
    
    log(333);

    // now we compute the quotient q, which serves as a witness. we can do simple bounding to show
    // q := reduced / P < (p256Reducer + multipleofP) / 2^255 < (2^(m+262) + 2^(m+261)) / 2^255 < 2^(m+8)
    // so the expected quotient q is always expressive in *7* 32-bit registers (i.e. < 2^224)
    // as long as m < 216 (and we only ever call m < 200)
    signal q[7];

    // getProperRepresentation(m, n, k, in) spec:
    // m bits per overflowed register (values are potentially negative)
    // n bits per properly-sized register
    // in has k registers
    // out has k + ceil(m/n) - 1 + 1 registers. highest-order potentially negative,
    // all others are positive
    // - 1 since the last register is included in the last ceil(m/n) array
    // + 1 since the carries from previous registers could push you over
    // TODO: need to check if largest register of proper is negative
    
    // FIXME The biggest register in reduced is ~2^254 . Therefore m+ 39 is wrong
    //          okay make real value doesn't matter...the 10reduce should only add 32-bits of overflow. 32+6+1 = 39
    //var temp[100] = getProperRepresentation(m + 39, 32, 8, reduced); // SOME ERROR HERE

    var temp[100] = getProperRepresentation(m + 53, 32, 8, reduced);
    log("===proper====");
    var proper[16];
    for (var i = 0; i<16; i++) {
        proper[i] = temp[i];
        log(proper[i]);
    }

    // Running evaluate on proper (my fix) and reduced shows equivalence in python
    // Although it seems that running with 39 also works..?

    log("===end proper====");

    // long_div(n, k, m, a, b) spec:
    // n bits per register
    // a has k + m registers
    // b has k registers
    // out[0] has length m + 1 -- quotient
    // out[1] has length k -- remainder
    // implements algorithm of https://people.eecs.berkeley.edu/~fateman/282/F%20Wright%20notes/week4.pdf
    // b[k-1] must be nonzero!
    var qVarTemp[2][100] = long_div(32, 8, 8, proper, p); // ERROR HERE 
    for (var i = 0; i < 7; i++) {
        q[i] <-- qVarTemp[0][i];
        log(q[i]);
    }

    // FIXME: I commented the below and uncommented the above
    //var qVarTemp[7] = [0, 0, 0, 0, 813694976, 2338053171, 2054]; // try hardcoding expected q in?
    // for (var i = 0; i < 7; i++) {
    //     q[i] <-- qVarTemp[i];
    //     log(q[i]);
    // }


    // we need to constrain that q is in proper (7x32) representation
    component qRangeChecks[7];
    for (var i = 0; i < 7; i++) {
        qRangeChecks[i] = Num2Bits(32);
        qRangeChecks[i].in <== q[i];
    }

    log(444);

    // now we compute a representation qpProd = q * p
    signal qpProd[14];

    // template BigMultNoCarry(n, ma, mb, ka, kb) spec:
    // a and b have n-bit registers
    // a has ka registers, each with NONNEGATIVE ma-bit values (ma can be > n)
    // b has kb registers, each with NONNEGATIVE mb-bit values (mb can be > n)
    // out has ka + kb - 1 registers, each with (ma + mb + ceil(log(max(ka, kb))))-bit values
    component qpProdComp = BigMultNoCarry(32, 32, 32, 7, 8); // qpProd = q*p
    for (var i = 0; i < 7; i++) {
        qpProdComp.a[i] <== q[i];
    }
    for (var i = 0; i < 8; i++) {
        qpProdComp.b[i] <== p[i];
    }
    for (var i = 0; i < 14; i++) {
        qpProd[i] <== qpProdComp.out[i]; // 67 bits
    }

    for (var i = 0; i < 14; i++) {
        log(qpProd[i]); // 67 bits
    }

    // log(444);
    // for (var i = 0; i < 26; i++) {
    //     log(qpProdComp.out[i]); // 67 bits
    // }


    log(555);

    // finally, check that qpProd == reduced
    // CheckCarryToZero(n, m, k) spec:
    // in[i] contains values in the range -2^(m-1) to 2^(m-1)
    // constrain that in[] as a big integer is zero
    // each limbs is n bits
    // FAILING HERE:
    component zeroCheck = CheckCarryToZero(32, m + 50, 14);
    for (var i = 0; i < 14; i++) {
        if (i < 8) { // reduced only has 8 registers
            zeroCheck.in[i] <== qpProd[i] - reduced[i]; // (m + 39) + 1 bits
            log(zeroCheck.in[i]);
        } else {
            zeroCheck.in[i] <== qpProd[i];
            log(zeroCheck.in[i]);
        }
    }

    log(666);

}

template AddUnequalCubicConstraint2() {
    signal input x1[4];
    signal input y1[4];
    signal input x2[4];
    signal input y2[4];
    signal input x3[4];
    signal input y3[4];

    signal x13[10]; // 197 bits
    component x13Comp = A3NoCarry();
    for (var i = 0; i < 4; i++) x13Comp.a[i] <== x1[i];
    for (var i = 0; i < 10; i++) x13[i] <== x13Comp.a3[i];

    signal x23[10]; // 197 bits
    component x23Comp = A3NoCarry();
    for (var i = 0; i < 4; i++) x23Comp.a[i] <== x2[i];
    for (var i = 0; i < 10; i++) x23[i] <== x23Comp.a3[i];

    signal x12x2[10]; // 197 bits
    component x12x2Comp = A2B1NoCarry();
    for (var i = 0; i < 4; i++) x12x2Comp.a[i] <== x1[i];
    for (var i = 0; i < 4; i++) x12x2Comp.b[i] <== x2[i];
    for (var i = 0; i < 10; i++) x12x2[i] <== x12x2Comp.a2b1[i];

    signal x1x22[10]; // 197 bits
    component x1x22Comp = A2B1NoCarry();
    for (var i = 0; i < 4; i++) x1x22Comp.a[i] <== x2[i];
    for (var i = 0; i < 4; i++) x1x22Comp.b[i] <== x1[i];
    for (var i = 0; i < 10; i++) x1x22[i] <== x1x22Comp.a2b1[i];

    signal x22x3[10]; // 197 bits
    component x22x3Comp = A2B1NoCarry();
    for (var i = 0; i < 4; i++) x22x3Comp.a[i] <== x2[i];
    for (var i = 0; i < 4; i++) x22x3Comp.b[i] <== x3[i];
    for (var i = 0; i < 10; i++) x22x3[i] <== x22x3Comp.a2b1[i];

    signal x12x3[10]; // 197 bits
    component x12x3Comp = A2B1NoCarry();
    for (var i = 0; i < 4; i++) x12x3Comp.a[i] <== x1[i];
    for (var i = 0; i < 4; i++) x12x3Comp.b[i] <== x3[i];
    for (var i = 0; i < 10; i++) x12x3[i] <== x12x3Comp.a2b1[i];

    signal x1x2x3[10]; // 197 bits
    component x1x2x3Comp = A1B1C1NoCarry();
    for (var i = 0; i < 4; i++) x1x2x3Comp.a[i] <== x1[i];
    for (var i = 0; i < 4; i++) x1x2x3Comp.b[i] <== x2[i];
    for (var i = 0; i < 4; i++) x1x2x3Comp.c[i] <== x3[i];
    for (var i = 0; i < 10; i++) x1x2x3[i] <== x1x2x3Comp.a1b1c1[i];

    signal y12[7]; // 130 bits
    component y12Comp = A2NoCarry();
    for (var i = 0; i < 4; i++) y12Comp.a[i] <== y1[i];
    for (var i = 0; i < 7; i++) y12[i] <== y12Comp.a2[i];

    signal y22[7]; // 130 bits
    component y22Comp = A2NoCarry();
    for (var i = 0; i < 4; i++) y22Comp.a[i] <== y2[i];
    for (var i = 0; i < 7; i++) y22[i] <== y22Comp.a2[i];

    signal y1y2[7]; // 130 bits
    component y1y2Comp = BigMultNoCarry(64, 64, 64, 4, 4);
    for (var i = 0; i < 4; i++) y1y2Comp.a[i] <== y1[i];
    for (var i = 0; i < 4; i++) y1y2Comp.b[i] <== y2[i];
    for (var i = 0; i < 7; i++) y1y2[i] <== y1y2Comp.out[i];

    for (var i=0; i<7; i++) {
        log(y1y2[i]);
    }
    
    log(11);
 
    // fail here
    component zeroCheck = CheckCubicModPIsZero2(200); // 200 bits per register
    for (var i = 0; i < 10; i++) {
        if (i < 7) {
            zeroCheck.in[i] <== x13[i] + x23[i] - x12x2[i] - x1x22[i] + x22x3[i] + x12x3[i] - 2 * x1x2x3[i] - y12[i] + 2 * y1y2[i] - y22[i];
        } else {
            zeroCheck.in[i] <== x13[i] + x23[i] - x12x2[i] - x1x22[i] + x22x3[i] + x12x3[i] - 2 * x1x2x3[i];
        }
    }

    log(22);
}

template Add(n, k) {
    assert(n == 64 && k == 4);

    signal input a[2][k];
    signal input b[2][k];

    signal output out[2][k];
    var x1[4];
    var y1[4];
    var x2[4];
    var y2[4];
    for(var i=0;i<4;i++){
        x1[i] = a[0][i];
        y1[i] = a[1][i];
        x2[i] = b[0][i];
        y2[i] = b[1][i];
    }

    var tmp[2][100] = p256_addunequal_func(n, k, x1, y1, x2, y2);
    for(var i = 0; i < k;i++){
        out[0][i] <-- tmp[0][i];
        out[1][i] <-- tmp[1][i];
    }

    log(1);

    // fail here
    component cubic_constraint = AddUnequalCubicConstraint2();
    for(var i = 0; i < k; i++){
        cubic_constraint.x1[i] <== x1[i];
        cubic_constraint.y1[i] <== y1[i];
        cubic_constraint.x2[i] <== x2[i];
        cubic_constraint.y2[i] <== y2[i];
        cubic_constraint.x3[i] <== out[0][i];
        cubic_constraint.y3[i] <== out[1][i];
    }

    // log(2);
    
    // component point_on_line = P256PointOnLine();
    // for(var i = 0; i < k; i++){
    //     point_on_line.x1[i] <== a[0][i];
    //     point_on_line.y1[i] <== a[1][i];
    //     point_on_line.x2[i] <== b[0][i];
    //     point_on_line.y2[i] <== b[1][i];
    //     point_on_line.x3[i] <== out[0][i];
    //     point_on_line.y3[i] <== out[1][i];
    // }

    // log(3);


    // component x_check_in_range = CheckInRangeP256();
    // component y_check_in_range = CheckInRangeP256();
    // for(var i = 0; i < k; i++){
    //     x_check_in_range.in[i] <== out[0][i];
    //     y_check_in_range.in[i] <== out[1][i];
    // }

    // log(4);
}

component main = Add(64, 4);