- POLER-ERI-v3.2.0/README.md

# POLER-ERI-v3.2.0/README.md
```
# POLER-ERI v3.0.1

**Quantum-Inspired ERI Meta-Compiler with R1CS + Crystallization + Archetype Algebra**

## What Is This?

POLER-ERI is a meta-compiler that generates optimized Rust code for computing
electron repulsion integrals (ERIs) in quantum chemistry. It does NOT compute
integrals directly — instead, it **compiles the mathematical recipe** for each
integral type into flat, zero-alloc, SIMD-ready Rust source code.

## What's New in v3.0.1

### Archetype Equation from the Algebra of Senses

v3.0.1 introduces the **Algebra of Senses** A = (O, ⊕, ⊗_ε), where:

- **O** is the set of semantic (computational) elements
- **⊕** is the direct sum (superposition of code fragments)
- **⊗_ε** is the topologically deformed tensor product with parameter ε

An **archetype** is a non-trivial idempotent element a ∈ O satisfying:

```
a ⊗_ε a = a    (Idempotency: re-compilation produces the same code)
a ⊗_ε e = a    (Neutrality: the archetype is self-sufficient)
a ≠ e           (Non-triviality: the archetype is not the vacuum)
```

And any fixed point of the SCF iteration satisfies:

```
p* = a ⊗_ε p*  (Fixed-point: convergence is guaranteed)
```

**Derivation** (4 axioms of tensor algebra):

1. **Associativity**: (x ⊗_ε y) ⊗_ε z = x ⊗_ε (y ⊗_ε z)
2. **Distributivity**: x ⊗_ε (y ⊕ z) = (x ⊗_ε y) ⊕ (x ⊗_ε z)
3. **Neutral element**: x ⊗_ε e = e ⊗_ε x = x
4. **Topological continuity**: ⊕ and ⊗_ε are continuous

From axioms 1-3: L_a² = L_a → a ⊗_ε a = a (evaluating at x = e)
From axiom 4: if p_t → p*, then p* = a ⊗_ε p* (continuity of ⊗_ε)

### Cryptographic Verification

The idempotency a ⊗_ε a = a provides a natural **hash function**:
if you compile the same circuit twice and get different results, something is wrong.

- **Fingerprint**: 64-bit hash of each archetype's circuit structure
- **Merkle tree**: Single root hash committing to all archetypes
- **Signed modules**: Generated code with cryptographic integrity proof

### Reverse Meta-Compiler

The inverse of crystallization: given source code (C/Python/Rust), extract
the underlying archetype and re-crystallize it into optimized Rust.

### One-Keystroke Pipeline

```
poler-eri one-key --max-am 3
```

Builds archetypes → Crystallizes → Verifies → Signs → Outputs code with integrity proof.

## How It Works

The meta-compiler uses a 3-stage pipeline (plus archetype/crypto layers):

```
Shell quartet (la,lb,lc,ld)
        |
        v
  [1] CircuitBuilder
        |   Builds an R1CS (Rank-1 Constraint System) circuit
        |   representing the VRR+HRR recurrence relations.
        |   Each gate: result = cL * operand[left] + cR * operand[right]
        v
  [2] VrrCrystallizer
        |   Flattens the circuit into linear Rust code.
        |   No loops. No branches. No allocations.
        |   Just: operands[i] = coeff * operands[j] + coeff * operands[k]
        v
  [3] BatchCompiler
        |   Iterates over ALL shell quartets up to MAX_AM.
        |   Writes each crystallized function to generated/eri_XYZW.rs
        |   Generates mod.rs with all module declarations.
        v
  [4] ArchetypeRegistry  (NEW in v3.0.1)
        |   Maps each quartet to an archetype a ⊗_ε a = a
        |   Verifies idempotency and fixed-point properties
        v
  [5] CryptoVerifier  (NEW in v3.0.1)
        |   Builds Merkle tree of archetype fingerprints
        |   Signs each generated module
        |   Provides integrity proof for the entire codebase
        v
Generated Rust crate with ERI functions + cryptographic proof
```

### The 4-Stage ERI Pipeline

ERIs are computed via recurrence relations that reduce angular momentum:

```
VRR-A  →  Increase l on center A until target la is reached
HRR-bra →  Transfer l from A to B (horizontal shift)
VRR-C  →  Increase l on center C until target lc is reached
  (with cross-terms from A and B — this was the critical bug in v0.5-v1.0)
HRR-ket →  Transfer l from C to D (horizontal shift)
```

### R1CS Gate Format

```
result = coeff_left * operand[left] + coeff_right * operand[right]
```

Where coefficients can be:
- `Zero` / `One` — trivial
- `Scalar(f64)` — a numeric constant
- `Prefactor(usize)` — index into a prefactor array (computed at runtime from geometry)
- `BoyF(usize)` — Boys function F_m(T)
- `Operand(usize)` — reference to a previously computed operand

## Quick Start

```bash
# Build the project
cargo build --release

# Run the test suite (10 checks including archetype + crypto)
poler-eri validate

# One-keystroke pipeline: compile, verify, sign
poler-eri one-key --max-am 3

# Batch-compile all quartets up to f-shell (MAX_AM=3)
poler-eri compile --max-am 3 --output src/autogen

# Inspect an archetype
poler-eri archetype --quartet 2,1,2,1

# Crypto-verify all archetypes
poler-eri verify --max-am 3

# Reverse-compile a source file
poler-eri reverse --input ../libcint/src/g2e.c

