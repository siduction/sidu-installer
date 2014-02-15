#! /usr/bin/python
# coding=UTF-8
'''
Created on 13.04.2013

@author: hm
'''
import unittest

from updatecheck import main, UpdateTester
#from pyunit.aux import Aux
from util.util import Util;
import os.path, re

class Test(unittest.TestCase):


    def setUp(self):
        self._appl = 'test_installer'

    def tearDown(self):
        pass

    def testNoArgs(self):
        main(["/usr/bin/update.py"])

    def assertRegex(self, line, regex):
        self.assertTrue(re.match(regex, line))
        
    def checkContent(self, fn):
        self.assertTrue(os.path.exists(fn))
        content = Util.readFileAsList(fn, True)
        for line in content:
            if line.startswith("."):
                self.assertRegex(line, r'^\.hasNetwork=(True|False)')
            else:
                self.assertRegex(line, 
                    r'^(sidu-base|sidu-installer|pywwetha)=\S+ [.\d]+')
                
    def testMain(self):
        fn = "/tmp/updatetest.answer"
        if os.path.exists(fn):
            os.unlink(fn)
        main(["/usr/bin/update.py", fn])
        self.checkContent(fn)
        main(["/usr/bin/update.py", fn])
        self.checkContent(fn)

if __name__ == "__main__":
    unittest.main()