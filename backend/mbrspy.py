#! /usr/bin/python
'''MBR partition table decoder
'''
import sys, struct, os.path


PARTITION_TYPES = { 
	0x00 : 'Empty',
	0x01 : 'FAT12',
	0x02 : 'XENIX root',
	0x03 : 'XENIX usr',
	0x04 : 'FAT16 <32M',
	0x05 : 'Extended',
	0x06 : 'FAT16',
	0x07 : 'HPFS/NTFS/exFAT',
	0x08 : 'AIX',
	0x09 : 'AIX bootable',
	0x0a : 'OS/2 Boot Manag',
	0x0b : 'W95 FAT32',
	0x0c : 'W95 FAT32 (LBA)',
	0x0e : 'W95 FAT16 (LBA)',
	0x0f : 'W95 Ext (LBA)',
	0x10 : 'OPUS 55 EZ-Drive',
	0x11 : 'Hidden FAT12',
	0x12 : 'Compaq diagnost',
	0x14 : 'Hidden FAT16 small',
	0x16 : 'Hidden FAT16',
	0x17 : 'Hidden HPFS/NTF',
	0x18 : 'AST SmartSleep',
	0x1b : 'Hidden W95 FAT3',
	0x1c : 'Hidden W95 FAT3',
	0x1e : 'Hidden W95 FAT1',
	0x24 : 'NEC DOS',
	0x27 : 'Hidden NTFS Win',
	0x39 : 'Plan 9',
	0x3c : 'PartitionMagic',
	0x40 : 'Venix 80286',
	0x41 : 'PPC PReP Boot',
	0x42 : 'SFS',
	0x4d : 'QNX4.x',
	0x4e : 'QNX4.x 2nd part',
	0x4f : 'QNX4.x 3rd part',
	0x50 : 'OnTrack DM',
	0x51 : 'OnTrack DM6 Aux',
	0x52 : 'CP/M',
	0x53 : 'OnTrack DM6 Aux',
	0x54 : 'OnTrackDM6',
	0x56 : 'Golden Bow',
	0x5c : 'Priam Edisk',
	0x61 : 'SpeedStor ab Darwin boot',
	0x63 : 'GNU HURD',
	0x64 : 'Novell Netware',
	0x65 : 'Novell Netware',
	0x70 : 'DiskSecure Mult',
	0x75 : 'PC/IX',
	0x80 : 'Old Minix',
	0x81 : 'Minix',
	0x82 : 'Linux swap',
	0x83 : 'Linux',
	0x84 : 'OS/2 hidden C:',
	0x85 : 'Linux extended',
	0x86 : 'NTFS volume set',
	0x87 : 'NTFS volume set',
	0x88 : 'Linux plaintext',
	0x8e : 'Linux LVM',
	0x93 : 'Amoeba',
	0x94 : 'Amoeba BBT',
	0x9f : 'BSD/OS',
	0xa0 : 'IBM Thinkpad hi',
	0xa5 : 'FreeBSD',
	0xa6 : 'OpenBSD',
	0xa7 : 'NeXTSTEP',
	0xa8 : 'Darwin UFS',
	0xa9 : 'NetBSD',
	0xaf : 'HFS / HFS+',
	0xb7 : 'BSDI fs',
	0xb8 : 'BSDI swap',
	0xbb : 'Boot Wizard hid',
	0xbe : 'Solaris boot',
	0xbf : 'Solaris',
	0xc1 : 'DRDOS FAT-16',
	0xc4 : 'DRDOS FAT-32',
	0xc6 : 'DRDOS FAT-32 big',
	0xc7 : 'Syrinx',
	0xda : 'Non-FS data',
	0xdb : 'CP/M / CTOS',
	0xde : 'Dell Utility',
	0xdf : 'BootIt',
	0xe1 : 'DOS access',
	0xe3 : 'DOS R/O',
	0xe4 : 'SpeedStor',
	0xeb : 'BeOS fs',
	0xee : 'GPT',
	0xef : 'EFI FAT-12/16/32',
	0xf0 : 'Linux/PA-RISC boot',
	0xf1 : 'SpeedStor',
	0xf2 : 'DOS secondary',
	0xf4 : 'SpeedStor',
	0xfb : 'VMware VMFS',
	0xfc : 'VMware VMKCORE',
	0xfd : 'Linux raid auto',
	0xfe : 'LANstep',
	0xff : 'BBT'
}

