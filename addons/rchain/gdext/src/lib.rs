//! RChain crypto GDExtension.
//!
//! Exposes the secp256k1 + keccak256 + blake2b-256 + base58 primitives that
//! `RChainWallet` needs to sign deploys and derive REV addresses, matching the
//! proven `~/RWallet/r-wallet` implementation byte-for-byte.

use godot::prelude::*;

use blake2::digest::consts::U32;
use blake2::{Blake2b, Digest as Blake2bDigest};
use k256::ecdsa::{
    signature::hazmat::{PrehashSigner, PrehashVerifier},
    Signature, SigningKey, VerifyingKey,
};
use rand_core::OsRng;
use sha3::Keccak256;

struct RChainGdext;

#[gdextension(entry_symbol = rchain_gdext_init)]
unsafe impl ExtensionLibrary for RChainGdext {}

/// Native crypto primitives. All methods are static; the class is not instantiable.
#[derive(GodotClass)]
#[class(no_init)]
struct RChainCryptoNative;

// ---------------------------------------------------------------------------
// Pure helpers (no Godot types) — unit-tested directly.
// ---------------------------------------------------------------------------

fn hex_encode(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        s.push(HEX[(b >> 4) as usize] as char);
        s.push(HEX[(b & 0x0f) as usize] as char);
    }
    s
}

fn hex_decode(s: &str) -> Result<Vec<u8>, String> {
    let s = s.strip_prefix("0x").unwrap_or(s);
    if s.len() % 2 != 0 {
        return Err("odd-length hex string".to_string());
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).map_err(|e| format!("invalid hex: {e}")))
        .collect()
}

fn keccak256(bytes: &[u8]) -> [u8; 32] {
    let mut h = Keccak256::new();
    h.update(bytes);
    let out = h.finalize();
    let mut arr = [0u8; 32];
    arr.copy_from_slice(&out);
    arr
}

fn blake2b256(bytes: &[u8]) -> [u8; 32] {
    let mut h = Blake2b::<U32>::new();
    h.update(bytes);
    let out = h.finalize();
    let mut arr = [0u8; 32];
    arr.copy_from_slice(&out);
    arr
}

fn signing_key_from_private(priv_hex: &str) -> Result<SigningKey, String> {
    let bytes = hex_decode(priv_hex)?;
    if bytes.len() != 32 {
        return Err("private key must be 32 bytes".to_string());
    }
    SigningKey::from_slice(&bytes).map_err(|e| format!("invalid private key: {e}"))
}

fn public_key_bytes(sk: &SigningKey) -> Vec<u8> {
    sk.verifying_key()
        .to_encoded_point(false)
        .as_bytes()
        .to_vec()
}

/// coinId "000000" + version "00" — the 4-byte REV address prefix.
const PREFIX: [u8; 4] = [0, 0, 0, 0];

fn derive_rev_address_from_pub(public_key: &[u8]) -> Result<String, String> {
    if public_key.len() != 65 || public_key[0] != 0x04 {
        return Err("public key must be 65 bytes starting with 0x04".to_string());
    }
    let eth_hash = keccak256(&public_key[1..]); // 32 bytes
    let eth_address = &eth_hash[12..]; // last 20 bytes
    let key_hash = keccak256(eth_address); // 32 bytes
    let mut payload = PREFIX.to_vec();
    payload.extend_from_slice(&key_hash);
    let checksum = &blake2b256(&payload)[0..4];
    let mut address = payload;
    address.extend_from_slice(checksum);
    Ok(bs58::encode(&address).into_string())
}

fn is_valid_rev_address_inner(address: &str) -> bool {
    let Ok(decoded) = bs58::decode(address).into_vec() else {
        return false;
    };
    if decoded.len() != 40 {
        return false;
    }
    let (payload, checksum) = decoded.split_at(36);
    if &blake2b256(payload)[0..4] != checksum {
        return false;
    }
    payload.starts_with(&PREFIX)
}

// --- protobuf (DeployData) ---

fn write_varint(buf: &mut Vec<u8>, mut v: u64) {
    while v >= 0x80 {
        buf.push((v as u8 & 0x7f) | 0x80);
        v >>= 7;
    }
    buf.push(v as u8);
}

fn write_string_field(buf: &mut Vec<u8>, field: u64, s: &str) {
    if s.is_empty() {
        return;
    }
    write_varint(buf, (field << 3) | 2);
    write_varint(buf, s.len() as u64);
    buf.extend_from_slice(s.as_bytes());
}

