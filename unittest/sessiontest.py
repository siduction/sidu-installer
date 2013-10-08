'''
Created on 09.03.2013

@author: hm
'''
from unittest import TestCase, main

from source.session import Session
from pyunit.aux import Aux

class SessionTest(TestCase):

    def setUp(self):
        self._session = Session(Aux.getRequest())
    
    def testGetTemplate(self):
        content = self._session.getTemplate('pageframe.html')
        self.assertTrue(content.find('body') > 0)
        
    def testGetButton(self):
        html = self._session.getButton('prev')
        self.assertTrue(html.find('button_prev"') > 0)
        self.assertTrue(html.find(u'value="Zur') > 0)
        html = self._session.getButton('next')
        self.assertTrue(html.find('button_next"') > 0)
        self.assertTrue(html.find('value="Weiter') > 0)
        
    def testbuildNavigationButtons(self):
        body = '{{.gui.button.prev}}\n{{.gui.button.next}}'
        html = self._session.buildNavigationButtons('home', body)
        self.assertFalse(html.find('button_prev') > 0)
        self.assertTrue(html.find('button_next') > 0)
        
        html = self._session.buildNavigationButtons('partition', body)
        self.assertTrue(html.find('button_prev') > 0)
        self.assertTrue(html.find('button_next') > 0)
        
        html = self._session.buildNavigationButtons('run', body)
        self.assertTrue(html.find('button_prev') > 0)
        self.assertFalse(html.find('button_next') > 0)
    
    def testBuildInfo(self):
        self._session.log('MyMessage1')
        self._session.error('MyError1')
        self._session.log('MyMessage2')
        self._session.error('MyError2')
        body = '{{INFO}}'
        html = self._session.buildInfo(body)
        self.assertTrue(html.find('MyError1') > 0)
        self.assertTrue(html.find('MyMessage2') > 0)
        self.assertTrue(html.find('MyError2') > 0)
        self.assertTrue(html.find('MyMessage2') > 0)

        self._session._logMessages = ['Abc']
        self._session._errorMessages = []
        html = self._session.buildInfo(body)
        self.assertTrue(html.find('Abc') > 0)
        
        self._session._logMessages = []
        self._session._errorMessages = ['Error2']
        html = self._session.buildInfo(body)
        self.assertTrue(html.find('Error2') > 0)
        
        self._session._logMessages = []
        self._session._errorMessages = []
        html = self._session.buildInfo(body)
        self.assertFalse(html.find('class="error"') > 0)
        
    def testReplaceInPageFrame(self):
        self._session.log('MyMessage1')
        body = '<form action="{{!form.url}}"> {{INFO}} {{.gui.button.next}}'
        html = self._session.replaceInPageFrame('home', body)
        self.assertTrue(html.find('MyMessage1') > 0)
        self.assertTrue(html.find('button_next') > 0)
        self.assertTrue(html.find('action="/home') > 0)

    def testNeighbourOf(self):
        self.assertEquals(None, self.neighbourOf('home', True))
        self.assertEquals('partition', self.neighbourOf('home', False))
        
if __name__ == "__main__":
    #import sys;sys.argv = ['', 'Test.testName']
    main()