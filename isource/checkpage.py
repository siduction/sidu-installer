'''
Created on 13.03.2013

@author: hm
'''
import operator

from webbasic.page import Page
from webbasic.configcheck import ConfigChecker

class CheckPage(Page):
    '''
    Allows the selection of the language.
    '''
    def __init__(self, session):

        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, 'check', session)
        self._resultBody = None
        self._resultTitle = None

    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField('language')

        
    def checkConfig(self):
        checker = ConfigChecker(self._session)
        self._resultTitle = self._session.getConfig('check.config.title')
        self._resultBody = checker.checkConfig(self.getField('language'),
            self._snippets.get('KEY_DIFF'), self._snippets.get('KEY_SEPARATOR'))
     
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        field = 'language'
        curLanguage = self.getField(field)
        values = []
        for lang in self._session._supportedLanguages:
            if lang != 'en':
                values.append(lang)
        if curLanguage == None:
            ix = 0
        else:
            ix = operator.indexOf(values, curLanguage)
        body = self.fillOpts(field, values, None, ix, body)
        if self._resultTitle == None:
            title = ''
            result = ''
        else:
            title = self._snippets.get('RESULT_TITLE')
            title = title.replace('{{title}}', self._resultTitle)
            if self._resultBody == None:
                result = self._snippets.get('EMPTY_BODY')
            else:
                result = self._resultBody
        body = body.replace('{{RESULT_TITLE}}', title)
        body = body.replace('{{RESULT}}', result)
        return body
    
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == 'button_check_config':
            self.checkConfig()
        else:
            self.buttonError(button)
            
        return pageResult
  
          