fn write_int64_field(buf: &mut Vec<u8>, field: u64, v: i64) {
    if v == 0 {
        return;
    }
    write_varint(buf, (field << 3) | 0);
    write_varint(buf, v as u64);
}

struct DeployData<'a> {
    term: &'a str,
    timestamp: i64,
    phlo_price: i64,
    phlo_limit: i64,
    valid_after_block_number: i64,
    shard_id: &'a str,
}

fn serialize_deploy_data(d: &DeployData) -> Vec<u8> {
    let mut buf = Vec::new();
    write_string_field(&mut buf, 2, d.term);
    write_int64_field(&mut buf, 3, d.timestamp);
    write_int64_field(&mut buf, 7, d.phlo_price);
    write_int64_field(&mut buf, 8, d.phlo_limit);
    write_int64_field(&mut buf, 10, d.valid_after_block_number);
    write_string_field(&mut buf, 11, d.shard_id);
    buf
}

fn sign_deploy_inner(d: &DeployData, priv_hex: &str) -> Result<(String, String), String> {
    let sk = signing_key_from_private(priv_hex)?;
    let deployer = public_key_bytes(&sk);
    let hash = blake2b256(&serialize_deploy_data(d));
    let sig: Signature = sk
        .sign_prehash(&hash)
        .map_err(|e| format!("sign failed: {e}"))?;
    let sig = sig.normalize_s().unwrap_or(sig);
    let der = sig.to_der().as_bytes().to_vec();
    Ok((hex_encode(&deployer), hex_encode(&der)))
}

fn verify_deploy_inner(d: &DeployData, deployer_hex: &str, sig_hex: &str) -> bool {
    let Ok(deployer) = hex_decode(deployer_hex) else {
        return false;
    };
    let Ok(sig_bytes) = hex_decode(sig_hex) else {
        return false;
    };
    let Ok(vk) = VerifyingKey::from_sec1_bytes(&deployer) else {
        return false;
    };
    let Ok(sig) = Signature::from_der(&sig_bytes) else {
        return false;
    };
    let hash = blake2b256(&serialize_deploy_data(d));
    vk.verify_prehash(&hash, &sig).is_ok()
}

// ---------------------------------------------------------------------------
// Godot API
// ---------------------------------------------------------------------------

#[godot_api]
impl RChainCryptoNative {
    #[func]
    fn generate_keypair() -> Dictionary<Variant, Variant> {
        let sk = SigningKey::random(&mut OsRng);
        let private_key = hex_encode(&sk.to_bytes());
        let public_key = hex_encode(&public_key_bytes(&sk));
        let mut out = Dictionary::new();
        out.set("private_key", private_key.as_str());
        out.set("public_key", public_key.as_str());
        out
    }

    #[func]
    fn public_key_from_private(private_key: GString) -> GString {
        match signing_key_from_private(&private_key.to_string()) {
            Ok(sk) => GString::from(hex_encode(&public_key_bytes(&sk)).as_str()),
            Err(_) => GString::new(),
        }
    }

    #[func]
    fn derive_rev_address(public_key: GString) -> GString {
        match hex_decode(&public_key.to_string())
            .and_then(|pk| derive_rev_address_from_pub(&pk))
        {
            Ok(addr) => GString::from(addr.as_str()),
            Err(_) => GString::new(),
        }
    }

    #[func]
    fn is_valid_rev_address(address: GString) -> bool {
        is_valid_rev_address_inner(&address.to_string())
    }

    #[allow(clippy::too_many_arguments)]
    #[func]
    fn sign_deploy(
        term: GString,
        timestamp: i64,
        phlo_price: i64,
        phlo_limit: i64,
        valid_after_block_number: i64,
        shard_id: GString,
        private_key: GString,
    ) -> Dictionary<Variant, Variant> {
        let term = term.to_string();
        let shard_id = shard_id.to_string();
        let d = DeployData {
            term: &term,
            timestamp,
            phlo_price,
            phlo_limit,
            valid_after_block_number,
            shard_id: &shard_id,
        };
        let mut out = Dictionary::new();
        match sign_deploy_inner(&d, &private_key.to_string()) {
            Ok((deployer, signature)) => {
                out.set("deployer", deployer.as_str());
                out.set("signature", signature.as_str());
                out.set("sig_algorithm", "secp256k1");
            }
            Err(e) => {
                out.set("error", e.as_str());
            }
        }
        out
    }

