'''
Created on 14.03.2013

@author: hm
'''

from webbasic.globalbasepage import GlobalBasePage

class GlobalPage(GlobalBasePage):
    '''
    Container for the global (= page independent) data
    '''


    def __init__(self, session, cookies):
        '''
        Constructor.
        @param session: the session info
        @fieldValues: the GET or POST dictionary of the request
        @cookies: the COOKIE dictionary from the request 
        '''
        GlobalBasePage.__init__(self, session, cookies)
        
    def defineFields(self):
        '''Defines the elements of the global data.
        '''
        self.addField("language")
        self.addField("mountpoint.list")
        self.addField("root")
        # "-" or "ext3"
        self.addField("rootfs")
        # "/dev/sda1:/tmp /dev/sdb2:home"
        self.addField("mountpoints")
        self.addField("realname")
        self.addField("login")
        # encoded: SHA256
        self.addField("rootpw")
        # encoded: SHA256
        self.addField("userpw")
        self.addField("host")
        # "y" or "n"
        self.addField("ssh")
        # "-" or "GRUB"
        self.addField("loader")
        # "mbr" "partition" or "/dev/sda" ...
        self.addField("target")
        # "yes" or "no"
        self.addField("mountonboot")
        self.addField("wait.translation")
        self.addField(".pages")
        # F or T
        self.addField("free_sw_only", "F", None, "b")
        self.addField("efi_boot")
        