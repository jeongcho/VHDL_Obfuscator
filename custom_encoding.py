import base64
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
import os

def aes_encrypt_to_custom(input_str, key):
    """
    AES 256 CBC 모드를 사용하여 암호화하고 Base64로 인코딩 후 특정 문자로 변환
    """
    assert len(key) == 32, "AES key must be 32 bytes long"

    # IV 생성 및 AES CBC 모드 암호화
    iv = os.urandom(AES.block_size)
    cipher = AES.new(key, AES.MODE_CBC, iv)

    padded_data = pad(input_str.encode(), AES.block_size)
    encrypted = cipher.encrypt(padded_data)

    # IV + 암호문을 Base64로 인코딩
    encoded_with_iv = base64.b64encode(iv + encrypted).decode()
    print(f"Base64 Encoded with IV: {encoded_with_iv}")

    # Base64 변환: 특수문자 치환 및 패딩 제거
    b64_encoded_filtered = encoded_with_iv.replace('+', 'a').replace('/', 'b').replace('=', '')
    print(f"Filtered Base64: {b64_encoded_filtered}")

    # 변환 후 복원 검증
    restored_b64 = b64_encoded_filtered.replace('a', '+').replace('b', '/')
    restored_b64 += '=' * ((4 - len(restored_b64) % 4) % 4)  # 올바른 패딩 추가

    assert base64.b64decode(restored_b64) == base64.b64decode(encoded_with_iv), "Base64 conversion failed!"

    return b64_encoded_filtered

def aes_decrypt_from_custom(encoded_str, key):
    """
    변환된 문자열을 다시 원래의 ASCII 문자열로 복원
    """
    assert len(key) == 32, "AES key must be 32 bytes long"

    # 특수 문자 복원 및 패딩 보완
    b64_decoded = encoded_str.replace('a', '+').replace('b', '/')
    b64_decoded += '=' * ((4 - len(b64_decoded) % 4) % 4)  # 패딩 보정

    print(f"Decoded Base64 with padding: {b64_decoded}")

    # Base64 디코딩
    encrypted_with_iv = base64.b64decode(b64_decoded)
    iv = encrypted_with_iv[:AES.block_size]  # 첫 16바이트는 IV
    encrypted = encrypted_with_iv[AES.block_size:]

    print(f"IV: {list(iv)}")
    print(f"Decrypted Base64 bytes: {list(encrypted)}")

    # 복호화 수행
    cipher = AES.new(key, AES.MODE_CBC, iv)
    decrypted = cipher.decrypt(encrypted)
    print(f"Decrypted text (before unpad): {list(decrypted)}")

    # 패딩 값 검증 및 제거
    try:
        decrypted = unpad(decrypted, AES.block_size)
    except ValueError as e:
        print("Padding removal failed!")
        print("Decrypted bytes:", list(decrypted))
        raise ValueError("Incorrect padding value detected!")

    return decrypted.decode()

# 256비트(32바이트) 키 설정
key = b'Sixteen byte keySixteen byte key'

# 테스트할 원래 텍스트
original_text = "hello world"

# 암호화 및 변환 수행
encoded_text = aes_encrypt_to_custom(original_text, key)
decoded_text = aes_decrypt_from_custom(encoded_text, key)

print(f"Original: {original_text}")
print(f"Encoded:  {encoded_text}")
print(f"Decoded:  {decoded_text}")

# 검증
assert original_text == decoded_text, "Decoding failed!"
