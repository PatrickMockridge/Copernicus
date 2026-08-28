# RChain — Wallet & Crypto Specification

Spec for `RChainCrypto` (Rust GDExtension) and `RChainWallet` (GDScript). All
algorithms are the secp256k1-based scheme used by RNode and `~/RWallet/r-wallet`.

## Key formats

- **Private key**: 32 bytes, represented as 64 lowercase hex chars (optionally
  `0x`-prefixed on input). Validated to be in the secp256k1 range.
- **Public key**: secp256k1 **uncompressed** 65-byte point (`0x04 || X || Y`),
  represented as 130 hex chars.
- **Deployer id**: the 65-byte uncompressed public key (hex), used as the
  `deployer` field of a `DeployRequest`.

## REV address derivation

Given the uncompressed public key bytes `pk` (65 bytes, `pk[0] == 0x04`):

1. `eth_hex = hex(keccak256(pk[1..]))` (hash the 64 bytes after `0x04`).
2. `eth_address = eth_hex[last 40 hex chars]`.
3. `key_hash = keccak256(hex_decode(eth_address))` (32 bytes).
4. `payload = hex_decode("000000" ++ "00") ++ key_hash`  (`coinId=000000`, `version=00`; 34 bytes).
5. `checksum = blake2b-256(payload)[0..4]` (first 4 bytes).
6. `rev_address = base58(payload ++ checksum)`.

REV addresses begin with `1111…`. `is_valid_rev_address(s)` reverses the split
(base58-decode → payload = all but last 4 bytes → recompute checksum → compare).

## Signing a deploy

1. `serialized = protobuf(DeployData)` — see `protocol.md` field table
   (`shardId` field 11 is mandatory).
2. `hash = blake2b-256(serialized)`.
3. `sig = secp256k1_sign(hash, priv)` with **low-S canonicalization**, output as
   **DER**.
4. Return `{ deployer: hex(pub), signature: hex(sig), sigAlgorithm: "secp256k1" }`.

`verify_deploy(data, deployer_hex, sig_hex)` reverses: recompute hash, recover/verify
against the uncompressed public key.

## `RChainCrypto` (GDExtension) method surface

Exposed as a Godot class with static methods (all pure, no node I/O):

```
generate_keypair() -> Dictionary                       # { private_key: String, public_key: String }
public_key_from_private(private_key) -> String
derive_rev_address(public_key) -> String
is_valid_rev_address(address) -> bool
sign_deploy(term, timestamp, phlo_price, phlo_limit,
            valid_after_block_number, shard_id, private_key) -> Dictionary
verify_deploy(term, timestamp, phlo_price, phlo_limit,
              valid_after_block_number, shard_id, deployer, signature) -> bool
keccak256_hex(bytes: PackedByteArray) -> String
blake2b256_hex(bytes: PackedByteArray) -> String
base58_encode(bytes: PackedByteArray) -> String
base58_decode(str: String) -> PackedByteArray
```

`timestamp`/`phlo_price`/`phlo_limit`/`valid_after_block_number` are `int` (64-bit
signed — sufficient for these magnitudes). `sign_deploy` returns
`{ deployer, signature, sig_algorithm }`.

## `RChainWallet` (GDScript)

Wraps `RChainCrypto` and adds lifecycle + node-adjacent operations:

- `generate()`, `from_private_key(hex)`, `export_private_key() -> String`
- `get_public_key()`, `get_rev_address()`
- `sign_deploy(term, opts) -> Result` (fills timestamp/phlo/defaults from the node)
- `check_balance() -> Result[int]` (explore-deploys the `revVault getBalance` term)
- `transfer(to, amount) -> Result[deploy_id]` (deploys the `revVault transfer` term)
- `save_keystore(password, path)` / `load_keystore(path, password)` (Ethereum V3)
- `from_mnemonic(phrase)` / `generate_mnemonic()` (BIP-39 English, path
  `m/44'/60'/0'/0/0`)

`RChainWallet` extends the existing `addons/primitives/wallet/wallet.gd` `Wallet`
base where practical, and returns `Result` (`addons/primitives/result.gd`) from
fallible operations.

### Mnemonic / keystore (optional, parity with RWallet)

- **Mnemonic**: BIP-39 English; seed → HD key at `m/44'/60'/0'/0/0` → private key.
- **Keystore**: Ethereum V3 JSON (scrypt `n=131072`). `RChainCrypto` does **not**
  implement scrypt; keystore support is a GDScript/helper concern and can be
  deferred (raw hex + mnemonic are the primary formats).
