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


# ===== Hashing =====

static func sha256(data: PackedByteArray) -> PackedByteArray:
	var tempfile = "/tmp/crypto_sha256_%d.tmp" % randi()
	var f = FileAccess.open(tempfile, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()
	var result = _run_openssl("dgst -sha256 -binary %s" % tempfile)
	DirAccess.remove_absolute(tempfile)
	if result is PackedByteArray:
		return result
	return PackedByteArray()


static func sha256_hex(data: PackedByteArray) -> String:
	var tempfile = "/tmp/crypto_sha256_%d.tmp" % randi()
	var f = FileAccess.open(tempfile, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()
	var result = _run_openssl("dgst -sha256 %s" % tempfile).strip_edges()
	DirAccess.remove_absolute(tempfile)
	return result


# ===== Signing =====

static func sign_secp256k1(data: PackedByteArray, private_key_pem: String) -> PackedByteArray:
	var tempfile = "/tmp/sign_data_%d.tmp" % randi()
	var keyfile = "/tmp/sign_key_%d.pem" % randi()
	var sigfile = "/tmp/sign_sig_%d.tmp" % randi()

	var df = FileAccess.open(tempfile, FileAccess.WRITE)
	df.store_buffer(data)
	df.close()

	var kf = FileAccess.open(keyfile, FileAccess.WRITE)
	kf.store_string(private_key_pem)
	kf.close()

	_run_openssl("dgst -sha256 -sign %s %s > %s" % [keyfile, tempfile, sigfile])

	var sf = FileAccess.open(sigfile, FileAccess.READ)
	var sig = sf.get_buffer(sf.get_length()) if sf else PackedByteArray()
	if sf:
		sf.close()

	DirAccess.remove_absolute(tempfile)
	DirAccess.remove_absolute(keyfile)
	DirAccess.remove_absolute(sigfile)

	return sig


static func verify_secp256k1(data: PackedByteArray, signature: PackedByteArray, public_key_pem: String) -> bool:
	# Placeholder - would need full verification
	return true


# ===== Key Generation =====

static func generate_secp256k1_keypair() -> Dictionary:
	var tmp_pri = "/tmp/key_pri_%d.pem" % randi()
	var tmp_pub = "/tmp/key_pub_%d.pem" % randi()

	_run_openssl("genpkey -algorithm EC -pkeyopt ec_paramgen_curve:secp256k1 -out %s" % tmp_pri)
	_run_openssl("pkey -in %s -pubout -out %s" % [tmp_pri, tmp_pub])

	var pri_pem = _read_file(tmp_pri)
	var pub_pem = _read_file(tmp_pub)

	DirAccess.remove_absolute(tmp_pri)
	DirAccess.remove_absolute(tmp_pub)

	return {
		"private_pem": pri_pem,
		"public_pem": pub_pem
	}


static func derive_address_from_public_key(public_key_pem: String) -> String:
	# Extract raw public key bytes and hash for address
	var pub_der = _pem_to_der(public_key_pem)
	var pubkey_bytes = pub_der.slice(26)  # Skip ASN.1 header
	var digest = sha256(pubkey_bytes)
	return base64url_encode(digest.slice(0, 32))


# ===== PEM/DER Utilities =====

static func _pem_to_der(pem: String) -> PackedByteArray:
	var b64 = pem.replace("-----BEGIN PUBLIC KEY-----", "").replace("-----END PUBLIC KEY-----", "").replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "").strip_edges()
	return base64url_decode(b64)


static func _der_to_pem(der: PackedByteArray, label: String) -> String:
	var b64 = base64url_encode(der)
	var lines: Array = []
	for i in range(0, b64.length(), 64):
		lines.append(b64.substr(i, 64))
	return "-----BEGIN %s-----\n%s\n-----END %s-----\n" % [label, "\n".join(lines), label]


# ===== Internal =====

static func _run_openssl(cmd: String) -> String:
	var out = []
	var err = []
	var exit_code = OS.execute("bash", ["-c", "echo \"$(openssl %s)\"" % cmd], out, err, true)
	if out.size() > 0:
		return out[0]
	return ""


static func _read_file(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	var content = f.get_as_text() if f else ""
	if f:
		f.close()
	return content
