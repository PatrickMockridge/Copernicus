# crypto.gd
# Unified cryptographic primitives - composable across SDKs

class_name HyperCrypto

# ===== Base64url =====

static func base64url_encode(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data).replace("+", "-").replace("/", "_").trim_suffix("=")


static func base64url_decode(data: String) -> PackedByteArray:
	var padded = data.replace("-", "+").replace("_", "/")
	while padded.length() % 4 != 0:
		padded += "="
	return Marshalls.base64_to_raw(padded)


# ===== Hashing (native, no subprocess) =====

static func sha256(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()


static func sha256_hex(data: PackedByteArray) -> String:
	return sha256(data).hex_encode()


# ===== Signing (secp256k1 via openssl) =====

static func sign_secp256k1(data: PackedByteArray, private_key_pem: String) -> PackedByteArray:
	var datafile := _write_temp("sign_data", data)
	var keyfile := _write_temp("sign_key", private_key_pem.to_utf8_buffer())
	var output: Array = []
	var exit_code := OS.execute("openssl", ["dgst", "-sha256", "-sign", keyfile, datafile], output, false, false)
	_remove_temp(datafile)
	_remove_temp(keyfile)
	if exit_code != 0 or output.is_empty():
		return PackedByteArray()
	return output[0]


static func verify_secp256k1(data: PackedByteArray, signature: PackedByteArray, public_key_pem: String) -> bool:
	var datafile := _write_temp("verify_data", data)
	var sigfile := _write_temp("verify_sig", signature)
	var keyfile := _write_temp("verify_key", public_key_pem.to_utf8_buffer())
	var output: Array = []
	var exit_code := OS.execute("openssl", ["dgst", "-sha256", "-verify", keyfile, "-signature", sigfile, datafile], output, true, false)
	_remove_temp(datafile)
	_remove_temp(sigfile)
	_remove_temp(keyfile)
	return exit_code == 0


# ===== Key Generation =====

static func generate_secp256k1_keypair() -> Dictionary:
	var pri := "/tmp/key_pri_%d.pem" % randi()
	var pub := "/tmp/key_pub_%d.pem" % randi()
	var out: Array = []
	var e1 := OS.execute("openssl", ["genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:secp256k1", "-out", pri], out, true, false)
	var e2 := OS.execute("openssl", ["pkey", "-in", pri, "-pubout", "-out", pub], out, true, false)
	var pri_pem := _read_file(pri) if e1 == 0 else ""
	var pub_pem := _read_file(pub) if e2 == 0 else ""
	_remove_temp(pri)
	_remove_temp(pub)
	return {"private_pem": pri_pem, "public_pem": pub_pem}


static func derive_address_from_public_key(public_key_pem: String) -> String:
	var pub_der = _pem_to_der(public_key_pem)
	var pubkey_bytes = pub_der.slice(26)  # Skip ASN.1 header
	var digest = sha256(pubkey_bytes)
	return base64url_encode(digest)


# ===== PEM/DER Utilities =====

static func _pem_to_der(pem: String) -> PackedByteArray:
	var b64 = pem.replace("-----BEGIN PUBLIC KEY-----", "").replace("-----END PUBLIC KEY-----", "").replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "").strip_edges()
	return base64url_decode(b64)


# ===== Internal =====

static func _write_temp(prefix: String, data: PackedByteArray) -> String:
	var path := "/tmp/%s_%d.tmp" % [prefix, randi()]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()
		return path
	return ""


static func _remove_temp(path: String) -> void:
	if not path.is_empty():
		DirAccess.remove_absolute(path)


static func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	var content = f.get_as_text() if f else ""
	if f:
		f.close()
	return content