    #[allow(clippy::too_many_arguments)]
    #[func]
    fn verify_deploy(
        term: GString,
        timestamp: i64,
        phlo_price: i64,
        phlo_limit: i64,
        valid_after_block_number: i64,
        shard_id: GString,
        deployer: GString,
        signature: GString,
    ) -> bool {
        let term = term.to_string();
        let shard_id = shard_id.to_string();
        let d = DeployData {
            term: &term,
            timestamp,
            phlo_price,
            phlo_limit,
            valid_after_block_number,
            shard_id: &shard_id,
        };
        verify_deploy_inner(&d, &deployer.to_string(), &signature.to_string())
    }

    #[func]
    fn keccak256_hex(bytes: PackedByteArray) -> GString {
        GString::from(hex_encode(&keccak256(bytes.as_slice())).as_str())
    }

    #[func]
    fn blake2b256_hex(bytes: PackedByteArray) -> GString {
        GString::from(hex_encode(&blake2b256(bytes.as_slice())).as_str())
    }

    #[func]
    fn base58_encode(bytes: PackedByteArray) -> GString {
        GString::from(bs58::encode(bytes.as_slice()).into_string().as_str())
    }

    #[func]
    fn base58_decode(s: GString) -> PackedByteArray {
        match bs58::decode(s.to_string()).into_vec() {
            Ok(v) => PackedByteArray::from(v.as_slice()),
            Err(_) => PackedByteArray::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Vectors from ~/RWallet/r-wallet/scripts/test-unit.ts (proven against the Rust node).
    const PRIV: &str = "a68a6e6cca30f81bd24a719f3145d20e8424bd7b396309b0708a16c7d8000b76";
    const PUB: &str = "04f700a417754b775d95421973bdbdadb2d23c8a5af46f1829b1431f5c136e549e8a0d61aa0c793f1a614f8e437711c7758473c6ceb0859ac7e9e07911ca66b5c4";
    const ADDR: &str = "11112VYAt8rUGNRRZX3eJdgagaAhtWTK8Js7F7X5iqddMVqyDTtYau";
    const PROTO: &str = "12034e696c1801380140c0843d5a04726f6f74";
    const SIG: &str = "3045022100b781a370c644f082a1cff1d32548a646664dde33a4f33409d59ff74e669a7e7b02207b7aa1967f64be21eede99579a0966dbeb5b648714848502595a4b23e3493a7c";

    fn deploy_data() -> DeployData<'static> {
        DeployData {
            term: "Nil",
            timestamp: 1,
            phlo_price: 1,
            phlo_limit: 1_000_000,
            valid_after_block_number: 0,
            shard_id: "root",
        }
    }

    #[test]
    fn public_key_matches_wallet_vector() {
        let sk = signing_key_from_private(PRIV).unwrap();
        assert_eq!(hex_encode(&public_key_bytes(&sk)), PUB);
    }

    #[test]
    fn rev_address_matches_wallet_vector() {
        let pk = hex_decode(PUB).unwrap();
        assert_eq!(derive_rev_address_from_pub(&pk).unwrap(), ADDR);
    }

    #[test]
    fn rev_address_validation() {
        assert!(is_valid_rev_address_inner(ADDR));
        assert!(!is_valid_rev_address_inner("not-a-rev-address"));
    }

    #[test]
    fn deploy_data_serialization_matches_wallet_vector() {
        let d = deploy_data();
        let ser = serialize_deploy_data(&d);
        assert_eq!(hex_encode(&ser), PROTO);
        assert!(ser.contains(&0x5a)); // shardId field 11 tag
    }

    #[test]
    fn sign_and_verify_deploy() {
        let d = deploy_data();
        let (deployer, signature) = sign_deploy_inner(&d, PRIV).unwrap();
        assert_eq!(deployer, PUB);
        assert!(signature.starts_with("30"), "DER signature");
        assert!(verify_deploy_inner(&d, &deployer, &signature));
    }

    #[test]
    fn signature_matches_wallet_vector_rfc6979() {
        let d = deploy_data();
        let (_, signature) = sign_deploy_inner(&d, PRIV).unwrap();
        assert_eq!(signature, SIG);
    }
}
