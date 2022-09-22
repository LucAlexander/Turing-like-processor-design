import sys
import os

WRITE = 0
DIRECTION = 1
JUMP = 2
JUMP_OFFSET = 3
JUMP_PAD = 6

def pad(x):
    while len(x) < JUMP_PAD:
        x = '0'+x
    return x

def generate_instruction(instruction_set, labels):
    instruction = [0, 0, 0, 0, 0, 0]
    condition = 0
    jump = 0
    byte_offset = 0
    for t in instruction_set:
        if condition:
            byte_offset = int(t)*JUMP_OFFSET
            condition = 0
        elif t == "if":
            condition = 1
        elif jump:
            instruction[byte_offset+JUMP] = labels.index(t+':')
            jump = 0
        elif t=="->":
            jump = 1
        if t == "write":
            instruction[byte_offset+WRITE] = 1
        if t == "left":
            instruction[byte_offset+DIRECTION] = 1
    instruction[JUMP] = pad(f'{instruction[JUMP]:01b}');
    instruction[JUMP+JUMP_OFFSET] = pad(f'{instruction[JUMP+JUMP_OFFSET]:01b}');
    return ''.join(str(x) for x in instruction)

def main():
    n = len(sys.argv)
    if (n < 2):
        print("please provide a (.tur) input file")
        return
    file_i = 1
    while file_i < n:
        filename = sys.argv[file_i]
        labels = []
        with open(filename, "r") as f:
            tokens = f.read().split()
        labels = [token for token in tokens if token[-1] == ':']
        instruction_offsets = [tokens.index(label) for label in labels]
        instruction_offsets.sort()
        instructions = []
        for i, offset in enumerate(instruction_offsets):
            next_offset = len(tokens)
            if i < len(instruction_offsets)-1:
                next_offset = instruction_offsets[i+1]
            instruction = generate_instruction(tokens[offset:next_offset], ['0:']+labels)
            instructions.append(instruction)
        outfile = filename[:filename.find(".")]+".tbc"
        with open(outfile, "w+") as f:
            f.write(("0"*16) + "\n");
            f.write("\n".join(instructions)+"\n")
        print("\033[1;32mCompiled to turing bytecode:\033[33m",outfile, "\033[0m")
        os.system("cat " + outfile)
        file_i += 1

if __name__=="__main__":
    main()
