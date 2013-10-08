'''
Created on 10.03.2013

@author: hm
'''

from webbasic.page import Page
from isource.diskinfopage import DiskInfoPage

class PartitionPage(Page):
    '''
    Handles the page allowing changing the partitions.
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, 'partition', session)
        self._diskInfo = DiskInfoPage(self)

    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("partman")
        self.addField("disk")
        # fields used by diskinfopage: 
        self.addField("disk2")
        self.addField("infostate", "NO")
   
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        body = self.fillStaticSelected("partman", body)
        disks = self._diskInfo.getRealDisks()
        body = self.fillDynamicSelected('disk', disks, None, body)
        state = self.getField("infostate")
        content = self._diskInfo.buildInfoSwitch(state)
        body = body.replace("{{INFO}}", content)
        return body
    
    def handleExecute(self):
        '''Handles the button "execute".
        @return:    None: error occurred
                    a PageResult instance: another page follows
        '''
        rc = None
        answer = self._session._shellClient.buildFileName("part", ".ready")
        disk = self.getField("disk")
        program = self.getField("partman")
        value = self._session.getConfigWithoutLanguage("partition.cmd_" + program)
        (allDisksAllowed, options, command, params) = self.autoSplit(value)
        # All disks?
        allDisks = self._session.getConfig("partition.txt_all")
        if disk == allDisks:
            disk = ""
        if allDisksAllowed != "y" and disk == "":
            self.putError("disk", "partition.err_all_not_allowed")
        else:
            if disk != "":
                disk = "/dev/" + disk
            params = params.replace("{{disk}}", disk)
            params = self.autoSplit(params)
            self.execute(answer, options, command, params, 0)
            # Partition info is potentially changed. Reload necessary:
            self._diskInfo.reload()
            intro = "wait.txt_intro"
            description = "partition.description_wait"
            progress = None
            rc = self.gotoWait(self._name, answer, progress, intro, [program],
                description, None)
        return rc
        
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == "button_infostate":
            pass
        elif button == "button_refresh":
            pass
        elif button == "button_reload":
            self._diskInfo.reload()
        elif button == "button_exec":
            pageResult = self.handleExecute()
        elif button == "button_auto":
            self.addPage("autopart", "partition")
            self.delPage("partition")
            self.delPage("rootfs")
            self.delPage("mountpoint")
            pageResult = self._session.redirect("autopart", "")
        elif button == "button_prev":
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                "partition.handleButton")
        elif button == "button_next":
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, False), 
                "partition.handleButton")
        else:
            self.buttonError(button)
            
        return pageResult
    