'''
Created on 16.03.2013

@author: hm
'''
import re

from webbasic.page import Page
from subprocess import check_output

class UserPage(Page):
    '''
    Handles the search page
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, 'user', session)
        self._searchResults = None
        self._errorPrefix = self._snippets.get('ERROR_PREFIX')
        self._errorSuffix = self._snippets.get('ERROR_SUFFIX')

    def afterInit(self):
        '''Will be called after all initializations are done.
        Note: self._globalPage will be set after the constructor.
        '''
        value = self.getField("show_passwd")
        self._showPasswd = value != "F"

    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("root_pass")
        self.addField("root_pass2")
        self.addField("real_name")
        self.addField("name")
        self.addField("pass")
        self.addField("pass2")
        self.addField("show_passwd", "F", None, "b")
        
    def encodePassword(self, clearText):
        '''Encodes the text into a SHA256 hash.
        This is used by the install script.
        @param cleartext: the password
        @return: the SHA256 hash
        '''
        # $handle = popen("/usr/bin/mkpasswd --method=SHA-256 '$clearText'" , 'r');
        hashValue = check_output(["/usr/bin/mkpasswd", "--method=SHA-256", clearText])
        return hashValue.rstrip()

    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        key = "ROOT_PW_DISPLAYED" if  self._showPasswd else "ROOT_PW"
        content = self._snippets.get(key)
        body = body.replace("{{ROOT_PW}}", content)
        key = "USER_PW_DISPLAYED" if  self._showPasswd else "USER_PW"
        content = self._snippets.get(key)
        body = body.replace("{{USER_PW}}", content)
        return body
    
    def doSearch(self, phrases):
        '''Runs a search and stores the result in _searchResults
        @param phrases: the search phrases
        '''
        self._searchResults = 'Nothing searched, nothing found'
        
    def validate(self):
        password = self._pageData.get('root_pass')
        err = False
        if len(password) < 6:
            err = self._pageData.putError('root_pass', '.too_short')
        if not self._showPasswd:
            password2 = self._pageData.get('root_pass2')
            if password != password2:
                err = self._pageData.putError('root_pass2', '.not_equal')

        password = self._pageData.get('pass')
        password2 = self._pageData.get('pass2')
        if len(password) < 6:
            err = self._pageData.putError('pass', '.too_short')
        elif not  self._showPasswd and password != password2:
            err = self._pageData.putError('pass2', '.not_equal')
            
        login = self._pageData.get('name')
        if not re.match(r'^[a-zA-Z][-a-zA-Z0-9_.]*$', login):
            err = self._pageData.putError('name', '.wrong_chars')
        return not err
    
    def storePassword(self, fieldLocal, fieldGlobal):
        '''Stores the hash of a password in the global page.
        @param fieldLocal: the field containing the password
        @param fieldGlobal: the field in the global page
        '''
        value = self.getField(fieldLocal)
        hashValue = self.encodePassword(value)
        self._globalPage.putField(fieldGlobal, hashValue)
      
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == "button_activate":
            pass
        elif button == 'button_next':
            if self.validate():
                self.storeAsGlobal("real_name", "realname")
                self.storeAsGlobal("name", "login")
                self.storePassword("root_pass", "rootpw")
                self.storePassword("pass", "userpw")
                pageResult = self._session.redirect(
                    self.neighbourOf(self._name, False), 
                    'homepage.handleButton')
        elif button == 'button_prev':
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                'homepage.handleButton')
        else:
            self.buttonError(button)
            
        return pageResult
