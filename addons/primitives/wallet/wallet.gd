# wallet.gd
# Unified wallet interface - composable across Arweave, HyperBEAM, etc.

class_name Wallet

var _address: String
var _key_type: String
var _signer: Callable  # External signer function


func _init(key_type: String = "secp256k1") -> void:
	_key_type = key_type


func get_address() -> String:
	return _address


func get_key_type() -> String:
	return _key_type


func set_address(addr: String) -> void:
	_address = addr


func set_signer(signer: Callable) -> void:
	_signer = signer


func sign(data: PackedByteArray) -> PackedByteArray:
	if _signer.is_valid():
		return _signer.call(data)
	return PackedByteArray()


func has_private_key() -> bool:
	return _signer.is_valid()


# ===== Factory =====

static func create(key_type: String = "secp256k1") -> Wallet:
	match key_type:
		"secp256k1":
			return Secp256k1Wallet.new()
		"rsa":
			return RsaWallet.new()
		_:
			return Secp256k1Wallet.new()


# ===== Secp256k1 Implementation =====

class Secp256k1Wallet extends Wallet:

	var _private_pem: String = ""
	var _public_pem: String = ""

	func _init():
		super("secp256k1")


	func generate() -> Secp256k1Wallet:
		var keys = HyperCrypto.generate_secp256k1_keypair()
		_private_pem = keys["private_pem"]
		_public_pem = keys["public_pem"]
		_address = HyperCrypto.derive_address_from_public_key(_public_pem)
		_signer = Callable(self, "_secp256k1_signer")
		return self


	func _secp256k1_signer(data: PackedByteArray) -> PackedByteArray:
		return HyperCrypto.sign_secp256k1(data, _private_pem)


	func get_public_pem() -> String:
		return _public_pem


	static func from_pem(private_pem: String, public_pem: String = "") -> Secp256k1Wallet:
		var wallet = Secp256k1Wallet.new()
		wallet._private_pem = private_pem
		wallet._public_pem = public_pem if not public_pem.is_empty() else private_pem
		wallet._address = HyperCrypto.derive_address_from_public_key(wallet._public_pem)
		wallet._signer = Callable(wallet, "_secp256k1_signer")
		return wallet


	static func from_jwk(jwk: Dictionary) -> Secp256k1Wallet:
		# Convert JWK to PEM format
		var wallet = Secp256k1Wallet.new()
		wallet._address = jwk.get("kid", "")
		# Would convert JWK to PEM here
		return wallet


# ===== RSA Implementation =====

class RsaWallet extends Wallet:

	var _private_key: PackedByteArray

	func _init():
		super("rsa")


	func sign(data: PackedByteArray) -> PackedByteArray:
		# RSA signing via HyperSig or external
		return PackedByteArray()


	static func from_key_data(key_data: PackedByteArray) -> RsaWallet:
		var wallet = RsaWallet.new()
		wallet._private_key = key_data
		return wallet
