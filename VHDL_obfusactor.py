import re
from Obfuscation import Obfuscation
import os
from pathlib import Path
import argparse

SRC_Dir = "input"
DIST_Dir = "output"

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
            # select signal, constant, variable
            # (?:...) → 비캡처 그룹, 매칭은 하지만 캡처(추출)는 하지 않음.
            # \w+ → 한 개 이상의 문자, 숫자, 밑줄이 조합된 단어를 찾음.
            SigDefinePattern = r";\s*(?:signal|constant|variable)\s+(\w+)"
            Sig_file = re.findall(SigDefinePattern, text_file, re.IGNORECASE)

            # select types
            TypePattern = r';\s*TYPE\s+(\w+)\s+is'
            type_file = re.findall(TypePattern, text_file, re.IGNORECASE)

            # select input, output ports
            inoutDefinePattern = r"(\w+)\s*:\s*(?:in|out|inout)\s+\w+"
            inout_file = re.findall(inoutDefinePattern, text_file, re.IGNORECASE)

            # select generic
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

import re

def Obfuscation_files(SRC_Dir, DIST_Dir, source_to_obfusacte, signals, obfuscated_signals):
    """
    파일을 읽고 특정 signal 단어들을 난독화된 단어로 대체하여 출력 디렉토리에 저장하는 함수.
    또한, 연속된 스페이스, 탭, 개행 문자를 하나의 스페이스로 변환.

    Args:
        SRC_Dir (str): 원본 파일이 있는 디렉토리 경로.
        DIST_Dir (str): 난독화된 파일을 저장할 디렉토리 경로.
        source_to_obfusacte (list): 난독화할 파일 목록.
        signals (list): 원본 신호 이름 리스트.
        obfuscated_signals (list): 난독화된 신호 이름 리스트 (signals와 1:1 매칭).
    """

    # 파일 처리 카운트 초기화
    i = 0
    
    for next_file_input in source_to_obfusacte:
        # 원본 디렉토리 대비 상대 경로 계산
        relative_path = next_file_input.relative_to(SRC_Dir)
        # 난독화된 파일을 저장할 경로 설정
        next_file_output = DIST_Dir / relative_path
        # 출력 디렉토리가 없으면 생성
        next_file_output.parent.mkdir(parents=True, exist_ok=True)

        i += 1  # 처리한 파일 개수 증가
        with open(next_file_input, "rt", encoding='utf-8') as file_input, \
             open(next_file_output, "wt", encoding='utf-8') as file_output:
            print(f"Processing file: {next_file_input}")
            print(f"{i}/{len(source_to_obfusacte)} Files obfuscated")

            # 전체 파일 내용을 읽기
            text = file_input.read()

            # 주석 제거: '--'로 시작하는 주석을 삭제
            text = re.sub(r"--.*?$", "", text, flags=re.MULTILINE)

            # 줄바꿈 포함 연속된 스페이스, 탭, 개행 문자를 하나의 스페이스로 변환
            text = re.sub(r"[\s\t\n\r]+", " ", text).strip()

            # 원본 신호 이름을 난독화된 이름으로 대체
            for original, obfuscated in zip(signals, obfuscated_signals):
                regex = r"\b" + re.escape(original) + r"\b"  # 정확한 단어 일치
                insensitive_regex = re.compile(regex, re.IGNORECASE)  # 대소문자 무시
                text = insensitive_regex.sub(obfuscated, text)

            # 수정된 내용을 출력 파일에 저장 (줄바꿈 없이 한 줄로 저장)
            file_output.write(text)

    print("All files have been successfully obfuscated.")

def Write_dumpfile(DIST_Dir, signals, obfuscated_signals):
    # Dump json containing the old and new signals in out_directory/dump.txt
    # The result is an array of objects like {original_signal : "...", obfuscated_signal: "..."}
    with open(DIST_Dir + "dump.txt", "wt", encoding='utf-8') as file_dump:
        file_dump.write("[\n")
        for i in range(len(signals)):
            si = signals[i]
            obf = obfuscated_signals[i]
            line = f"\t{{\n\t\t\"original_signal\": \"{si}\",\n\t\t\"obfuscated_signal\" : \"{obf}\"\n\t}},\n"
            file_dump.write(line)
        file_dump.write("]")

obf = Obfuscation()

if (os.path.exists(SRC_Dir)):
    files = list_All_Vhd_Files(SRC_Dir)
    signals = get_token(files)
    # Generate an obfuscated version for each string
    obfuscated_signals = [obf.obfuscate(signal) for signal in signals]
    Obfuscation_files(SRC_Dir, DIST_Dir, files, signals, obfuscated_signals)
    Write_dumpfile(DIST_Dir, signals, obfuscated_signals)
    print('--------------- Job Done Successfully!')
else:
    print("ERROR: Source folder doesn't exist")

