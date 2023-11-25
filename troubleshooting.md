# Native attempts
When adopting the ECC addition to P-256, there seems to be issues surrounding using the circom-ecdsa secp256k1 methods.
- 8 32-bit registers are used in the reduction templates instead of 4 64-bit registers, as the P-256 prime has higher order bits unset, which leads to unwanted overflows in the multiplication of register reduction templates.
- The 8 32-bit register outputs are overflowed, but evaluating them $mod p$ shows that they are indeed equal to zero (and therefore work correctly)
- Howerver, `getProperRepresentation` does not seem to handle these registers correctly, so we cannot reduce them to the proper 4 64-bit registers.

# Attempts to use circom-pairing
- If we simply replace `getProperRepresentation` with `PrimeReduce` in `CheckCubicModPIsZero`, this does not work as some of the registers of both the input and the reduction step have values > 2^250.
- `EllipticCurveScalarMultiply` only works with scalar values in [0, 2^250), but the scalars used in ecdsa are taken mod the order, which is > 2^250
- When using a modified version of `P256ScalarMult` (instead of using `EllipticCurveScalarMultiply`), `EllipticCurveDouble` requires that a < 2^n, but P256 a is 256 bits (greater than circom field size)

# Notes from meeting
- Try to modify ECCDouble to take in a as BigInt