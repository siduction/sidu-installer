'''
Created on 10.03.2013

@author: hm
'''

from webbasic.page import Page
from isource.diskinfopage import DiskInfoPage

class MountpointPage(Page):
    '''
    Handles the page allowing changing the partitions.
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, "mountpoint", session)
        self._diskInfo = DiskInfoPage(self)
        self._errorPrefix = self._snippets.get("ERROR_PREFIX")
        self._errorSuffix = self._snippets.get("ERROR_SUFFIX")

    def initMounts(self):
        points = self._globalPage.getField("mountpoint.list")
        self._mountRows = self.autoSplit(points) if points != None and points != "" else []
        
    def afterInit(self):
        '''Will be called after all initializations are done.
        '''
        # the constructor is to early for access to self._globalPage
        self.initMounts()
        
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("add_dev")
        self.addField("add_label")
        self.addField("add_mount")
        self.addField("add_mount2")
        self.addField("mountonboot")
        self.addField("mounts")
        self.addField("partinfo")
        # fields used by diskinfopage: 
        self.addField("disk2")
        self.addField("infostate", "NO")
        # hidden fields:
        self.addField("dev_selector", "DEV")
        self.addField("point_selector")

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
            rc = self._snippets.get("TABLE_MOUNTS")
        elif what == "rows":
            rc = len(self._mountRows)
        elif what == "cols":
            item = self._mountRows[ixRow]
            (dev, point) = item.split(r':')
            label = self._diskInfo.getLabel(dev) 
            button = "<xml>" + self._snippets.get("BUTTON_DEL")
            fs = self._diskInfo.getFsSystem(dev) 
            button = button.replace("{{no}}", str(ixRow))
            self._mounts += " /dev/" + dev + ":" + point
            rc = [dev, label, fs, point, button]
        return rc
    
    def handleSelectors(self, body):
        '''Handles the device and the mountpoint selector.
        @param body: the HTML template with placeholders
        @return:     the placeholder for the selectors are replaced by the current
                     values
        '''
        devSelector = self.getField("dev_selector")
        (devs, labels) = self._diskInfo.getMountPartitions(self._mountRows)
        if devSelector == "DEV":
            content = self._snippets.get("DEVICE")
            content = self.fillDynamicSelected("add_label", devs, None, content)
            body = body.replace("{{DEV_SELECTOR}}", content)
            body = body.replace("{{button_dev_selector}}", 
                self._session.getConfig("mountpoint.txt_button_label"))
        else:
            content = self._snippets.get("LABEL")
            # Remove the empty labels:
            ix = len(labels) - 1
            while ix >= 0:
                if len(labels[ix]) == 0:
                    del labels[ix]
                    del devs[ix]
                ix -= 1
                    
            content = self.fillDynamicSelected("add_label", labels, devs, content)
            body = body.replace("{{DEV_SELECTOR}}", content)
            body = body.replace("{{button_dev_selector}}", 
                self._session.getConfig("mountpoint.txt_button_device"))

        pointSelector = self.getField("point_selector")
        if pointSelector == "TEXT":
            body = body.replace("{{POINT_SELECTOR}}", self._snippets.get("TEXT"))
            body = body.replace("{{button_point_selector}}", 
                self._session.getConfig("mountpoint.txt_button_combo"))
        else:
            content = self._snippets.get("COMBO")
            content = self.fillStaticSelected("add_mount", content)
            body = body.replace("{{POINT_SELECTOR}}", content)
            body = body.replace("{{button_point_selector}}", 
                self._session.getConfig("mountpoint.txt_button_text"))
        return body
    
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        body = self.handleSelectors(body)
        body = self.fillStaticSelected("mountonboot", body)
        devs = self._diskInfo.getMountPartitions(self._mountRows)[0]
        body = self.fillDynamicSelected("add_dev", devs, None, body)
        self._mounts = ""
        table = self.buildTable(self, None)
        self._globalPage.putField("mountpoints", self._mounts.lstrip())
        body = body.replace("{{TABLE_MOUNTS}}", table)
        state = self.getField("infostate")
        content = self._diskInfo.buildInfoSwitch(state)
        body = body.replace("{{INFO}}", content)
        return body
    
    def addMountPoint(self):
        '''Adds the current device/mountpoint relation to the list.
        '''
        devSelector = self.getField("dev_selector")
        field = "add_dev" if devSelector == "DEV" else "add_label"
        dev = self.getField(field)
        pointSelector = self.getField("point_selector")
        field = "add_mount2" if pointSelector == "TEXT" else "add_mount"
        point = self.getField(field)
        if not point.startswith("/"):
            self._pageData.putError("add_mount2", "mountpoint.err_wrong_mount")
        else:
            points = self._globalPage.getField("mountpoint.list")
            points += ";" + dev + ":" + point
            self._globalPage.putField("mountpoint.list", points)
            self.initMounts()
            
        
    
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == "button_add":
            self.addMountPoint()
        elif button == "button_dev":
            devSelector = self.getField("dev_selector")
            devSelector = "LABEL" if devSelector == "DEV" else "DEV"
            self.putField("dev_selector", devSelector)
        elif button == "button_point":
            pointSelector = self.getField("point_selector")
            pointSelector = "COMBO" if pointSelector == "TEXT" else "TEXT"
            self.putField("point_selector", pointSelector)
        elif button == "button_refresh":
            pass
        elif button == "button_infostate":
            # Show same page again:
            pass
        elif button.startswith("button_del_"):
            ix = int(button[11:])
            if ix < len(self._mountRows): 
                del self._mountRows[ix]
                points = "" if len(self._mountRows) == 0 else self.autoJoinArgs(self._mountRows)
                self._globalPage.putField("mountpoint.list", points)
        elif button == "button_prev":
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                "mountpoint.handleButton")
        elif button == "button_next":
            self.storeAsGlobal("mountonboot", "mountonboot")
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, False), 
                "mountpoint.handleButton")
        else:
            self.buttonError(button)
            
        return pageResult
