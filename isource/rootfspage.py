'''
Created on 10.03.2013

@author: hm
'''

from webbasic.page import Page
from isource.diskinfopage import DiskInfoPage

class RootFSPage(Page):
    '''
    Handles the page allowing selecting the root partition.
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, "rootfs", session)
        self._diskInfo = DiskInfoPage(self)

    def afterInit(self):
        '''Will be called after all initializations are done.
        Note: self._globalPage will be set after the constructor.
        '''
        
        self._btrfsAndGpt = False
        if self.getField("filesys") == "btrfs":
            partition = self.getField("root")
            self._btrfsAndGpt = self._diskInfo.hasGPT(partition)
        
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("root")
        self.addField("filesys")
        # fields used by diskinfopage:
        self.addField("infostate")
        self.addField("confirmation")
        self.addField("disk2")
        self.addField("confirmation", None, 0)

   
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        content = ""
        value = self.getField("filesys") 
        if value == "btrfs":
            content = self._snippets.get("BTRFS_INFO")
        body = body.replace("{{BTRFS_INFO}}", content)
        body = body.replace("{{WAIT_FOR_PARTINFO}}", "");
        body = self.fillStaticSelected("filesys", body)
        disks = self._diskInfo.getRootFsDevices()
        body = self.fillDynamicSelected("root", disks, None, body)
        state = self.getField("infostate")
        content = self._diskInfo.buildInfoSwitch(state)
        body = body.replace("{{INFO}}", content)
        content = ""
        if self._btrfsAndGpt:
            content = self._snippets.get("BTRFS_WARNING")
            content = self.fillStaticSelected("confirmation", content)
        body = body.replace("{{BTRFS_WARNING}}", content);
        return body
    
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if (button == "button_infostate" or button == "button_activate2" 
                or button == "button_refresh"):
            pass
        elif button == 'button_prev':
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                'rootfs.handleButton')
        elif button == 'button_next':
            rootPartition = self.getField("root")
            rootFs = self.getField("filesys")
            ix = self.findIndexOfOptions("filesys")
            ix2 = self.findIndexOfOptions("confirmation")
            if ix == 0:
                rootFs = "-"
            if rootPartition == "-":
                self.putError("root", "rootfs.err_empty_root")
            elif (self._btrfsAndGpt and ix2 != 1) :
                pass
            else:
                self._globalPage.putField("root", rootPartition)
                self._globalPage.putField("rootfs", rootFs)
                pageResult = self._session.redirect(
                    self.neighbourOf(self._name, False), 
                    'rootfs.handleButton')
        else:
            self.buttonError(button)
            
        return pageResult
    