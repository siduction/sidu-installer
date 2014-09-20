'''
Created on 10.03.2013

@author: hm
'''

from webbasic.page import Page

class NetworkPage(Page):
    '''
    Handles the page allowing changing the partitions.
    '''
    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, 'network', session)

    def afterInit(self):
        '''Will be called after all initializations are done.
        Note: self._globalPage will be set after the constructor.
        This method can be overridden.
        '''
        field = self.getField("host")
        if field == None:
            field = self._session.getConfigWithoutLanguage("network.default_host")
            self.putField("host", field)

    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("host")
        self.addField("ssh", None, 1)
   
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        body = self.fillStaticSelected("ssh", body)
        return body
    
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == 'button_prev':
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                'network.handleButton')
        elif button == 'button_next':
            self.storeAsGlobal("host", "host")
            ix = self.findIndexOfOptions("ssh")
            value = "y" if ix == 0 else "n" 
            self._globalPage.putField("ssh", value)
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, False), 
                'network.handleButton')
        elif button == "button_infostate":
            # Show same page again:
            pass
        else:
            self.buttonError(button)
            
        return pageResult
    