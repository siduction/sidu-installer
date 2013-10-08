'''
Created on 10.03.2013

@author: hm
'''

from webbasic.page import Page
from basic.shellclient import SVOPT_BACKGROUND
import logging, os, sys

class HomePage(Page):
    '''
    Handles the search page
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, "home", session)

    def afterInit(self):
        '''Will be called when the object is fully initialized.
        Does some preloads: time consuming tasks will be done now,
        while the user reads the introductions.
        '''
        preloaded = self.getField("preloaded")
        if preloaded != "Y":
            count = int(self._session.getConfigWithoutLanguage("preload.count"))
            for ix in xrange(count):
                value = self._session.getConfigWithoutLanguage("preload." + unicode(ix))
                cols = self.autoSplit(value)
                if len(cols) < 2:
                    self._session.error("wrong preload [ix]:" + value)
                    cols = [ "echo", "error", value ]
                answer = cols[0]
                command = cols[1]
                param = "" if len(cols) <= 2 else cols[2]
                if param.find("|") >= 0:
                    param = param.split(r'\|')
                opt = ''    
                if command.startswith("&"):
                    opt = SVOPT_BACKGROUND
                    command = command[1:]
                self.execute(answer, opt, command, param, 0, False)
            self.putField("preloaded", "y")
        
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("preloaded", "No")

    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        return body
    
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == "button_clear_config":
            self._session.clearUserData()
            self._pageData.clearFields()
            self._globalPage._pageData.clearFields()

        elif button ==  "button_usb_install":
            # background;startgui;gdisk|###DISK###|root|console
            answer = None
            options = SVOPT_BACKGROUND
            command = "startgui"
            answer = self._session._shellClient.buildFileName()
            # APPL, ARGS, USER, OPTS
            params = ["install-usb-gui.bash", "", "root", "console"]
            self.execute(answer, options, command, params, 0)
            self.gotoWait("home", answer, None, None, ["usb-install"])

        elif button == "button_next":
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, False), 
                "homepage.handleButton")
        else:
            self.buttonError(button)
            
        return pageResult
    