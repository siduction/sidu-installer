from djinn.django.conf.urls import patterns, url

from installer import views

# Uncomment the next two lines to enable the admin:
#from django.contrib import admin
#admin.autodiscover()

def getPatterns():
    rc = patterns('',
        url(r'^$', views.home, name='root'),
        url(r'^home', views.home, name='home'),
        url(r'^autopart', views.autopart, name='autopart'),
        url(r'^partition', views.partition, name='partition'),
        url(r'^rootfs', views.rootfs, name='rootfs'),
        url(r'^mountpoint', views.mountpoint, name='mountpoint'),
        url(r'^boot', views.boot, name='boot'),
        url(r'^user', views.user, name='user'),
        url(r'^network', views.network, name='network'),
        url(r'^packet', views.packet, name='packet'),
        url(r'^run', views.run, name='run'),
        url(r'^wait', views.wait, name='wait'),
        url(r'^check', views.check, name='check')
        )
    return rc

urlpatterns = getPatterns() 