def nameOfType(no):
	'''Returns the name of a partition type
	@param no:	partition type number
	@return: 	the name of the partition type
	'''
	if no in PARTITION_TYPES:
		rc = PARTITION_TYPES[no]
	else:
		rc = "undef"
	return rc

def humanSize(kByte):
	'''Returns a human readable size.
	@param kByte:	the size in kByte
	@return: 		a human readable string, e.g. "204MiB"
	'''
	rc = None
	if kByte > 1024*1024*1024:
		rc = "{:d}GiB".format(kByte / 1024 / 1024)
	elif kByte > 1024*1024:
		rc = "{:d}MiB".format(kByte / 1024)
	else:
		rc = "{:d}KiB".format(kByte)
	return rc

def getUByte(data, pos):
	'''Returns a unsigned byte.
	@param data:	byte array
	@param pos:		the position of the wanted byte
	'''
	byte = data[pos]
	rc = struct.unpack("<B", data[pos:pos+1])[0]
	return rc

def getUShort(data, pos):
	'''Returns a unsigned short (16 bit).
	@param data:	byte array
	@param pos:		the lowest position of the wanted value
	'''
	byte = data[pos]
	rc = struct.unpack("<H", data[pos:pos+2])[0]
	return rc

def getUInt(data, pos):
	'''Returns a unsigned short (32 bit).
	@param data:	byte array
	@param pos:		the lowest position of the wanted value
	'''
	byte = data[pos]
	rc = struct.unpack("<I", data[pos:pos+4])[0]
	return rc

class PartitionEntry:
	'''Describes one entry of the partition table.
	@param bytes: binary data of the partition entry
	'''
	def __init__(self, data):
		'''Decodes a partition table entry.
		@param data: the binary data of the entry
		'''
		self._bootFlag = getUByte(data, 0)
		self._chsStart = (getUByte(data, 1), getUByte(data, 2), getUByte(data, 3))
		self._partType = getUByte(data, 4)
		self._chsEnd = (getUByte(data, 5), getUByte(data, 6), getUByte(data, 7))
		self._startLBA = getUInt(data, 8)
		self._sectors = getUInt(data, 12)
       
	def getCHSSectors(self, chs):
		rc = chs[1] % 64
		return rc
    
	def getCHSCylinders(self, chs):
		rc = chs[2] + 256*chs[1] / 64
		return rc
	
	def getCHSHeads(self, chs):
		rc = chs[0]
		return rc
	
	def isValid(self):
		'''Returns if the partition has valid data.
		@return: True: the partition has valid data
		'''
		rc = self._sectors != 0
		return rc
		
	def out(self, mode, dev, no):
		'''Prints the partition entry.
		@param mode:	"machine" or "human"
		@param no:		partition number
		'''
		if mode == "machine":
			print("{:s}{:d}:{:x}:{:x}:{:d}:{:d}:{:d}:{:d}/{:d}/{:d}-{:d}/{:d}/{:d}".format(
				dev, no, self._bootFlag, self._partType,
				self._startLBA, self._startLBA + self._sectors - 1,
				self._sectors,
				self.getCHSCylinders(self._chsStart), 
				self.getCHSHeads(self._chsStart),
				self.getCHSSectors(self._chsStart),
				self.getCHSCylinders(self._chsEnd), 
				self.getCHSHeads(self._chsEnd),
				self.getCHSSectors(self._chsEnd)))
			boot = "b" if self._bootFlag == 128 else '-'
			print("{:s}{:d}: {:s} {:10d} - {:10d} {:10d} ({:s}) {:02x} {:s}".format(
				dev, no, boot,
				self._startLBA, self._startLBA + self._sectors - 1,
				self._sectors, 
				humanSize(self._sectors / 2),
				self._partType, 
				nameOfType(self._partType)))

