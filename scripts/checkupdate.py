#! /usr/bin/python

'''
Tests whether a newer version of the sidu-installer is available.
Result: a file (name given by an argument) with this format:

Usage:
checkupdate.py <answer_file>

Example:
.hasNetwork=True
sidu-installer=(keine) 2014.01.27
sidu-base=2014.01.05.2 2014.01.09
'''
from subprocess import check_output
import re, sys, os.path

class UpdateTester:
    '''Tests whether a newer version of the sidu-installer is available.
    '''
    def __init__(self, answer):
        '''Constructor.
        @param answer:    name of the answer file, e.g. /tmp/answer.txt
        '''
        self._answer = answer
        if os.path.exists(self._answer):
            os.unlink(self._answer)
        self._network = self.testNetwork()
        self._currentVersion = dict()
        self._availableVersion = dict()
        self._packets = ["fll-installer", "pywwetha", "sidu-base", 
                         "sidu-installer", "sidu-disk-center"]
        
    def testNetwork(self):
        '''Tests whether the network is working.
        @return: true: network is working<br>
                 false: otherwise
        '''
        rc = False
        try:
            output = check_output(["dig", "siduction.org", "+time=1", "+tries=1"])
            rc = output.find("connection timed out") < 0
        except:
            pass 
        return rc

    def getVersion(self, line):
        '''Return the version from a output line of "apt-cache policy".
        @param line:    the line to inspect
        @return: "" No version found
                otherwise: the version string, e.g. 2014.01.03
        '''
        matcher = re.match(r'[^:]+:\s+(\S+)', line)
        rc = "" if matcher == None else matcher.group(1)
        return rc
    
    def getVersionsOfPackage(self, package):
        '''Gets the versions of a package.
        @param package:    name of the package to test
        '''
        try:
            output = check_output(["apt-cache", "policy", package])
            lines = output.split("\n")
            self._currentVersion[package] = self.getVersion(lines[1]) 
            self._availableVersion[package] = self.getVersion(lines[2]) 
        except:
            pass
        print(package + ": " + self._currentVersion[package] + " / " + self._availableVersion[package]) 
       
    def getVersions(self):
        '''Detects the versions of the interesting packages.
        '''
        for package in self._packets:
            self.getVersionsOfPackage(package) 
            
    def writeVersion(self, packet, fp):
        '''Writes the versions of a package.
        @param packet:    name of the package
        @param fp:        file pointer to write
        '''
        if packet in self._availableVersion:
            available = self._availableVersion[packet]
            current = self._currentVersion[packet]
            if available != current:
                fp.write("{:s}={:s} {:s}\n".format(packet, current, available))
            
    def writeAnswer(self):
        '''Writes the answer file.
        '''
        tempFile = self._answer + ".tmp"
        with open(tempFile, "w") as fp:
            fp.write(".hasNetwork={:s}\n".format(str(self._network)))
            if self._network:
                for packet in self._packets:
                    self.writeVersion(packet, fp)
            fp.close()
        os.rename(tempFile, self._answer)
        
def main(argv):
    if len(argv) < 2:
        print("usage: {:s} <answer_file>".format(argv[0]))
    else:
        answer =  argv[1]
        tester = UpdateTester(answer)
        tester.getVersions()
        tester.writeAnswer()
        fn = answer + ".pending"
        if os.path.exists(fn):
            os.unlink(fn)
            print("deleted: " + fn)
        
if __name__ == "__main__":
    main(sys.argv)
