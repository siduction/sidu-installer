# coding=UTF-8
'''
Created on 13.04.2013

@author: hm
'''
import unittest, os.path

from isource.diskinfopage import DiskInfoPage
from pyunit.aux import Aux
from util.util import Util;

class Test(unittest.TestCase):


    def setUp(self):
        self._appl = 'test_installer'
        self._session = Aux.getSessionWithStdConfig(self._appl)
        self._partInfo = Util.getTempFile('partinfo.txt', self._appl)
        if not os.path.exists(self._partInfo):
            Util.writeFile(self._partInfo, '''
sda\t500107608
/dev/loop0\tfs:squashfs\tdistro:wheezy/sid\tsubdistro:siduction\t12.2.0\tRider\tin\tthe\tStorm\t-\tkde\t(201212092131)
/dev/mapper/vertex4-home\tlabel:v4home\tfs:ext4\tuuid:8329668e-ca2e-4217-9c4e-49c1f5c780c5\tcreated:2012.11.12\tmodified:2013.03.16\tsize:25165824
/dev/mapper/vertex4-rider\tlabel:v4rider\tfs:ext4\tuuid:8329777e-ca2e-4217-9c4e-49c1f5c780c5\tcreated:2012.11.13\tmodified:2013.02.16\tsize:8111222\tsubdistro:siduction
/dev/sda1\tlabel:System-reserviert\tfs:ntfs\tuuid:2CEAB44DEAB41554\tsize:102400\tpinfo:Microsoft basic data
/dev/sda2\tlabel:win7\tfs:ntfs\tuuid:06CAD5C4CAD5AFE3\tsize:41943040\tpinfo:Microsoft basic data
/dev/sda3\tsize:204800\tptype:8300\tpinfo:Linux\tfilesystem
/dev/sda5\tlabel:winprogs\tfs:ntfs\tuuid:029C9A3C9C9A29E5\tsize:16777216\tpinfo:Microsoft basic data
/dev/sda6\tfs:LVM2_member\tuuid:ZBNt1t-puF3-wcsT-xPHM-zHhQ-OG90-XGhY83\tsize:441077080\tpinfo:Linux LVM
/dev/sdb1\tlabel:usb-store\tfs:vfat\tuuid:0514-A998\tsize:3955712\tpinfo:Microsoft basic data
/dev/sdb2\tlabel:ubuntu\tfs:ext4\tuuid:8329777e-ca2e-4217-8c4e-49c1f5c780c5\tcreated:2012.11.13\tmodified:2013.01.26\tsize:4321333\tdistro:ubuntu\tsubdistro:Daisy Duck
/dev/sr0\tlabel:siduction\tfs:iso9660
sdb\t3956736
!GPT=;sda;
!VG=vertex4
!LV=vertex4/desp64-boot;vertex4/desperado64;vertex4/desperado64-b;vertex4/home;vertex4/nas-cache;vertex4/opt;vertex4/rider-lxde-64;vertex4/swap;vertex4/vdi
'''             )
        self._session.addConfig('diskinfo.file.demo.partinfo', self._partInfo)
        self._parent = Aux.buildPage(None, self._session)


    def tearDown(self):
        pass


    def testPartitions(self):
        page = DiskInfoPage(self._parent)
        self.assertEquals(0, len(page._partitions))
        # /dev/sda1	label:System-reserviert	fs:ntfs	uuid:2CEAB44DEAB41554	
        #    size:102400	pinfo:Microsoft basic data
        if False:
            info = page._partitions['sda1']
            self.assertEquals(page._partitions, info._diskInfo)
            self.assertEquals('sda1', info._device)
            self.assertEquals('System-reserviert', info._label)
            self.assertEquals('Microsoft basic data', info._partInfo)
            self.assertEquals('ntfs', info._filesystem)
            self.assertEquals(102, info._megabytes)
            self.assertEquals('', info._info)
            
            # /dev/mapper/vertex4-home	label:v4home	fs:ext4	
            # uuid:8329668e-ca2e-4217-9c4e-49c1f5c780c5	created:2012.11.12	
            # modified:2013.03.16	size:25165824
            info = page._partitions['mapper/vertex4-home']
            self.assertEquals(page._partitions, info._diskInfo)
            self.assertEquals('mapper/vertex4-home', info._device)
            self.assertEquals('v4home', info._label)
            self.assertEquals('', info._partInfo)
            self.assertEquals('ext4', info._filesystem)
            self.assertEquals(25165, info._megabytes)
            self.assertTrue(info._info.find('2012.11.12') > 0)
            self.assertTrue(info._info.find('2013.03.16') > 0)
        
    def testDisks(self):
        if False:
            page = DiskInfoPage(self._parent)
            self.assertEquals(2, len(page._disks))
            self.assertEqual(500107608, page._disks['sda']._size)
            self.assertEqual('sda', page._disks['sda']._device)
            self.assertEqual(3956736, page._disks['sdb']._size)
        
    def testHasGPT(self):
        page = DiskInfoPage(self._parent)
        # self.assertTrue(page.hasGPT('sda1'))
        # self.assertFalse(page.hasGPT('sdb2'))

    def testGetPartitionsOfDisk(self):
        if False:
            page = DiskInfoPage(self._parent)
            partitions = page.getPartitionsOfDisk('sda')
            names = ''
            for partition in partitions:
                names += ' ' + partition._device
            # self.assertEquals(" sda1 sda2 sda3 sda5 sda6", names)
        
    def testBuildPartitionInfoTable(self):
        if False:
            page = DiskInfoPage(self._parent)
            table = page.buildPartitionInfoTable('sdb')
            table = table.replace("<td>", "\n<td>")
            table = table.replace("\t", " ")
            diff = Aux.compareText(u'''<table class="table-partitioninfo">
 <tr>
  <th>{{diskinfo.txt_device}}</th>
  <th>{{diskinfo.txt_label}}</th>
  <th>{{diskinfo.txt_size}}</th>
  <th>{{diskinfo.txt_parttype}}</th>
  <th>{{diskinfo.txt_fs}}</th>
  <th>{{diskinfo.txt_info}}</th>
 </tr>
 <tr>
<td>sdb1</td>
<td></td>
<td>100MiB</td>
<td>EF02</td>
<td></td>
<td></td></tr><tr>
<td>sdb2</td>
<td>sidu-11.1-64-kde</td>
<td>7435MiB</td>
<td></td>
<td>ext4</td>
<td> Erzeugt: 2013.10.23 Geändert: 2013.10.23</td></tr><tr>
<td>sdb3</td>
<td>home</td>
<td>6284MiB</td>
<td></td>
<td>ext4</td>
<td> Erzeugt: 2013.10.23 Geändert: 2013.10.23</td></tr><tr>
<td>sdb4</td>
<td>swap</td>
<td>1252MiB</td>
<td></td>
<td>swap</td>
<td></td></tr>
</table>
''',        table)
    # self.assertEquals(None, diff)

    def testGetRootFsDevices(self):
         if False:
             page = DiskInfoPage(self._parent)
             rootPartitions = page.getRootFsDevices()
             self.assertEqual(['-', 'vertex4-home', 'vertex4-rider', 'sdb2'], 
                 rootPartitions)
         
if __name__ == "__main__":
    #import sys;sys.argv = ['', 'Test.testName']
    unittest.main()