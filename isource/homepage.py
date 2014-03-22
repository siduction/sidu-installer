'''
Created on 10.03.2013

@author: hm
'''

import os.path
from webbasic.page import Page
from basic.shellclient import SVOPT_BACKGROUND
from util.util import Util

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
        self._rowUpdates = None
        self._updateDataExists = False
        self._fnUpdateCheck = self._session._tempDir + "packetversions.txt"
        self._fnUpdateCheckPending = self._fnUpdateCheck + ".pending"
        self._hasNetwork = None
        self._nodeUpdateLog = "public/packetupdate.txt"
        self._fnUpdateLog = self._session._tempDir + self._nodeUpdateLog

    def afterInit(self):
        '''Will be called when the object is fully initialized.
        Does some preloads: time consuming tasks will be done now,
        while the user reads the introductions.
        '''
        self.startUpdateCheck()
        preloaded = self.getField("preloaded")
        if preloaded != "y":
            count = int(self._session.getConfigWithoutLanguage("preload.count"))
            for ix in xrange(count):
                value = self._session.getConfigWithoutLanguage("preload." + str(ix))
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
                    if command.startswith("&amp;"):
                        command = command[5:]
                    else:
                        command = command[1:]
                self.execute(answer, opt, command, param, 0, False)
            self.putField("preloaded", "y")
        
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        # hidden:
        self.addField("preloaded", "No")
        self.addField("waitForLog", "No")

    def startUpdateCheck(self):
        '''Starts the program to check for packet updates.
        '''
        value = self.getField("waitForLog")
        if value == "y":
            if os.path.exists(self._fnUpdateLog):
                value = "No"
                self.putField("waitForLog", value)
                self.setRefresh()
        if value != "y":
            answer = self._fnUpdateCheck
            self._updateDataExists = os.path.exists(answer)
            if not self._updateDataExists:
                if not os.path.exists(self._fnUpdateCheckPending):
                    Util.writeFile(self._fnUpdateCheckPending, None)
                    command = "checkupdate"
                    options = SVOPT_BACKGROUND 
                    # APPL, ARGS, USER, OPTS
                    params = []
                    self.execute(answer, options, command, params, 0)
                    self.setRefresh()
                
    def contentUpdateCheck(self, buildTable = True):
        '''Builds the html output with the info about the program version check.
        @param buildTable:  True: read file and build the content. 
                            False: read file content only
        @return: None or a html text with the info
        '''
        body = None
        if os.path.exists(self._fnUpdateLog):
            body = self._snippets.get("UPD_LOG")
            fn = self._session._urlStatic + self._nodeUpdateLog
            body = body.replace("{{url_log}}", fn)
        elif self._rowUpdates == None:
            fileExists = os.path.exists(self._fnUpdateCheck)
            if not fileExists:
                self._rowUpdates = None
            else:
                lines = Util.readFileAsList(self._fnUpdateCheck, True)
                for line in lines:
                    if line.startswith(".hasNetwork="):
                        self._hasNetwork = line[12] == 'T'
                        if not self._hasNetwork:
                            break
                    else:
                        if self._rowUpdates == None:
                            self._rowUpdates = []
                        self._rowUpdates.append(line.replace("=", "|").replace(" ", "|"))   
            if buildTable:
                if not fileExists:
                    body = self._snippets.get("UPD_WAIT")
                elif not self._hasNetwork:
                    body = self._snippets.get("UPD_NO_NETWORK")
                elif self._rowUpdates != None:
                    body = self.buildTable(self, None)
        return body    
        
    def buildPartOfTable(self, info, what, ixRow = None):
        '''Builds a part of a HTML element <table>.
        @param info:  not used
        @param what:  names a part of the table which will be returned
                      "Table": None or html template of table with "{{ROWS}}"
                      "Row:" None or a template with "{{COLS}}"
                      "Col": None or a template with "{{COL}}"
                      "rows": number of rows. Data type: int
                      "cols": list of column values (data type: Object)
        @param ixRow: index of the row (only relevant if what == "cols") 
        @return:      the wanted part of the table
        '''
        rc = None
        if what == "Table":
            rc = self._snippets.get("TABLE_UPDATE")
        elif what == "rows":
            rc = 0 if self._rowUpdates == None else len(self._rowUpdates)
        elif what == "cols":
            # module statement action
            value = self._rowUpdates[ixRow]
            rc = value.split("|")
        return rc

    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        if not self._updateDataExists:
            content = self._snippets.get("UPD_WAIT")
            self.setRefresh()
        else:
            content = self.contentUpdateCheck()
        body = body.replace("{{UPDATE_BODY}}", "" if content == None else content)
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
            self._session.deleteFile(self._fnUpdateCheck)
            self._session.deleteFile(self._fnUpdateCheckPending)
            self._session.deleteFile(self._fnUpdateLog)
        elif button ==  "button_update":
            value = self.getField("waitForLog")
            if value != "y" and not os.path.exists(self._fnUpdateLog):
                answer = self._fnUpdateLog
                options = SVOPT_BACKGROUND
                command = "packetupdate"
                params = []
                self.contentUpdateCheck(False)
                if self._rowUpdates != None:
                    for item in self._rowUpdates:
                        cols = item.split("|")
                        params.append(cols[0])
                    self.execute(answer, options, command, params, 0)
                    self.putField("waitForLog", "y")
                self._session.redirect("/home", 
                    "homepage.handleButton(buttonUpdate)")
        elif button == "button_update_again":
            if os.path.exists(self._fnUpdateLog):
                self._session.deleteFile(self._fnUpdateCheck)        
                self._session.deleteFile(self._fnUpdateCheckPending)        
                self._session.deleteFile(self._fnUpdateLog) 
                self.setRefresh()       
        elif button == "button_next":
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, False), 
                "homepage.handleButton")
        else:
            self.buttonError(button)
            
        return pageResult
    