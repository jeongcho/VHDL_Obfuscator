import base64
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

class Obfuscation:
    def __init__(self, _key=None):
        # _key 값이 제공되지 않으면 기본값 사용
        self.key = _key if _key is not None else b'secretkey1234567'

    def obfuscate(self, plain_text):
        encrypted_text = self.aes_ecb_encrypt(plain_text)
        return self.s2num_enc(encrypted_text)

    def deobfuscation(self, encrypted_text):
        decrypted_text = self.num2s_dec(encrypted_text)
        return self.aes_ecb_decrypt(decrypted_text)

    def aes_ecb_encrypt(self, plain_text):
        """
        AES-128 ECB 모드로 문자열을 암호화
        :param plain_text: 암호화할 평문 문자열
        :param key: 16바이트(128비트) 키
        :return: Base64 인코딩된 암호문
        """
        assert len(self.key) == 16, "AES-128 키는 16바이트여야 합니다."

        cipher = AES.new(self.key, AES.MODE_ECB)
        padded_text = pad(plain_text.encode(), AES.block_size)
        encrypted_bytes = cipher.encrypt(padded_text)
        encrypted_base64 = base64.b64encode(encrypted_bytes).decode()

        return encrypted_base64

    def aes_ecb_decrypt(self, encrypted_base64):
        """
        AES-128 ECB 모드로 암호문을 복호화
        :param encrypted_base64: Base64로 인코딩된 암호문
        :param key: 16바이트(128비트) 키
        :return: 복호화된 원래 문자열
        """
        assert len(self.key) == 16, "AES-128 키는 16바이트여야 합니다."

        encrypted_bytes = base64.b64decode(encrypted_base64)
        cipher = AES.new(self.key, AES.MODE_ECB)
        decrypted_padded = cipher.decrypt(encrypted_bytes)
        decrypted_text = unpad(decrypted_padded, AES.block_size).decode()

        return decrypted_text

    def s2num_enc(self, instring):
        outstr = "ff"
        for c in instring:
            outstr = outstr + f"{ord(c):02x}"
        # print(outstr)
        return outstr

    def num2s_dec(self, encoded_str):
        # "as" 접두사 제거
        if not encoded_str.startswith("ff"):
            raise ValueError("Invalid encoded string format")

        hex_part = encoded_str[2:]  # "as" 이후의 문자열만 추출
        decoded_str = "".join(chr(int(hex_part[i:i+2], 16)) for i in range(0, len(hex_part), 2))
        return decoded_str    

if __name__ == "__main__":
    obf = Obfuscation()

    plain_text = "Hello"
    outstr = obf.obfuscate(plain_text)
    instr = obf.deobfuscation(outstr)
    print(instr)