class PartitionTable:
	'''Manages the MBR partition table
	'''
	def __init__(self, data):
		'''Decodes a MBR partition table
		@param data: the binary data of the partition table
		'''
		self._label1 = getUByte(data, 0)
		self._label2 = getUByte(data, 1)
		self._label3 = getUByte(data, 2)
		self._label4 = getUByte(data, 3)
		self._reserve1 = getUShort(data, 4)
		self._entries = (PartitionEntry(data[6:22]),
			PartitionEntry(data[22:38]),
			PartitionEntry(data[38:54]),
			PartitionEntry(data[54:70]))
		self._sign5 = getUShort(data, 70)  

	def out(self, mode, dev, printAll = False):
		'''Prints the partition entry.
		@param mode:	"machine" or "human"
		@param dev:		device, e.g. /dev/sdc
		@param printAll True: invalid entries will be printed too
		'''
		countPart = 0
		for ix in range(4):
			if self._entries[ix].isValid():
				countPart += 1
		
		if mode == "machine":
			print("{:s}:{:02x}-{:02x}-{:02x}-{:02x}:{:d}".format(
				dev, self._label1, self._label2, self._label3, self._label4,
				countPart))
		else:
			print("{:s}: Label: {:02x}-{:02x}-{:02x}-{:02x} Partitions: {:d}"
				.format(dev,
				self._label1, self._label2, self._label3, self._label4,
				countPart))
				
		for ix in range(4):
			if printAll or self._entries[ix].isValid():
				self._entries[ix].out(mode, dev, ix)

	def isValid(self):
		'''Returns whether the partition table is valid.
		@return: True: the partition table is valid
		'''
		rc = self._sign5 == 0xaa55
		return rc

class ExtPartitionTable:
	'''Managages a extended partition table (used for logical partitions).
	'''
	def __init__(self, dev, data):
		'''Decodes an extended partition table.
		@param data: the binary data of the partition table
		'''
		self._label1 = getUByte(data, 0)
		self._label2 = getUByte(data, 1)
		self._label3 = getUByte(data, 2)
		self._label4 = getUByte(data, 3)
		self._reserve1 = getUShort(data, 4)
		self._entries = (PartitionEntry(data[6:22]),
			PartitionEntry(data[22:38]),
			PartitionEntry(data[38:54]),
			PartitionEntry(data[54:70]))
		self._sign5 = getUShort(data, 70)  
		
			
class Spy:
	'''A MBR partition table inspector.
	'''
	def __init__(self):
		'''Decodes the boot sector.
		'''
		self._verbose = True

	def usage(self, message = None):
		print('''mbrspy.py <opts> <dev> print [<print_opts>]
<print_opts>:
 -m        output is readable for machines
 -h        output is readable for humans
 -a        print invalid entries too
Example:
mbrspy.py /dev/sdc print -m -a
''')
		if message != None:
			print("+++ " + message)
		sys.exit(1)

	def processPrint(self, dev, argv):
		'''Handle the print command
		@param dev: 	the device, e.g. "/dev/sdc"
		@param argv:	the arguments for the print command
		'''
		mode = "human"
		printAll = False
		while len(argv) > 0:
			arg = argv[0]
			if arg.startswith('-h'):
				mode = "human"
			elif arg.startswith('-m'):
				mode = "machine"
			elif arg.startswith('-a'):
				printAll = True
			elif arg.startswith('-'):
				self.usage("unknown option: " + arg)
			argv = argv[1:]
		stream = open(dev, "rb")
		sector = stream.read(512)
		if len(sector) != 512:
			usage("cannot read first sector")
		table = PartitionTable(sector[440:])
		table.out(mode, dev, printAll)
		
	def process(self, argv):
		'''Decodes arguments and processes it.
		@param argv:	the program arguments
		'''
		while len(argv) > 0:
			arg = argv[0]
			if not arg.startswith('-'):
				break
			elif arg.startswith('-q'):
				self._verbose = False
			elif arg.startswith('-'):
				self.usage("unknown option: " + arg)
			argv = argv[1:]
		if len(argv) < 2:
			self.usage("too few arguments")
		dev = argv[0]
		mode = argv[1]
		argv = argv[2:]
		if not os.path.exists(dev):
			usage("unknown device")
		
		if mode == "print":
			self.processPrint(dev, argv)
		else:
			self.usage("unknown mode: " + mode)

if __name__ == "__main__":
    spy = Spy()
    spy.process(sys.argv[1:])
