'''
Created on 10.03.2013

@author: hm
'''

import re, os.path
from webbasic.page import Page
from diskinfopage import DiskInfoPage
from util.util import Util
from basic.shellclient import SVOPT_DEFAULT

class AutoPartPage(Page):
    '''
    Handles the search page
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, "autopart", session)
        self._diskInfo = DiskInfoPage(self)
        self._freeSpaces = self._diskInfo._emptyPartitions
        self._nodeFullLog = "public/autopart_log.txt"

    def afterInit(self):
        '''Will be called when the object is fully initialized.
        Does some preloads: time consuming tasks will be done now,
        while the user reads the introductions.
        '''
        self._disks = self._diskInfo.getDisksWithSpace()
        
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("template", None, 0)
        self.addField("adisk", None, 0)
        self.addField("apartition", None, 0)
        self.addField("vg", "siduction")
        self.addField("size_boot")
        self.addField("size_root")
        self.addField("size_swap")
        self.addField("size_home")
        for ix in xrange(len(self._freeSpaces)):
            self.addField("part{:d}".format(ix), None, None, "b")
        # Hidden fields:
        self.addField("log")
        self.addField("answer")
        self.addField("progress")
                         

    def buildStandardLVM(self):
        '''Builds the HTML code for the standard LVM template.
         @return: the HTML code
        '''
        body = self._snippets.get("STD_LVM")
        #body = body.replace("{{DISK}}", self._snippets.get("DISK"))
        #body = body.replace("{{PARTITION}}", self._snippets.get("PARTITION"))
        content = self._diskInfo.buildFreePartitionTable(None)
        body = body.replace("{{PARTITIONS}}", content)
        body = body.replace("{{ACTIVATE}}", self._snippets.get("ACTIVATE"))
        body = body.replace("{{PARAMETER}}", self._snippets.get("PARAM_STD"))
        sizeAvailable = self.calcAvailableSpace()
        sizeUsed = self.getCorrectedUsedSpace()
        sizeFree =self.humanReadableSize((sizeAvailable-sizeUsed)*1024)
        sizeAvailable = self.humanReadableSize(sizeAvailable*1024)
        body = body.replace("{{size_free}}", sizeFree)
        body = body.replace("{{size_total}}", sizeAvailable)
        return body

    def buildReady(self, answer):
        '''Builds the content if the automatic partitioning has been done.
        @param answer: the file with the answer from the shell server
        '''
        content = self._snippets.get("READY")
        url = self._session._urlStatic + self._nodeFullLog
        content = content.replace("{{fullLog}}", url)        
        fileContent = self._session.readFile(answer, "===", True)
        successful = fileContent.find("+++ ") < 0
        if not successful:
            message = self._session.getConfig("autopart.txt_failed")
        else:
            message = self._session.getConfig("autopart.txt_successful")
            vg = self.getField("vg")
            value = vg + "/root"
            self._globalPage.putField("root", value)
            self._session.putUserData("rootfs", "root", value)
            self._globalPage.putField("rootfs", "-")
            self._session.putUserData("rootfs", "filesys", "-")
            mountPoints = ""
            if self.getField("size_home") != "0M":
                mountPoints = " /dev/" + vg + "/home:/home"
            if self.getField("size_boot") != "0M":
                mountPoints += " /dev/" + vg + "/boot:/boot"
            self._globalPage.putField("mountpoints", mountPoints)
            self._session.putUserData("mountpoint", "mounts", "-")
            self._globalPage.putField("mountonboot", "yes")
        content = content.replace("{{success}}", message)
        content = content.replace("{{lines}}", fileContent)
        content = content.replace("{{RETRY}}", "" if successful else self._snippets.get("RETRY"))
        return content
        
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        answer = self.getField("answer")
        progress = self.getField("progress")
        if progress != None and progress != "":
            if os.path.exists(answer):
                self.putField("progress", None)
                content = self.buildReady(answer)
            else:
                content = self._snippets.get("WAIT")
                message = self._session.getConfig("wait.txt_intro")
                message = message.replace("{{1}}", "autopart")
                content = content.replace("{{message}}", message)
                bar = self._diskInfo.buildProgress(progress)
                content = content.replace("{{PROGRESS}}", bar)
                self.setRefresh()
        elif not self._diskInfo._hasInfo:
            content = self._snippets.get("WAIT")
            message = self._session.getConfig("wait.txt_intro")
            message = message.replace("{{1}}", "partinfo")
            content = content.replace("{{message}}", message)
            progress = self._diskInfo.buildProgress()
            content = content.replace("{{PROGRESS}}", progress)
            self.setRefresh()
        else:
            self._session.trace("changeContent(): answer: {:s}".format(answer))
            if (answer != None and os.path.exists(answer)):
                content = self.buildReady(answer)          
            elif len(self._freeSpaces) == 0:
                content = self._snippets.get("NO_SPACE")
            else:
                templ = self.getField("template")
                if templ == "std":
                    content2 = self.buildStandardLVM()
                elif templ == "single":
                    content2 = ""
                else:
                    content2 = self.buildStandardLVM()
                content = self._snippets.get("ENOUGH_SPACE")
                content = self.fillStaticSelected("template", content)
                content = content.replace("{{TEMPLATE}}", content2)
        body = body.replace("{{CONTENT}}", content)
        return body

    def calcAvailableSpace(self):
        '''Calculates the sum of the selected free spaces:
        @return: the size in kBytes
        '''
        size = 0
        for ix in xrange(len(self._freeSpaces)):
            val = self.getField("part{:d}".format(ix))
            if val == "on":
                info = self._freeSpaces[ix].split('-')
                size += (int(info[2]) - int(info[1])) / 2
        return size
    
    def getCorrectedSizeValue(self, field):
        '''Returns the value of a field containing a number 
        and optional a unit suffix.
        If there is an error the field will be corrected:
        If there is no number the field will be cleared.
        If there is a wrong suffix it will be removed.
        @param field:    the name of the field
        @return: the size in kByte
        '''
        val = self.getField(field)
        size = 0
        if val != None and val != "*" and len(val) != 0:
            rexpr = re.compile(r'^(\d+)(.*)')
            matcher = rexpr.match(val)
            if matcher == None:
                val = ""
                self.putField(field, "")
            else:
                size = int(matcher.group(1))
                suffix = matcher.group(2).upper()
                unit = None
                if suffix == "K":
                    unit = 1
                elif suffix == "M":
                    unit = 1024
                elif suffix == "G":
                    unit = 1024*1024
                elif suffix == "T":
                    unit = 1024*1024*1024
                else:
                    unit = 1024
                    suffix = "M"
                self.putField(field, str(size) + suffix)
                size *= unit
        return size       
      
    def getCorrectedUsedSpace(self):
        '''Returns the sum of the sizes of all specified partitions.
        Wrong field values will be corrected. See getCorrectedSizeValue().
        @return: the sum of the sizes of boot, root, swap and home
        '''
        size = self.getCorrectedSizeValue("size_boot") 
        size += self.getCorrectedSizeValue("size_root")
        size += self.getCorrectedSizeValue("size_home") 
        size += self.getCorrectedSizeValue("size_swap")
        return size
               
    def calcStandardLVM(self):
        '''The field values will be tested for "*". 
        If given the field will set to a value that the total space is used.
        '''
        sizeUsed = self.getCorrectedUsedSpace()
        sizeFree = str((self.calcAvailableSpace() - sizeUsed) / 1024) + "M"
        if self.getField("size_boot") == "*":
            self.putField("size_boot", sizeFree)
        if self.getField("size_root") == "*":
            self.putField("size_root", sizeFree)
        if self.getField("size_swap") == "*":
            self.putField("size_swap", sizeFree)
        if self.getField("size_home") == "*":
            self.putField("size_home", sizeFree)

    def checkStandardLVM(self):
        '''Checks the validity of the input fields for the standard LVM proposal.
        '''
        MByte=1024
        GByte=1024*1024
        sizeAvailable = self.calcAvailableSpace()
        if sizeAvailable <= 4*GByte:
            home = 0
            swap = 200
            root = sizeAvailable - swap - home
        elif sizeAvailable <= 8*GByte:
            # Min: 2709 Max: 4G
            root = (2000*MByte + (sizeAvailable - 2000) * (4*GByte - 2000*MByte)
                    / (8*GByte - 2000*MByte))
            # Min: 409M Max: 819M
            swap = 200 + (sizeAvailable - 200) / 10
            # Min: 976 Max: 3276
            home = sizeAvailable - root - swap
        elif sizeAvailable <= 32*GByte:
            # min: 4G max: 16G
            root = sizeAvailable / 2;
            # min: 822M max: 2.3G
            swap = 310*MByte + sizeAvailable / 16
            # min: 3274M max: 14026M
            home = sizeAvailable - root - swap
        else:
            root = 16*GByte
            swap = 2500*MByte
            home = sizeAvailable - root - swap   
        self.getCorrectedUsedSpace()
        if self.getField("size_boot") == "":
            self.putField("size_boot", "0")
        if self.getField("size_root") == "":
            self.putField("size_root", str(root / 1024) + "M")
        if self.getField("size_swap") == "":
            self.putField("size_swap", str(swap / 1024) + "M")
        if self.getField("size_home") == "":
            self.putField("size_home", str(home / 1024) + "M")
        # Now replace the star if it exists:
        self.calcStandardLVM()
        sizeUsed = self.getCorrectedUsedSpace()
        if sizeAvailable - sizeUsed < 0:
            self.putError(None, "autopart.txt_too_much_space")
        
    
    def checkInput(self):
        '''Checks the validity of the input fields and calculates some infos.
        '''
        templ = self.getField("template")
        if templ == "std":
            self.checkStandardLVM()
        else:
            self._session.error("unknown state: " + templ)
    
    def getFlavour(self):
        rc = "siduction"
        with open("/etc/siduction-version", "r") as fp:
            for line in fp:
                cols = line.split(" ")
                rc = cols[0] + cols[1]
                break
            if line.find("kde") > 0:
                rc += "-kde"
            elif line.find("xfce") > 0:
                rc += "-xfce"
            elif line.find("lxde") > 0:
                rc += "-lxde"
            fp.close()
        return rc
        
                    
    def createStandardLVM(self):
        '''Realizes the standard LVM proposal.
        @return: None or the PageResult
        '''
        pageResult = None
        answer = self._session._shellClient.buildFileName("ap", ".ready")
        program = "autopart"
        allowInit = "YES"
        diskInfo = ""
        partitions = ""
        for ix in xrange(len(self._freeSpaces)):
            part = self._freeSpaces[ix]
            val = self.getField("part{:d}".format(ix))
            if val == "on":
                # e.g. "sdb!1-2048-888888"
                disk = part.split("!")[0]
                if disk != None and diskInfo.find(disk) < 0:
                    if diskInfo != "":
                        diskInfo += "+"
                    diskInfo += disk + ":mbr"
                if partitions != "":
                    partitions += "+"
                # e.g. "sdb!3-2048-100000"
                partitions += part.replace("!", "")
        availableSpace = self.calcAvailableSpace()
        extensionSize = self._session.nextPowerOf2(availableSpace/2024)
        vgInfo = self.getField("vg") + ":" + str(extensionSize) + "K"
        lvInfo = ""
        minSize = int(self._session.getConfigWithoutLanguage("diskinfo.root.minsize.mb"))
        size = self.getCorrectedSizeValue("size_root") / 1024
        error = False 
        flavour = self.getFlavour()
        if diskInfo == "":
            error = self.putError(None, "autopart.err_missing_partition")
        elif self.calcAvailableSpace() / 1024 < minSize:
            error = self.putError(None, "autopart.err_too_small")
        elif (size < minSize):
            error = self.putError(None, "autopart.err_too_small")
        if vgInfo.startswith(":"):
            error = self.putError(None, "autopart.err_missing_vg")
        if not error:
            lvInfo = "root:{:s}:{:d}M:ext4".format(flavour, size)
            sizeHome = self.getCorrectedSizeValue("size_home") / 1024
            sizeSwap = self.getCorrectedSizeValue("size_swap") / 1024
            sumSize = size + sizeHome + sizeSwap
            # 6 extension must be reserved:
            allUsed = sumSize * 1024 > availableSpace - 6 * extensionSize
            if sizeHome > 0:
                if allUsed and sizeSwap == 0:
                    lvInfo += ";home:home:*:ext4" 
                else:   
                    lvInfo += ";home:home:{:d}M:ext4".format(sizeHome) 
            if sizeSwap > 0:
                if allUsed:
                    lvInfo += ";swap:swap:*:swap" 
                else:
                    lvInfo += ";swap:swap:{:d}:swap".format(sizeSwap)

            progress = self._session._shellClient.buildFileName("ap", ".progress")

            params = ["stdlvm", diskInfo, allowInit, partitions, vgInfo, lvInfo,
                      progress]
        
            self.execute(answer, SVOPT_DEFAULT, program, params, 0)
            
            intro = "wait.txt_intro"
            description = None
            self.putField("answer", answer)
            self.putField("progress", progress)
            self._session.trace("createStandardLVM(): answer set to" + answer)
            pageResult = self._session.redirect("autopart", "createStdVG")
            self.setRefresh()
        return pageResult
    def createPartitons(self):
        '''Realizes the current proposal.
        @return: None or the PageResult
        '''
        pageResult = None
        templ = self.getField("template")
        if templ == "std":
            pageResult = self.createStandardLVM()
        else:
            self._session.error("unknown state: " + templ)
        return pageResult
        
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == "button_manual":
            self.addPage("mountpoint", "autopart")
            self.addPage("rootfs", "mountpoint")
            self.addPage("partition", "rootfs")
            self.delPage("autopart")
            pageResult = self._session.redirect("partition", "autopart.handleButton")
        elif button == "button_cancel":
            fname = self._diskInfo._filePartInfo
            Util.writeFile(fname, "# created by the cancel button")
        elif button ==  "button_retry":
            answer = self.getField("answer")
            self._session.deleteFile(answer)
        elif button ==  "button_check":
            self.checkInput()
        elif button == "button_reload":
            self._diskInfo.reload()
            pageResult = self._session.redirect("autopart", "autopart-reload")
            self.setRefresh() 
        elif button ==  "button_activate":
            pass
        elif button ==  "button_recalc":
            self.putField("size_boot", "")
            self.putField("size_root", "")
            self.putField("size_swap", "")
            self.putField("size_home", "")
            self.checkStandardLVM()
            pass
        elif button == "button_run1" or button == "button_run2":
            pageResult = self.createPartitons()
        elif button == "button_prev":
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                "autopart.handleButton")
        elif button == "button_next":
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, False), 
                "autopart.handleButton")
        else:
            self.buttonError(button)
            
        return pageResult
    