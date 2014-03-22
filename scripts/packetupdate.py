#! /usr/bin/python
'''
Created on 26.03.2014

@author: hm
'''
import sys, subprocess, os, traceback

def main(argv):
    try:
        answer = argv[1]
        cmd = ["apt-get", "-y", "install"] + argv[2:]
        content = subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=False)
        temp = answer + ".tmp"
        os.rename(temp, answer)
    except Exception:
        content = traceback.format_exc()
    fp = open(answer, "w")
    fp.write(" ".join(cmd) + "\n")
    fp.write(content)
    fp.close()
    
if __name__ == '__main__':
    main(sys.argv)