import base64
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

# Base64 특수문자 변환 테이블
ENCODE_TRANS_TABLE = str.maketrans("+/", "ab")
DECODE_TRANS_TABLE = str.maketrans("ab", "+/")

def aes_encrypt_to_custom(input_str, key, iv):
    assert len(key) == 32, "AES key must be 32 bytes long"
    
    cipher = AES.new(key, AES.MODE_CBC, iv)
    padded_data = pad(input_str.encode(), AES.block_size)
    encrypted = cipher.encrypt(padded_data)

    encoded_with_iv = base64.b64encode(iv + encrypted).decode()
    print(f"Base64 Encoded with IV: {encoded_with_iv}")

    # Base64 필터링 및 변환
    b64_encoded_filtered = encoded_with_iv.translate(ENCODE_TRANS_TABLE).rstrip("=")
    print(f"Filtered Base64: {b64_encoded_filtered}")

    # 복원 검증
    restored_b64 = b64_encoded_filtered.translate(DECODE_TRANS_TABLE)
    restored_b64 += '=' * ((4 - len(restored_b64) % 4) % 4)

    assert base64.b64decode(restored_b64) == base64.b64decode(encoded_with_iv), \
        f"Base64 conversion failed!\nOriginal: {encoded_with_iv}\nRestored: {restored_b64}"

    return b64_encoded_filtered

def aes_decrypt_from_custom(encoded_str, key):
    assert len(key) == 32, "AES key must be 32 bytes long"

    b64_decoded = encoded_str.translate(DECODE_TRANS_TABLE)
    b64_decoded += '=' * ((4 - len(b64_decoded) % 4) % 4)

    encrypted_with_iv = base64.b64decode(b64_decoded)
    iv = encrypted_with_iv[:AES.block_size]
    encrypted = encrypted_with_iv[AES.block_size:]

    print(f"IV: {list(iv)}")
    print(f"Decrypted Base64 bytes: {list(encrypted)}")

    cipher = AES.new(key, AES.MODE_CBC, iv)
    decrypted = cipher.decrypt(encrypted)

    try:
        decrypted = unpad(decrypted, AES.block_size)
    except ValueError:
        raise ValueError("Incorrect padding value detected!")

    return decrypted.decode()

# 256비트(32바이트) 키 설정
key = b'credcommcredcommcredcommcredcomm'
iv = b'\x00' * AES.block_size  # 테스트를 위해 IV를 고정

# 테스트할 원래 텍스트
original_text = "hello world"

# 암호화 및 변환 수행
encoded_text = aes_encrypt_to_custom(original_text, key, iv)
decoded_text = aes_decrypt_from_custom(encoded_text, key)

print(f"Original: {original_text}")
print(f"Encoded:  {encoded_text}")
print(f"Decoded:  {decoded_text}")

# 검증
assert original_text == decoded_text, "Decoding failed!"
