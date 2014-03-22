'''
Created on 10.03.2013

@author: hm
'''
import os.path
from webbasic.page import Page
from basic.shellclient import SVOPT_BACKGROUND, SVOPT_DEFAULT

class PacketPage(Page):
    '''
    Handles the page allowing changing the partitions.
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, 'packet', session)
        self._firmwareFile = (self._session.getConfigWithoutLanguage(".dir.temp") 
            + "fwdetect.txt")
        self._nodeLog = "public/firmware_log.txt"
        self._installationLog = (self._session._tempDir + self._nodeLog)
        self._missingModules = None
        self._installedModules = None
        self._hasInfo = False

    def afterInit(self):
        '''Will be called after all initializations are done.
        '''
        # the constructor is to early for access to self._globalPage
        self._hasInfo = os.path.exists(self._firmwareFile)
        if self._hasInfo:
            self.readFirmwareFile()
        else:
            self.execute(self._firmwareFile, SVOPT_BACKGROUND, "firmware",
                "info", 0)        

    def readFirmwareFile(self):
        '''Reads the file created by the shellserver.
        Format: +<installed_modules> or <missing_modules>
        Example of a file:
        +|ath3k|r8169 
        amd64-microcode|apt-get install amd64-microcode
        radeon
        '''
        if os.path.exists(self._firmwareFile):
            with open(self._firmwareFile, "r") as fp:
                self._missingModules = []
                self._installedModules = ""
                for module in fp:
                    module = module.rstrip()
                    if module.startswith("+"):
                        self._installedModules = module.replace("|", " ")[1:]
                    else:
                        self._missingModules.append(module)
            fp.close()
    
    def nonFreeIsAvailable(self):
        '''Tests whether the non-free repositiory is installed.
        @return: True: yes
                False: otherwise
        '''
        rc = False
        answer = self._session._shellClient.buildFileName("nf", ".ready")
        program = 'nonfree'
        params = 'info'
        self.execute(answer, SVOPT_DEFAULT, program, params, 10)
        if os.path.exists(answer):
            size = os.path.getsize(answer)
            rc = size > 1
            self._session.deleteFile(answer)
        return rc
        
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        pass
        # Hidden fields:
   
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
            rc = self._snippets.get("TABLE_MISSED")
        elif what == "rows":
            rc = 0 if self._missingModules == None else len(self._missingModules)
        elif what == "cols":
            # module statement action
            value = self._missingModules[ixRow]
            statements = value.split("|")
            module = statements[0]
            statements = "<xml>" + "<br/>".join(statements[1:]) 
            button = "<xml>" + self._snippets.get("BUTTON_INSTALL")
            button = button.replace("{{no}}", str(ixRow))
            rc = [module, statements, button]
        return rc
    
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        snippet = "SOURCE_FOUND" if self.nonFreeIsAvailable() else "SOURCE_MISSED"
        content = self._snippets.get(snippet)
        body = body.replace("{{SOURCES}}", content)
        content = ""
        if self._missingModules != None:
            content = self._snippets.get("FOUND_FIRMWARE")
            content2 = ""
            if self._installedModules != "":
                content2 = self._snippets.get("INSTALLED_FW")
                content2 = content2.replace("{{installed}}", self._installedModules)
            content = content.replace("{{INSTALLED_FW}}", content2)
            content2 = ""
            content3 = ""
            if len(self._installedModules) > 0:
                content2 = self._snippets.get("FW_SEPARATOR")
                content3 = self._snippets.get("MISSING_FW")
            content = content.replace("{{FW_SEPARATOR}}", content2)
            content = content.replace("{{MISSING_FW}}", content3)
            content2 = ""
            if len(self._missingModules) > 1:
                content2 = self._snippets.get("BUTTON_ALL")
            content = content.replace("{{BUTTON_ALL}}", content2)
            
        body = body.replace("{{FOUND_FIRMWARE}}", content)
        table = self.buildTable(self, None)
        body = body.replace("{{TABLE_MISSED}}", table)
        if not os.path.exists(self._installationLog):
            content = ""
        else:
            content = self._snippets.get("LOG_FIRMWARE")
            url = self._session._urlStatic + self._nodeLog
            content = content.replace("{{log}}", url)
        body = body.replace("{{LOG_FIRMWARE}}", content)
        return body
    
    def install(self, statements):
        '''Installs a single or all modules.
        @param statements:  the statements used for installation
        '''
        answer = self._session._shellClient.buildFileName("fw", ".ready", "public")
        options = SVOPT_BACKGROUND
        command = "firmware"
        params = ["install", statements.replace(" ", "~")]
        self.execute(answer, options, command, params, 0)
        rc = self.gotoWait("packet", answer, None, None, ["firmware-install"])
        # force rebuilding of the info file:
        self._session.deleteFile(self._firmwareFile);
        return rc
        
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == "button_contrib":
            # Show same page again:
            answer = self._session._shellClient.buildFileName("cont", ".ready")
            program = 'nonfree'
            params = 'install'
            self.execute(answer, SVOPT_DEFAULT, program, params, 0);
        elif button.startswith("button_inst"):
            statements = ""
            if button == "button_install_all":
                statements = "-all"
                for module in self._missingModules:
                    ix = module.find("|")
                    statements += module[ix:]
            else:
                ix = int(button[12:])
                if ix < len(self._missingModules):
                    statements = self._missingModules[ix]
            if statements != "":
                rc = self.install(statements)
        elif button == 'button_prev':
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                'packet.handleButton')
        elif button == 'button_next':
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, False), 
                'packet.handleButton')
        else:
            self.buttonError(button)
            
        return pageResult
    