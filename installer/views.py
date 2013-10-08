# Create your views here.
from django.http import HttpResponse, HttpResponsePermanentRedirect
from isource.session import Session
from isource.homepage import HomePage
from isource.autopartpage import AutoPartPage
from isource.partitionpage import PartitionPage
from isource.rootfspage import RootFSPage
from isource.bootpage import BootPage
from isource.networkpage import NetworkPage
from isource.packetpage import PacketPage
from webbasic.waitpage import WaitPage
from isource.mountpointpage import MountpointPage
from isource.userpage import UserPage
from isource.globalpage import GlobalPage
from isource.runpage import RunPage
from isource.checkpage import CheckPage

def getSession(request):
    homeDir = request.documentRoot if hasattr(request, "documentRoot") else None
    session = Session(request, homeDir)
    return session

def getFields(request):
    fields = request.GET
    if len(fields) < len(request.POST):
        fields = request.POST
    return fields
    
def handlePage(page, request, session):
    page._globalPage = GlobalPage(session, request.COOKIES)
    
    fields = getFields(request)
    
    pageResult = page.handle('', fields, request.COOKIES)
    if pageResult._body != None:
        body = page.replaceInPageFrame(pageResult._body)
        rc = HttpResponse(body)
    else:
        url = pageResult._url
        session.trace('redirect to {:s} [{:s}]'.format(url, pageResult._caller))
        absUrl = session.buildAbsUrl(url)
        rc = HttpResponsePermanentRedirect(absUrl) 
    cookies = request.COOKIES
    for cookie in cookies:
        rc.set_cookie(cookie, session.unicodeToAscii(cookies[cookie]))
    return rc
    
def index(request):
    session = getSession(request)
    absUrl = session.buildAbsUrl('/home')
    rc = HttpResponsePermanentRedirect(absUrl) 
    return rc

def home(request):
    session = getSession(request)
    rc = handlePage(HomePage(session), request, session)
    return rc

def autopart(request):
    session = getSession(request)
    rc = handlePage(AutoPartPage(session), request, session)
    return rc

def partition(request):
    session = getSession(request)
    rc = handlePage(PartitionPage(session), request, session)
    return rc

def rootfs(request):
    session = getSession(request)
    rc = handlePage(RootFSPage(session), request, session)
    return rc

def mountpoint(request):
    session = getSession(request)
    rc = handlePage(MountpointPage(session), request, session)
    return rc

def boot(request):
    session = getSession(request)
    rc = handlePage(BootPage(session), request, session)
    return rc

def user(request):
    session = getSession(request)
    rc = handlePage(UserPage(session), request, session)
    return rc

def network(request):
    session = getSession(request)
    rc = handlePage(NetworkPage(session), request, session)
    return rc

def packet(request):
    session = getSession(request)
    rc = handlePage(PacketPage(session), request, session)
    return rc

def wait(request):
    session = getSession(request)
    rc = handlePage(WaitPage(session), request, session)
    return rc

def run(request):
    session = getSession(request)
    rc = handlePage(RunPage(session), request, session)
    return rc

def root(request):
    session = getSession(request)
    absUrl = session.buildAbsUrl('/home')
    rc = HttpResponsePermanentRedirect(absUrl) 
    return rc

def check(request):
    session = getSession(request)
    rc = handlePage(CheckPage(session), request, session)
    return rc

#partition;rootfs;mountpoint;boot;user;network;packet;run    