# Statistics
poler-eri stats --max-am 5
```

## CLI Reference

| Command | Description |
|---------|-------------|
| `compile` | Batch-compile all quartets up to MAX_AM |
| `stats` | Print statistics without writing files |
| `generate` | Generate code for a single quartet |
| `transpile` | Parse a C source file and extract recurrence patterns |
| `validate` | Run 10 built-in validation tests |
| `archetype` | Show archetype info and verify idempotency (a⊗a=a) |
| `verify` | Crypto-verify all archetypes (Merkle tree) |
| `reverse` | Reverse-compile source file to archetypes |
| `one-key` | Full one-keystroke pipeline (compile+verify+sign) |
| `dashboard` | Launch HTTP dashboard (not yet implemented) |

## Architecture

```
src/
  lib.rs              — Public API exports with documentation
  main.rs             — CLI entry point (subcommand dispatch)
  types.rs            — Core types: Shell, Point, QuartetData, Atom, BasisSet
  boys.rs             — Boys function F_m(T) evaluation
  cart.rs             — Cartesian component enumeration
  normalization.rs    — GTO normalization
  overlap.rs          — Overlap integrals (1-electron)
  kinetic.rs          — Kinetic energy integrals (1-electron)
  nuclear.rs          — Nuclear attraction integrals (1-electron)
  dipole.rs           — Dipole moment integrals
  vrr.rs              — VRR engine (Obara-Saika recurrence)
  hrr.rs              — HRR engine (horizontal recurrence)
  eri.rs              — ERI shell-level wrapper
  circuit.rs          — R1CS Circuit Builder (THE meta-compiler core)
  crystallizer.rs     — Circuit-to-Rust code generator
  batch.rs            — BatchCompiler (auto-iterate all quartets)
  c_parser.rs         — C source parser (extracts libcint patterns)
  transpiler.rs       — C-to-Rust transpiler engine
  contraction.rs      — CGTO contraction
  cart2sph.rs         — Cartesian to spherical transformation
  screening.rs        — Schwarz integral screening
  basis.rs            — NWChem basis set parser
  molecule.rs         — Molecule definitions (H2, LiH, Li40)
  engine.rs           — IntegralEngine API
  diagonalize.rs      — Jacobi eigenvalue solver
  density.rs          — Density matrix construction
  diis.rs             — DIIS convergence accelerator
  fock.rs             — Fock matrix builder (J and K)
  scf.rs              — RHF SCF loop
  eri_rys.rs          — Rys quadrature for high-l shells
  archetype.rs        — Archetype equation (a⊗a=a) + Algebra of Senses
  crypto.rs           — Merkle tree + fingerprint verification + signing
  reverse.rs          — Reverse meta-compiler (code → archetype)
  autogen/            — Auto-generated ERI modules (by BatchCompiler)
  bin/
    poler_eri.rs      — Main binary (CLI)
```

## The Archetype Equation and Cryptography

The archetype equation `a ⊗_ε a = a` is not just a mathematical curiosity — it
is the foundation of the cryptographic verification system:

1. **Idempotency = Collision Resistance**: If you compile the same circuit twice
   and get different code, the fingerprint changes. This is equivalent to a hash
   collision in the crystallizer.

2. **Fixed Point = Determinism**: The SCF iteration converges to a unique fixed
   point p* = a ⊗_ε p*. This means the generated code is deterministic — the
   same input always produces the same output.

3. **Topological Continuity = Avalanche Effect**: Small changes in the circuit
   (e.g., changing one gate) produce small changes in the fingerprint. This is
   the cryptographic avalanche property.

4. **Merkle Tree = Commitment**: The root hash commits to the entire codebase.
   Any change to any archetype changes the root hash, making it impossible to
   tamper with generated code without detection.

## Version History

| Version | Lines | Key Feature | Critical Bug |
|---------|-------|-------------|-------------|
| v0.5.0-SNAPSHOT | 2,059 | VRR-A only, (ss\|ss) to (ds\|ss) | No VRR-C cross-terms |
| v0.6.0-SNAPSHOT | 3,586 | +(pp\|pp), 689 lines generated | No VRR-C cross-terms |
| v0.7.0 | 16,757 | +(dd\|dd), 12,976 lines generated | No VRR-C cross-terms (WRONG MATH) |
| v0.8.0 | 2,858 | Rewrite to 4-stage pipeline | Still no VRR-C cross-terms |
| v0.9.0 | 3,244 | +1-electron integrals | No VRR-C cross-terms |
| v1.0.0 | 3,791 | +CGTO contraction + cart2sph | No VRR-C cross-terms |
| **v2.0.0** | 2,864 | +DIIS, SCF, Rys, VRR-C cross-terms | Rys quadrature bugs |
| v2.1.0 | 2,900 | +BatchCompiler, auto-gen | Same Rys bugs |
| v3.0.0 | ~4,000 | +README, CLI, C parser, doc comments | — |
| **v3.0.1** | ~5,200 | +Archetype (a⊗a=a), Crypto, Reverse compiler | — |

## The Bootstrapping Vision

The long-term goal is to **run the meta-compiler through itself**:

1. **Stage 1** (current): BatchCompiler auto-iterates all quartets to MAX_AM
2. **Stage 2**: C/Python parser frontend — feed libcint/PySCF source directly
3. **Stage 3**: Meta-compiler compiles itself — true bootstrapping

The archetype equation ensures that bootstrapping is safe: if the compiler
produces itself (a ⊗_ε a = a), the result is verified by construction.

## Dependencies

- `libm` — math functions (sqrt, exp, etc.) for no_std compatibility

No other dependencies. The project is intentionally minimal.

## License

POLER-ERI is research software. Use at your own risk.
```