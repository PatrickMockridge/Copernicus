class_name RChainCrypto
extends RefCounted
## Thin GDScript wrapper around the native `RChainCryptoNative` GDExtension class.
## Fallible operations return a Copernicus `Result` (addons/primitives/result.gd).


static func generate_keypair() -> Result:
	var d: Dictionary = RChainCryptoNative.generate_keypair()
	if d.is_empty():
		return Result.err("failed to generate keypair")
	return Result.ok(d)


static func public_key_from_private(private_key: String) -> Result:
	var pk: String = RChainCryptoNative.public_key_from_private(private_key)
	if pk.is_empty():
		return Result.err("invalid private key")
	return Result.ok(pk)


static func derive_rev_address(public_key: String) -> Result:
	var addr: String = RChainCryptoNative.derive_rev_address(public_key)
	if addr.is_empty():
		return Result.err("invalid public key")
	return Result.ok(addr)


static func is_valid_rev_address(address: String) -> bool:
	return RChainCryptoNative.is_valid_rev_address(address)


static func sign_deploy(
	term: String,
	timestamp: int,
	phlo_price: int,
	phlo_limit: int,
	valid_after_block_number: int,
	shard_id: String,
	private_key: String
) -> Result:
	var d: Dictionary = RChainCryptoNative.sign_deploy(
		term, timestamp, phlo_price, phlo_limit, valid_after_block_number, shard_id, private_key
	)
	if d.has("error"):
		return Result.err(str(d["error"]))
	return Result.ok(d)


static func verify_deploy(
	term: String,
	timestamp: int,
	phlo_price: int,
	phlo_limit: int,
	valid_after_block_number: int,
	shard_id: String,
	deployer: String,
	signature: String
) -> bool:
	return RChainCryptoNative.verify_deploy(
		term, timestamp, phlo_price, phlo_limit, valid_after_block_number, shard_id,
		deployer, signature
	)


static func keccak256_hex(bytes: PackedByteArray) -> String:
	return RChainCryptoNative.keccak256_hex(bytes)


static func blake2b256_hex(bytes: PackedByteArray) -> String:
	return RChainCryptoNative.blake2b256_hex(bytes)


static func base58_encode(bytes: PackedByteArray) -> String:
	return RChainCryptoNative.base58_encode(bytes)


static func base58_decode(s: String) -> Result:
	var b: PackedByteArray = RChainCryptoNative.base58_decode(s)
	if b.is_empty() and not s.is_empty():
		return Result.err("invalid base58")
	return Result.ok(b)


static func generate_mnemonic() -> Result:
	var m: String = RChainCryptoNative.generate_mnemonic()
	if m.is_empty():
		return Result.err("failed to generate mnemonic")
	return Result.ok(m)


static func is_valid_mnemonic(mnemonic: String) -> bool:
	return RChainCryptoNative.is_valid_mnemonic(mnemonic)


static func mnemonic_to_seed(mnemonic: String) -> Result:
	var seed: String = RChainCryptoNative.mnemonic_to_seed(mnemonic)
	if seed.is_empty():
		return Result.err("invalid mnemonic")
	return Result.ok(seed)


static func mnemonic_to_private_key(mnemonic: String) -> Result:
	var pk: String = RChainCryptoNative.mnemonic_to_private_key(mnemonic)
	if pk.is_empty():
		return Result.err("invalid mnemonic")
	return Result.ok(pk)
