'''
Created on 10.03.2013

@author: hm
'''

from webbasic.page import Page

class ExpertPage(Page):
    '''
    Handles the expert page
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, "expert", session)
 
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        if self.isExpert():
            content = self._snippets.get("UNSET_EXPERT")
        else:
            content = self._snippets.get("SET_EXPERT")
        body = body.replace("{{BUTTON}}", content)  
        return body
    
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == 'button_set_expert':
            self._globalPage.putField('expert', 'T')
        elif button == 'button_unset_expert':
            self._globalPage.putField('expert', 'F')
        else:
            self.buttonError(button)
        self._globalPage.putField('.pages', '')
            
        return pageResult
    