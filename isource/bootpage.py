'''
Created on 10.03.2013

@author: hm
'''

from webbasic.page import Page
from diskinfopage import DiskInfoPage
import os.path, re
from basic.shellclient import SVOPT_DEFAULT

class BootPage(Page):
    '''
    Handles the page allowing changing the partitions.
    '''


    def __init__(self, session):
        '''
        Constructor.
        @param session: the session info
        '''
        Page.__init__(self, 'boot', session)
        self._diskInfo = DiskInfoPage(self)
         
    def afterInit(self):
        '''Will be called after all initializations are done.
        Note: self._globalPage will be set after the constructor.
        '''
        region = self.getField("region")
        if region == None or region == "":
            content = self._session.readFile("/etc/timezone")
            rexpr = re.compile("^(\w+)/(\w+)")
            matcher = rexpr.match(content)
            if matcher != None:
                region = matcher.group(1)
                city = matcher.group(2)
                self.putField("region", region)
                self.putField("city", city)
    
    def defineFields(self):
        '''Defines the fields of the page.
        This allows a generic handling of the fields.
        '''
        self.addField("loader", None, 0, "v")
        self.addField("target", None, 0, "v")
        self.addField("region")
        self.addField("city")
        # Hidden fields:
   
    def readTimezones(self):
        '''Reads the file with the timezone info.
        @return: a tuple (regions, cities)
        '''
        name = self._session.getConfigWithoutLanguage(".dir.temp") + "timezoneinfo.txt"
        cities = []
        zones = []
        if not os.path.exists(name):
            # self.execute(name, options, command, params, timeout)
            pass
        else:
            currentZone = self.getField("region")
            if currentZone == None:
                currentZone = "Europe"
            with open(name, "r") as fp:
                lastZone = None
                for line in fp:
                    (zone, city) = line.rstrip().split("/")
                    if zone != lastZone:
                        zones.append(zone)
                        lastZone = zone
                    if zone == currentZone:
                        cities.append(city) 
        return (zones, cities)
                    
                    
    def changeContent(self, body):
        '''Changes the template in a customized way.
        @param body: the HTML code of the page
        @return: the modified body
        '''
        body = self.fillStaticSelected("loader", body)
        targets = self._diskInfo.getRealDisks()
        values = self.autoSplit(self._session.getConfig("boot.opts_target"))
        targets = values + targets
        body = self.fillDynamicSelected('target', targets, None, body)
        (regions, cities) = self.readTimezones()
        body = self.fillDynamicSelected('region', regions, None, body)
        body = self.fillDynamicSelected('city', cities, None, body)
        return body
    
    def setTimeZone(self):
        '''Sets the timezone.
        '''
        answer = self._session._shellClient.buildFileName("tz", ".ready")
        params = ["set", 
            "{:s}/{:s}".format(self.getField("region"), self.getField("city"))]
        options = SVOPT_DEFAULT
        command = "timezoneinfo"
        self.execute(answer, options, command, params, 0)
        
    def handleButton(self, button):
        '''Do the actions after a button has been pushed.
        @param button: the name of the pushed button
        @return: None: OK<br>
                otherwise: a redirect info (PageResult)
        '''
        pageResult = None
        if button == "button_refresh":
            # Show same page again:
            pass
        elif button == 'button_prev':
            pageResult = self._session.redirect(
                self.neighbourOf(self._name, True), 
                'boot.handleButton')
        elif button == 'button_next':
            self.storeAsGlobal("loader", "loader")
            target = self.getField("target")
            ix = self.findIndexOfOptions("target")
            if ix == 0:
                target = "mbr"
            elif ix == 1:
                target = "partition"
            else:
                target = "/dev/" + target
            self._globalPage.putField("target", target)
            zone = self.getField("region")
            city = self.getField("city")
            if zone == None or city == None:
                self.putError("region", "boot.err_no_timezone")
            else:
                self.setTimeZone()
                # force to fetch timezone info from system:
                self.putField("region", None)
                self.putField("city", None)
                
                pageResult = self._session.redirect(
                    self.neighbourOf(self._name, False), 
                    'boot.handleButton')
        else:
            self.buttonError(button)
            
        return pageResult
    