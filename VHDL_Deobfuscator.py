import re
from Obfuscation import Obfuscation
import os
from pathlib import Path
import argparse

SRC_Dir = "output"
DIST_Dir = "deobfused"

# Search files in subdirectory
def list_All_Vhd_Files(path):
    source_to_obfusacte = []
    for path, subdirs, files in os.walk(SRC_Dir):
        for name in files:
            if (name.endswith(".vhd")):
                # print(os.path.join(path, name))
                file_path = Path(path) / name
                # print(file_path)
                # source_to_obfusacte.append(os.path.join(path, name))
                source_to_obfusacte.append(file_path)
    return source_to_obfusacte

def get_token(files_list):
    signals = []
    for line in files_list:

        # Get path of the next file to analyze
        next_file = line
        with open(next_file, "rt", encoding='utf-8') as file_to_obfuscate:
            # Read all the file
            text_file = file_to_obfuscate.read()
            # Remove comments
            # -- 이후부터 줄 끝까지(\n)의 내용을 매칭해서 공백으로 바꿈
            text_file = re.sub(re.compile("--.*?\n" ) ,"" ,text_file) 

            # ----------- Get all its tokens

            # -- select signal, constant, variable
            # (?:...) → 비캡처 그룹, 매칭은 하지만 캡처(추출)는 하지 않음.
            # \w+ → 한 개 이상의 문자, 숫자, 밑줄이 조합된 단어를 찾음.
            SigDefinePattern = r";\s*(?:signal|constant|variable)\s+(\w+)"
            Sig_file = re.findall(SigDefinePattern, text_file, re.IGNORECASE)

            # select types
            TypePattern = r';\s*TYPE\s+(\w+)\s+is'
            type_file = re.findall(TypePattern, text_file, re.IGNORECASE)

            # -- inout port name
            # inout 포트 정의 패턴
            ioblock_pattern = r"entity\s+.*?architecture\s+"
            ioblock_match = re.search(ioblock_pattern, text_file, re.DOTALL | re.IGNORECASE)

            # select input, output ports
            inoutDefinePattern = r"(\w+)\s*:\s*(?:in|out|inout)\s+\w+"
            inout_define_pattern = r"(\w+)\s*:\s*(?:in|out|inout)\s+\w+"
            if ioblock_match:
                ioblock = ioblock_match.group(0)  # entity와 architecture 사이의 텍스트 추출
                inout_file = re.findall(inout_define_pattern, ioblock, re.IGNORECASE)
            else:
                inout_file = []


            # -- select generic
            # GenericPattern = r'generic\s*\(\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*[^;]*;'
            # # GenericPattern = r'generic\s*\(\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*[a-zA-Z_][a-zA-Z0-9_]*\s*(?::=\s*[^;]*)?\s*\)'
            # Generic_file = re.findall(GenericPattern, text_file)
            Generic_file = []

            generic_block_pattern = r'generic\s*\(\s*([\s\S]*?)\s*\)'
            generic_block = re.search(generic_block_pattern, text_file)
            if generic_block:
                generic_block = generic_block.group(1)

                # Pattern to match individual generic parameter names
                parameter_pattern = r'([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*[a-zA-Z_][a-zA-Z0-9_]*'
                Generic_file = re.findall(parameter_pattern, generic_block)

            tokens_file = Sig_file + inout_file + type_file + Generic_file

            # Put all the tokens in lowercase
            tokens_lowercase = [token.lower() for token in tokens_file]
            
            # Consider tokens which are no keywords and not numeric
            for token in tokens_lowercase:
                signals.append(token)
            # Remove dupicated signals
            signals = list(dict.fromkeys(signals))

    return signals

def decode_ff_string(encoded_str, obf):
    try:
        # Base64 디코딩 시도 (ff 이후의 문자열만 디코딩)
        decoded_str = obf.deobfuscation(encoded_str)
        return decoded_str
    except Exception as e:
        # 디코딩 실패 시 원래 문자열 반환
        print(f"Decoding failed for {encoded_str}: {e}")
        return encoded_str


def DeObfuscation_files(SRC_Dir, DIST_Dir, files, obf):

    # 파일 처리 카운트 초기화
    i = 0
    
    for next_file_input in files:
        # 원본 디렉토리 대비 상대 경로 계산
        relative_path = next_file_input.relative_to(SRC_Dir)
        # 출력 파일을 저장할 경로 설정
        next_file_output = DIST_Dir / relative_path
        # 출력 디렉토리가 없으면 생성
        next_file_output.parent.mkdir(parents=True, exist_ok=True)

        i += 1  # 처리한 파일 개수 증가
        with open(next_file_input, "rt", encoding='utf-8') as file_input, \
             open(next_file_output, "wt", encoding='utf-8') as file_output:
            print(f"Processing file: {next_file_input}")
            print(f"{i}/{len(files)} Files obfuscated")

            # 전체 파일 내용을 읽기
            text = file_input.read()

            # 지정된 문자열 패턴들에 줄바꿈 추가
            keywords = [';', ',', ' is ']
            for keyword in keywords:
                text = text.replace(keyword, keyword + '\n')           

            # ff로 시작하는 50자리 문자열을 "--"로 변경
            ff_pattern = r'\bff[a-zA-Z0-9]{48}\b'

            # 발견된 문자열을 decode_ff_string 함수로 변환
            text = re.sub(ff_pattern, lambda m: decode_ff_string(m.group(0), obf), text)

            # 수정된 내용을 출력 파일에 저장 (줄바꿈 없이 한 줄로 저장)
            file_output.write(text)

    print("All files have been successfully obfuscated.")



obf = Obfuscation()

if (os.path.exists(SRC_Dir)):
    files = list_All_Vhd_Files(SRC_Dir)
    DeObfuscation_files(SRC_Dir, DIST_Dir, files, obf)
else:
    print("ERROR: Source folder doesn't exist")

