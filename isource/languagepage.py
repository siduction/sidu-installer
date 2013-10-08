'''
Created on 13.03.2013

@author: hm
'''

from webbasic.page import Page, PageResult
from session import Session

class LanguagePage(Page):
    '''
    Allows the selection of the language.
    '''
    def __init__(self, session):

        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, 'language', session)
        self._searchResults = None

    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField('language')

    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        body = self.fillStaticSelected("language", body)
        return body
    
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == 'button_select':
            language = self._pageData.get('language')
            self._session.log('language: ' + language)
            if language != None:
                self._globalPage._pageData.put('language', language)
                self._session._language = language
                pageResult = PageResult(None, '!language', 
                    'LanguagePage.handleButton()')
        else:
            self.buttonError(button)
            
        return pageResult
        