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
        self.addField("size_total")
        self.addField("size_root")
        self.addField("size_swap")
        self.addField("size_home")
        self.addField("target")
        self.addField("boot_part")
        self.addField("target_part")
        self.addField("size_boot")
        self.addField("passphrase")
        for ix in xrange(len(self._freeSpaces)):
            self.addField("part{:d}".format(ix), None, None, "b")
        # Hidden fields:
        self.addField("log")
        self.addField("answer")
        self.addField("progress")
                         

    def buildStdParams(self, body, target, first3Cols):
        '''Builds the HTML code for the common parts of some proposals.
        @param body:          a HTML code with placeholders
        @param target         the HTML code with the target definitions
        @param first3Cols:    the snippet name for the first 3 columns.
        @return:              HTML code without placeholders
        '''
        body = body.replace("{{PARTITIONS}}", target)
        body = body.replace("{{ACTIVATE}}", self._snippets.get("ACTIVATE"))
        content = self._snippets.get("PARAM_STD")
        content2 = self._snippets.get(first3Cols)
        content = content.replace("{{PARAM_FIRST_3_COL}}", content2)
        body = body.replace("{{PARAMETER}}", content)
        sizeAvailable = self.calcAvailableSpace()
        sizeUsed = self.getCorrectedUsedSpace()
        sizeFree = self.humanReadableSize((sizeAvailable-sizeUsed) * 1024, 3, 100)
        sizeAvailable = self.humanReadableSize(sizeAvailable*1024, 3, 100)
        self._session.setLocalVar("size_total", sizeAvailable)
        self._session.setLocalVar("size_free", sizeFree)
        return body
        
    def buildLVM(self):
        '''Builds the HTML code for the standard LVM template.
         @return: the HTML code
        '''
        body = self._snippets.get("TEMPLATE_STD_LVM")
        content = self._diskInfo.buildFreePartitionTable(None)
        target = self._snippets.get("STD_PART")
        target = target.replace("{{PARTITION_LIST}}", content)
        body = self.buildStdParams(body, target, "FIRST_3_COL_VG")
        return body

    def buildRawPartitions(self):
        '''Builds the HTML code for the standard LVM template.
         @return: the HTML code
        '''
        body = self._snippets.get("TEMPLATE_RAW_PARTS")
        combo = self._diskInfo.buildFreePartitionComboBox("target_part")
        body = self.buildStdParams(body, combo, "FIRST_3_COL_RAW")
        return body

    def buildEncryptedLVM(self):
        '''Builds the HTML code for the standard LVM template.
         @return: the HTML code
        '''
        body = self._snippets.get("CRYPTO_LVM")
        content = self._snippets.get("CRYPTO_TARGET")
        target = self._diskInfo.buildFreePartitionComboBox("target_part")
        boot = self._diskInfo.buildFreePartitionComboBox("boot_part")
        content = content.replace("{{COMBO_TARGET}}", target)
        content = content.replace("{{COMBO_BOOT}}", boot)
        body = self.buildStdParams(body, content, "FIRST_3_COL_VG")
        
        return body
        
    def extractDevs(self, fileContent):
        '''Extracts devices from the answer file.
        @param fileContent:    the answer file
        @return:                (boot, root, home, efi, vg)
        '''
        (boot, root, home, efi, vg) = ("", "", "", "", "")
        lines = fileContent.split("\n")
        rexpr = re.compile(r'\s*(\S+) created as (\S+)')
        rexpr2 = re.compile(r'\s*VG (\S+) has been created')
        for line in lines:
            matcher = rexpr.match(line)
            if matcher != None:
                (dev, name) = (matcher.group(1), matcher.group(2))
                if name == "root":
                    root = dev
                elif name == "home":
                    home = dev
                elif name == "boot":
                    boot = dev
                elif name == "(U)EFI":
                    efi = dev
            else:
                matcher = rexpr2.match(line)
                if matcher != None:
                    vg = matcher.group(1)
        return (boot, root, home, efi, vg)
    
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
            (boot, root, home, efi, vg) = self.extractDevs(fileContent)
            self._globalPage.putField("root", root)
            self._session.putUserData("rootfs", "root", root)
            self._globalPage.putField("rootfs", "-")
            self._session.putUserData("rootfs", "filesys", "-")
            mountPoints = ""
            if home != "":
                mountPoints = " /dev/" + home + ":/home"
            if boot != "":
                mountPoints += " /dev/" + boot + ":/boot"
            if mountPoints != "":
                self._globalPage.putField("mountpoints", mountPoints)
                self._session.putUserData("mountpoint", "mounts", mountPoints)
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
                if templ == "raw":
                    content2 = self.buildRawPartitions()
                elif templ == "lvm":
                    content2 = self.buildLVM()
                elif templ == "encrypt":
                    content2 = self.buildEncryptedLVM()
                else:
                    content2 = self.buildLVM()
                content = self._snippets.get("ENOUGH_SPACE")
                content = self.fillStaticSelected("template", content)
                content = content.replace("{{TEMPLATE}}", content2)
        body = body.replace("{{CONTENT}}", content)
        return body

    def findGapInfo(self, field):
        '''Finds the partition info stored in a given field.
        @param field:    name of the field to inspect
        @return:         None: no info available.
                         (<name>, <from>, <to>): the partition info
        ''' 
        rc = None
        val = self.getField(field)
        if val != None:
            matcher = re.match("(\D+)(\d+)", val)
            if matcher:
                name = u"{:s}!{:s}".format(
                    Util.toUnicode(matcher.group(1)),
                    matcher.group(2))
                for item in self._freeSpaces:
                    info = item.split("-")
                    if info[0] == name:
                        rc = info
                        break;
        return rc
    
    def calcAvailableSpace(self):
        '''Calculates the sum of the selected free spaces:
        @return: the size in KiBytes
        '''
        size = 0
        templ = self.getField("template")
        if templ == "raw" or templ == "encrypt":
            info = self.findGapInfo("target_part")
            if info != None:
                size = (int(info[2]) - int(info[1])) / 2
        elif templ == "lvm":
            for ix in xrange(len(self._freeSpaces)):
                val = self.getField("part{:d}".format(ix))
                if val == "on":
                    info = self._freeSpaces[ix].split('-')
                    size += (int(info[2]) - int(info[1])) / 2
        else:
            self._session.error("unknown state: " + templ)
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
            size = self.sizeAndUnitToByte(val, "M")
            if size < 0:
                val = ""
            else:
                val = self.humanReadableSize(size, 3, 100)
                size /= 1024
            self.putField(field, val)
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
     
    def getTotalSize(self):
        '''Returns the value of the field total_size.
        @return:    the size in KiBytes
        '''
        rc = self.sizeAndUnitToByte(self.getField("size_total"), "M") / 1024
        if rc < 0:
            rc = 0
        return rc
        
    def processFieldForLeftOver(self):
        '''The field values will be tested for "*". 
        If given the field will set to a value that the total space is used.
        '''
        sizeUsed = self.getCorrectedUsedSpace()
        sizeTotal = self.getTotalSize()
        sizeFree = str((sizeTotal - sizeUsed) / 1024) + "M"
        if self.getField("size_boot") == "*":
            self.putField("size_boot", sizeFree)
        if self.getField("size_root") == "*":
            self.putField("size_root", sizeFree)
        if self.getField("size_swap") == "*":
            self.putField("size_swap", sizeFree)
        if self.getField("size_home") == "*":
            self.putField("size_home", sizeFree)

    def check(self):
        '''Checks the validity of the input fields for the standard LVM proposal.
        '''
        MByte=1024
        GByte=1024*1024
        sizeAvailable = self.calcAvailableSpace()
        sizeMax = self.getField("size_total")
        if sizeMax != "" and not sizeMax.startswith("0B"):
            sizeMax = self.sizeAndUnitToByte(sizeMax, "M") / 1024
        else:
            sizeMax = sizeAvailable
            if sizeMax > 50*GByte:
                sizeMax = 50*GByte
            self.putField("size_total", self.humanReadableSize(1024*sizeMax, 3, 100))
        if sizeMax <= 4*GByte:
            home = 0
            swap = 200
            root = sizeMax - swap - home
        elif sizeMax <= 8*GByte:
            # Min: 2709 Max: 4G
            root = (2000*MByte + (sizeMax - 2000) * (4*GByte - 2000*MByte)
                    / (8*GByte - 2000*MByte))
            # Min: 409M Max: 819M
            swap = 200 + (sizeMax - 200) / 10
            # Min: 976 Max: 3276
            home = sizeMax - root - swap
        elif sizeMax <= 32*GByte:
            # min: 4G max: 16G
            root = sizeMax / 2;
            # min: 822M max: 2.3G
            swap = 310*MByte + sizeMax / 16
            # min: 3274M max: 14026M
            home = sizeMax - root - swap
        else:
            root = 16*GByte
            swap = 2500*MByte
            home = sizeMax - root - swap   
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
        self.processFieldForLeftOver()
        sizeUsed = self.getCorrectedUsedSpace()
        if sizeMax - sizeUsed < 0:
            self.putError(None, "autopart.txt_too_much_space")
     
    def checkEncryptedLVM(self):
        '''Checks the validity of the input fields for the standard LVM proposal.
        '''
        self.check()
    
    def checkInput(self):
        '''Checks the validity of the input fields and calculates some infos.
        '''
        templ = self.getField("template")
        if templ == "raw" or  templ == "lvm" or templ == "encrypt":
            self.check()
        else:
            self._session.error("unknown state: " + templ)
    
    def buildShortName(self):
        '''Returns an info about the running siduction system.
        @return:        the flavour, e.g. "kde"
        '''
        (flavour, arch, version) = self._diskInfo.getOsInfo()
        rc = "sidu-{:s}-{:s}-{:s}".format(version, arch, flavour)
        return rc
        
    def createCommon(self):
        '''Does the common tasks for some proposals, e.g validations.
        @return:    a tuple (pageResult: (error, answer, progress, 
                    diskInfo, allowInit, partitions, vgInfo, lvInfo, totalSize)
                    if error == True an validation has failed
        '''
        answer = self._session._shellClient.buildFileName("ap", ".ready")
        allowInit = "YES"
        diskInfo = ""
        partitions = ""
        templ = self.getField("template")
        if templ == "raw" or templ == "encrypt":
            info = self.findGapInfo("target_part")
            if info != None:
                partitions = "-".join(info).replace("!", "")
                diskInfo = info[0].split("!")[0]
        elif templ == "lvm":
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
        totalSize = self.getTotalSize()
        extensionSize = self._session.nextPowerOf2(totalSize/2024)
        vgInfo = self.getField("vg") + ":" + str(extensionSize) + "K"
        lvInfo = ""
        flavour = self._diskInfo.getOsInfo()[0]
        minSize = int(self._session.getConfigWithoutLanguage(
                        "diskinfo.root.minsize.mb." + flavour))
        size = self.getCorrectedSizeValue("size_root") / 1024
        error = False 
        progress = None
        shortname = self.buildShortName()
        if diskInfo == "":
            error = self.putError(None, "autopart.err_missing_partition")
        elif totalSize < minSize:
            error = self.putError(None, "autopart.err_too_small")
        elif (size < minSize):
            error = self.putError(None, "autopart.err_too_small")
        if vgInfo.startswith(":"):
            error = self.putError(None, "autopart.err_missing_vg")
        if not error:
            lvInfo = "root:{:s}:{:d}M:ext4".format(shortname, size)
            sizeHome = self.getCorrectedSizeValue("size_home") / 1024
            sizeSwap = self.getCorrectedSizeValue("size_swap") / 1024
            sumSize = size + sizeHome + sizeSwap
            # 6 extension must be reserved:
            allUsed = sumSize * 1024 > totalSize - 6 * extensionSize
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
        return (error, answer, progress, diskInfo, allowInit, partitions, 
            vgInfo, lvInfo, str(totalSize))
    
    def createStandardLVM(self):
        '''Realizes the standard LVM proposal.
        @return: None or the PageResult
        '''
        pageResult = None
        (error, answer, progress, diskInfo, allowInit, partitions, 
            vgInfo, lvInfo, totalSize) = self.createCommon()
        if not error:
            program = "autopart"
            params = ["lvm", progress, diskInfo, allowInit, partitions, 
                      vgInfo, lvInfo, totalSize]
        
            self.execute(answer, SVOPT_DEFAULT, program, params, 0)
            
            self.putField("answer", answer)
            self.putField("progress", progress)
            self._session.trace("createStandardLVM(): answer set to" + answer)
            pageResult = self._session.redirect("autopart", "createStdVG")
            self.setRefresh()
        return pageResult

    def createEncryptedLVM(self):
        '''Realizes the standard LVM proposal.
        @return: None or the PageResult
        '''
        pageResult = None
        (error, answer, progress, diskInfo, allowInit, partitions, 
            vgInfo, lvInfo, totalSize) = self.createCommon()
        program = "autopart"
        if not error:
            value = self.getField("passphrase")
            if value == None or len(value) < 3:
                error = self.putError("passphrase", "autopart.err_short_pw")
            
        if not error:
            params = ["cryptlvm", progress, diskInfo, allowInit, partitions, 
                      vgInfo, lvInfo, totalSize, Util.scrambleText(value)]
        
            self.execute(answer, SVOPT_DEFAULT, program, params, 0)
            
            self.putField("answer", answer)
            self.putField("progress", progress)
            self._session.trace("createStandardLVM(): answer set to" + answer)
            pageResult = self._session.redirect("autopart", "createCrypted")
            self.setRefresh()
        return pageResult

    def createRawParitions(self):
        '''Realizes the standard LVM proposal.
        @return: None or the PageResult
        '''
        pageResult = None
        (error, answer, progress, diskInfo, allowInit, partitions, 
            vgInfo, lvInfo, totalSize) = self.createCommon()
        program = "autopart"
        if not error:
            params = ["raw", progress, diskInfo, allowInit, partitions, 
                      vgInfo, lvInfo, totalSize]
        
            self.execute(answer, SVOPT_DEFAULT, program, params, 0)
            
            self.putField("answer", answer)
            self.putField("progress", progress)
            self._session.trace("createRawParitions(): answer set to" + answer)
            pageResult = self._session.redirect("autopart", "createRaw")
            self.setRefresh()
        return pageResult

    def createPartitons(self):
        '''Realizes the current proposal.
        @return: None or the PageResult
        '''
        pageResult = None
        templ = self.getField("template")
        if templ == "raw":
            pageResult = self.createRawParitions()
        elif templ == "lvm":
            pageResult = self.createStandardLVM()
        elif templ == "encrypt":
            pageResult = self.createEncryptedLVM()
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
            self.check()
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
    