'''
Created on 10.03.2013

@author: hm
'''
import os.path, time
from webbasic.page import Page
from isource.diskinfopage import DiskInfoPage
from basic.shellclient import SVOPT_DEFAULT
from util.util import Util

class RunPage(Page):
    '''
    Handles the page allowing selecting the root partition.
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, 'run', session)
        self._diskInfo = DiskInfoPage(self)

    def getPair(self, key, field):
        '''Returns a tuple of (parameterName, parameterValue)
        @param key: the key in the configuration
        @param field: the global field containing the value
        @return: a tuple with name and value of self._table
        '''
        name = "<xml><b>" + self._session.getConfig(key) + "</b>:"
        value = self._globalPage.getField(field)
        return (name, value)

    def afterInit(self):
        '''Will be called after all initializations are done.
        '''
        self._logfile = self.getField("logfile")
        self._isStarted = self._logfile != None and self._logfile != "" 
        self._isReady = self._isStarted and os.path.exists(self._logfile)
        if not self._isReady:
            self._params = []
            self._params.append(self.getPair("rootfs.txt_root", "root"))
            self._params.append(self.getPair("rootfs.txt_filesys", "rootfs"))
            self._params.append(self.getPair("mountpoint.txt_partition", "mountpoints"))
            self._params.append(self.getPair("boot.txt_manager", "loader"))
            self._params.append(self.getPair("boot.txt_target", "target"))
            self._params.append(self.getPair("user.txt_login_name", "login"))
            self._params.append(self.getPair("network.txt_host", "host"))
        
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("force")
        # Hidden fields:
        self.addField("start")
        self.addField("duration")
        self.addField("logfile")
        self.addField("progress")
        
   
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
            rc = None
        elif what == "rows":
            rc = len(self._params)
        elif what == "cols":
            rc = self._params[ixRow]
        return rc
    
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        if self._isReady:
            details = self._session.readFile(self._logfile)
            content = self._snippets.get("READY")
            success = (len(content) > 10 and details.find("\nE:") < 0 
                and not details.startswith("E:"))
            key = "{{run.txt_ready_intro}}" if success else "{{run.txt_ready_failed}}"
            content = content.replace("{{status}}", key)
            duration = self.getField("duration")
            if duration == None or duration == "":
                start = self.getField("start")
                if start == None or start == "":
                    start = "{:.0f}".format(time.time())
                diff = int(time.time() - int(start))
                duration = "{:d}:{:02d}".format(diff / 60, diff % 60)
                self.putField("duration", duration)
            content = content.replace("{{details}}", details) 
            content = self._session.replaceVars(content)        
            content = content.replace("{{duration}}", duration)
        elif self._isStarted:
            content = self._snippets.get("WAIT")
            content = self.buildProgress(content)
            self.setRefresh()
        else:
            content = self._snippets.get("INSTALL")
            button = True
            content = self.fillStaticSelected("force", content)
            if button:
                content2 = self._snippets.get("BUTTON_INSTALL")
            else:
                content2 = ""
            content = content.replace("{{BUTTON_OR_INFO}}", content2)
            table = self.buildTable(self, None)
            content = content.replace("{{TABLE}}", table)
        body = body.replace("{{INSTALL_OR_READY}}", content)
        return body
    
    def installIt(self):
        '''Sends a request to the shell server and go into wait state.
        '''
        answer = self._session._shellClient.buildFileName("run", ".ready")
        self.putField("logfile", answer)
        self.putField("start", "{:.0f}".format(time.time()))
        progress = self._session._shellClient.buildFileName("run", ".progress")
        lines = []
        # This must be the first entry, because of changing with NAME_NAME:
        lines.append("REGISTERED=' SYSTEM_MODULE HD_MODULE HD_FORMAT HD_FSTYPE HD_CHOICE HD_MAP HD_IGNORECHECK SWAP_MODULE SWAP_AUTODETECT SWAP_CHOICES NAME_MODULE USER_MODULE USER_NAME USERPASS_MODULE USERPASS_CRYPT ROOTPASS_MODULE ROOTPASS_CRYPT HOST_MODULE HOST_NAME SERVICES_MODULE SERVICES_START BOOT_MODULE BOOT_LOADER BOOT_DISK BOOT_WHERE AUTOLOGIN_MODULE INSTALL_READY HD_AUTO'")
        lines.append("")
        lines.append("SYSTEM_MODULE='configured'")
        lines.append("HD_MODULE='configured'")
        lines.append('')

        shellConfig = self._session._shellClient.buildFileName("inst", ".conf")
        params = []
        params.append("progress=" + progress)
        params.append("configfile=" + shellConfig)

        value = "/dev/" + self._globalPage.getField("root")
        lines.append("# Here the siduction-System will be installed")
        lines.append("# This value will be checked by function module_hd_check")
        lines.append("HD_CHOICE='{:s}'".format(value))
        lines.append("")

        # "-" or "ext3"
        fs = self._globalPage.getField("rootfs")
        lines.append("# Determines if the HD should be formatted. (mkfs.*)")
        lines.append("# Possible are: yes|no")
        lines.append("# Default value is: yes")
        formatIt = "no" if fs == "-" else 'yes'
        lines.append("HD_FORMAT='{:s}'".format(formatIt))
        lines.append("")

        lines.append("# Sets the Filesystem type.")
        lines.append("# Possible are: ext3|ext4|ext2|reiserfs|jfs")
        lines.append("# Default value is: ext4")
        lines.append("HD_FSTYPE='{:s}'".format(fs))

        # "/dev/sda1:/tmp /dev/sdb2:home"
        value = self._globalPage.getField("mountpoints")
        
        lines.append("# Here you can give additional mappings. (Experimental) You need to have the partitions formatted yourself and give the correct mappings like: /dev/hda4:/boot /dev/hda5:/var /dev/hda6:/tmp")
        lines.append("HD_MAP='{:s}'".format(value))
        lines.append("")

        lines.append("# If set to yes, the program will NOT check if there is enough space to install sidux on the selected partition(s). Use at your own risk! Useful for example with HD_MAP if you only have a small root partition.")
        lines.append("# Possible are: yes|no")
        lines.append("# Default value is: no")
        check = self.getField("force")
        lines.append("HD_IGNORECHECK='{:s}'".format(check))
        lines.append("")

        lines.append("SWAP_MODULE='configured'")
        lines.append("# If set to yes, the swap partitions will be autodetected.")
        lines.append("# Possible are: yes|no")
        lines.append("# Default value is: yes")
        lines.append("SWAP_AUTODETECT='yes'")
        lines.append("")

        lines.append("# The swap partitions to be used by the installed siduction.")
        lines.append("# This value will be checked by function module_swap_check")
        lines.append("SWAP_CHOICES='__swapchoices__'")
        lines.append("")

        name = self._globalPage.getField("realname")
        lines.append("NAME_MODULE='configured'")
        if name != "":
            lines.append("NAME_NAME='{:s}'".format(name))
            lines[0] += " NAME_NAME"
        
        lines.append("")

        value = self._globalPage.getField("login")
        lines.append("USER_MODULE='configured'")
        lines.append(u"USER_NAME='{:s}'".format(Util.toUnicode(value)))
        lines.append("")

        value = self._globalPage.getField("userpw")
        lines.append("USERPASS_MODULE='configured'")
        value = self._session._shellClient.escShell(value)
        lines.append(u"USERPASS_CRYPT='{:s}'".format(Util.toUnicode(value)))

        value = self._globalPage.getField("rootpw")
        lines.append("ROOTPASS_MODULE='configured'")
        value = self._session._shellClient.escShell(value)
        lines.append(u"ROOTPASS_CRYPT='{:s}'".format(Util.toUnicode(value)))

        value = self._globalPage.getField("host").strip()
        lines.append("HOST_MODULE='configured'")
        lines.append(u"HOST_NAME='{:s}'".format(Util.toUnicode(value)))
        lines.append("")

        services = "cups"
        value = self._globalPage.getField("ssh")
        if value == "y":
            services += " ssh"
        lines.append("SERVICES_MODULE='configured'")
        lines.append("# Possible services are for now: cups smail ssh samba (AFAIK this doesnt work anymore)")
        lines.append("# Default value is: cups")
        lines.append("SERVICES_START='{:s}'".format(services))
        lines.append("")


        value = self._globalPage.getField("loader").lower()
        lines.append("BOOT_MODULE='configured'")
        lines.append("# Chooses the Boot-Loader")
        lines.append("# Possible are: grub")
        lines.append("# Default value is: grub")
        lines.append("BOOT_LOADER='{:s}'".format(value))
        lines.append("")

        lines.append("# If set to 'yes' a boot disk will be created! (AFAIK this doesnt work anymore)")
        lines.append("# Possible are: yes|no")
        lines.append("# Default value is: yes")
        lines.append("BOOT_DISK='no'")
        lines.append("")

        value = self._globalPage.getField("target")
        lines.append("# Where the Boot-Loader will be installed")
        lines.append("# Possible are: mbr|partition|/dev/[hsv]d[a-z]")
        lines.append("# Default value is: mbr")
        lines.append("BOOT_WHERE='{:s}'".format(value))
        lines.append("")

        lines.append("AUTOLOGIN_MODULE='configured'")
        lines.append("INSTALL_READY='yes'")
        lines.append("")
        lines.append("# mount partitions on boot. Default value is: yes")
        value = self._globalPage.getField("mountonboot")
        lines.append("HD_AUTO='{:s}'".format(value))
        lines.append("")

        with open(shellConfig, "w") as fp:
            for line in lines:
                fp.write(line + "\n")
        fp.close()
 
        options = "background requestfile"
        command = "install"
        self.execute(answer, options, command, params, 0)
        rc = self._session.redirect("run", "run-installIt")
        self.putField("logfile", answer)
        self.putField("progress", progress)
        return rc
    
    def buildProgress(self, body):
        '''Builds the progress bar while waiting.
        @param body:    the html text with the progress bar and placeholders
        @return:        the html text with replaced placeholders
        '''
        translationKey = "run.backend"
        fnProgress = self.getField("progress")
        (percentage, task, no, count) = self._session.readProgress(fnProgress)
        if task == None:
            task = ""
        if task != "":
            task = self._session.translateTask(translationKey, task)
        body = body.replace("{{percentage}}", str(percentage))
        body = body.replace("{{width}}", str(percentage))
        body = body.replace("{{task}}", task)
        body = body.replace("{{no}}", str(no))
        body = body.replace("{{count}}", str(count))
        return body
       
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == "button_install":
            if not self._isStarted:
                pageResult = self.installIt()
        elif button == "button_reinstall" or button == "button_cancel":
            self.putField("start", "")
            self._session.deleteFile(self._logfile)
            self.putField("logfile", "")
            self.putField("duration", "")
            pageResult = self._session.redirect("run", "run-button-reinstall")
        elif button == "button_reboot":
            options = SVOPT_DEFAULT
            command = "reboot"
            self.execute(None, options, command, [], 0)
        elif button == 'button_prev':
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                'rootfs.handleButton')
        else:
            self.buttonError(button)
            
        return pageResult
    