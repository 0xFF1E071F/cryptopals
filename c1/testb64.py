#! /usr/bin/python2
from base64 import b64encode

hexstr = raw_input()
rawhex = []
for i in range(0, len(hexstr), 2):
    rawhex.append(chr(int(hexstr[i:i+2], base=16)))

print(b64encode(''.join(rawhex)))


