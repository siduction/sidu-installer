<?php
define ('SEPARATOR_PARTITION', '|');
define ('SEPARATOR_INFO', "\t");
define ('PAGE_PARTITION', 0);
define ('PAGE_ROOTFS', 1);
define ('PAGE_MOUNTPOINT', 2);
/**
 * Administrates the disk and partition infos.
 * 
 */
class DiskInfo {
	/// the current plugin
	var $page;
	/// the session info
	var $session;
	// the disk array: name => size in kbyte
	var $disks;
	/// an array of PartitionInfo.
	var $partitions;
	/// the file created by the shellserver
	var $filePartInfo;
	/// True: the partition info is avaliable.
	var $hasInfo;
	/// One of PAGE_PARTITION .. PAGE_MOUNTPOINT
	var $pageIndex;
	/** Constructor.
	 * 
	 * @param $session		the session info
	 * @param $page			the current plugin. Type: Derivation of Page
	 * @param $forceRebuild	Deletes the partition info file to force rebuilding
	 */
	function __construct(&$session, $page, $forceRebuild){
		$this->session = $session;
		$this->hasInfo = false;
		$this->page = $page;
		$this->name = $page->name;
		if (strcmp($this->name, "partition") == 0)
			$this->pageIndex = PAGE_PARTITION;
		elseif (strcmp($this->name, "rootfs") == 0)
			$this->pageIndex = PAGE_ROOTFS;
		else
			$this->pageIndex = PAGE_MOUNTPOINT;
			
		$this->partitions = NULL;
		$this->disks = array();
		$this->filePartInfo = $session->configuration->getValue(
			'diskinfo.file.demo.partinfo');
		if (! file_exists($this->filePartInfo))
			$this->filePartInfo = $session->configuration->getValue(
				'diskinfo.file.partinfo');
			
		if ($forceRebuild && file_exists($this->filePartInfo)){
			$this->session->userData->setValue('', 'partinfo', '');
			unlink($this->filePartInfo);
		}
		
		$wait = (int) $session->configuration->getValue('diskinfo.wait.partinfo');
		$maxWait = (int) $session->configuration->getValue('diskinfo.wait.partinfo.creation');
		if ($session->testFile($this->filePartInfo, 
				'partinfo.created', $wait, $maxWait))
			$session->exec($this->filePartInfo, SVOPT_DEFAULT,
				'partinfo', NULL, 0);
		$this->hasInfo = file_exists($this->filePartInfo);
		if ($this->hasInfo)
			$this->readPartitionInfo();
		else
			$this->clearPartitionInfo();
	}
	/** Forces the reload of the partition info.
	 */
	function forceReload(){
		if (file_exists($this->filePartInfo))
			unlink($this->filePartInfo);
	}
	/** Sets all gui info related with partition info to undefined.
	 */
	function clearPartitionInfo(){
		$this->session->userData->setValue('partition', 'opt_disk', '-');
		$this->session->userData->setValue('partition', 'opt_disk2', '-');
		$this->session->userData->setValue('rootfs', 'opt_root', '-');
		$this->session->userData->setValue('rootfs', 'opt_disk2', '-');
		$this->session->userData->setValue('mountpoint', 'opt_disk2', '-');
		$this->session->userData->setValue('mountpoint', 'opt_add_dev', '-');
		$this->session->userData->setValue('mountpoint', 'opt_add_label', '-');
		$this->page->setRowCount('partinfo', 0);
	}	
	/** Gets the data of the partition info and put it into into the user data.
	 */
	function importPartitionInfo(){
		$this->session->trace(TRACE_RARE, 'DiskInfo.importPartitionInfo()');
		$file = File($this->filePartInfo);
		$partitions = '';
		$excludes = $this->session->configuration->getValue('diskinfo.excluded.dev');
		if (strlen($excludes) > 0)
			$excludes = '/' . str_replace('/', '\/', $excludes) . '/';
		
		while( (list($no, $line) = each($file))){
			$line = chop($line);
			$cols = explode("\t", $line);
			$dev = str_replace('/dev/', '', $cols[0]);
			if (strlen($excludes) != 0 && preg_match($excludes, $dev) > 0)
				continue;
			if (count($cols) == 2){
				// Disks
				$this->disks[$dev] = $cols[1];
				continue;
			}
			$infos = array();
			foreach($cols as $key => $value){
				$vals = explode(':', $value);
				if (count($vals) > 1){
					$infos[$vals[0]] = $vals[1];
				}
			}
			$size = isset($infos['size']) ? (int)$infos['size'] : 0;
			$label = isset($infos['label']) ? $infos['label'] : '';
			$ptype = isset($infos['ptype']) ? $infos['ptype'] : '';
			$fs = isset($infos['fs']) ? $infos['fs'] : '';
			$pinfo = isset($infos['pinfo']) ? $infos['pinfo'] : '';
			$debian = isset($infos['debian']) ? $infos['debian'] : '';
			$os = isset($infos['os']) ? $infos['os'] : '';
			$distro = isset($infos['distro']) ? $infos['distro'] : '';
			$subdistro = isset($infos['subdistro']) ? $infos['subdistro'] : '';
			$date = '';
			if (isset($infos['created']))
				$date = ' ' . $this->session->i18n('rootfs', 'CREATED', 'created') . ': ' . $infos['created'];
			if (isset($infos['modified']))
				$date .= ' ' . $this->session->i18n('rootfs', 'MODIFIED', 'modified') . ': ' . $infos['modified'];
						
			$info = empty($subdistro) ? $distro : $subdistro;
			if (empty($info))
				$info = $os;
			if (! empty($date))
				$info .= $date;
			$partitions .= "|$dev\t$label\t$size\t$ptype\t$fs\t$info";
		}
		// strip the first separator:
		$partitions = substr($partitions, 1);
		$this->session->userData->setValue('', 'partinfo', $partitions);
	}
	/** Reads the partition infos from the user data.
	 */
	function readPartitionInfo(){
		$this->session->trace(TRACE_RARE, 'DiskInfo.readPartitionInfo()');
		if ($this->hasInfo)
			$this->importPartitionInfo();
		switch($this->pageIndex)
		{
			case PAGE_MOUNTPOINT:
				$excludedPartition = $this->session->userData->getValue('rootfs', 'root');
				break;
			case PAGE_PARTITION:
			case PAGE_ROOTFS:
			default:
				$excludedPartition = "";
				break;
		}
		$value = $this->session->userData->getValue('', 'partinfo');
		$disks = array();
		$devs = '-';
		$labels = '-';
		$info = $this->session->userData->getValue('', 'partinfo');
		$minSize = (int) $this->session->configuration->getValue('diskinfo.root.minsize.mb');
		
		$this->partitions = array();
		$disklist = '';
		$diskOnlyList = '';
		if (empty($info)){
			foreach ($this->disks as $key => $val)
				$diskOnlyList .= ';' . $key;				
		}else{
			$parts = explode(SEPARATOR_PARTITION, $info);
			foreach($parts as $key => $info){
				$item = new PartitionInfo($info);
				$isSwap = strcmp($item->partType, '82') == 0 || strcmp($item->partType, '8200') == 0
					|| strcmp($item->filesystem, 'swap') == 0;
				$hasFileSys = ! empty($item->filesystem) && strcmp($item->filesystem, "LVM2_member") != 0;
				$ignored = strcmp($item->device, $excludedPartition) == 0
					|| $isSwap
					|| $this->pageIndex == PAGE_ROOTFS && $item->megabytes < $minSize && $item->megabytes > 0
					|| $this->pageIndex == PAGE_MOUNTPOINT && ! $hasFileSys;
				$disk = preg_replace('/[0-9]/', '', $item->device);
				if (empty($disk))
					continue;
				if (! isset($disks[$disk])){
					$disks[$disk] = 1;
				}
				$this->partitions[$item->device] = $item;
				// Ignore too small partitions and swap:
				if (! $ignored)
					$devs .= ';' . $item->device;
				if (! empty($item->label)){
					$labels .= ';' . $item->label;
				}
			}
			foreach ($disks as $key => $val)
				$disklist .= ';' . $key;
			foreach ($this->disks as $key => $val)
				if (! isset($disks[$key]))
					$disklist .= ';' . $key;				
		}
		if (! empty($disklist) || ! empty($diskOnlyList))
		{
			switch($this->pageIndex)
			{
				case PAGE_PARTITION:
					$this->session->userData->setValue('partition', 'opt_disk', $this->page->getConfiguration('txt_all') . $disklist . $diskOnlyList);
					$this->session->userData->setValue('partition', 'opt_disk2', $disklist);
					break;
				case PAGE_ROOTFS:
					$this->session->userData->setValue('rootfs', 'opt_disk', $this->page->getConfiguration('txt_all') . $disklist . $diskOnlyList);
					$this->session->userData->setValue('rootfs', 'opt_disk2', $disklist);
					$this->session->userData->setValue('rootfs', 'opt_root', $devs);
					break;
				case PAGE_MOUNTPOINT:
					$this->session->userData->setValue('mountpoint', 'opt_disk2', $disklist);
					$this->session->userData->setValue('mountpoint', 'opt_add_dev', substr($devs, 2));
					$this->session->userData->setValue('mountpoint', 'opt_add_label', substr($labels, 2));
					break;
				default:
					break;
			}
		}
	}	
	/** Gets the label of a device.
	 * 
	 * @param $device	the name of the device, e.g. sda1
	 * @return '': no label available. Otherwise: the label of the device
	 */
	function getPartitionLabel($device){
		$rc = '';
		if (isset($this->partitions[$device]))
			$rc = $this->partitions[$device]->label;
		return $rc;
	}
	/** Gets the filesystem of a device.
	 * 
	 * @param $device	the name of the device, e.g. sda1
	 * @return '': no filesystem available. Otherwise: the filesystem of the device
	 */
	function getPartitionFs($device){
		$rc = '';
		if (isset($this->partitions[$device]))
			$rc = $this->partitions[$device]->filesystem;
		return $rc;
	}
	/** Gets the device name of a device given by its label.
	 * 
	 * @param $label	the label of the wanted device 
	 * @return '': no label available. Otherwise: the label of the device
	 */
	function getPartitionName($label){
		$rc = '';
		foreach($this->partitions as $key => $item){
			if (strcmp($label, $item->label) == 0){
				$rc = $key;
				break;
			}
		}
		return $rc;
	}
	/** Returns the partitions of a given disk.
	 * 
	 * @param $disk	the name of the disk, e.g. sda
	 * @return an array with the partitions (type PartitionInfo)
	 */
	function getPartitionsOfDisk($disk){
		$rc = array();
		$len = strlen($disk);
		foreach($this->partitions as $dev => $item){
			if (strncmp($disk, $dev, $len) == 0)
				$rc[$dev] = $item;
		}
		return $rc;
	}
	/** Builds dynamic part of the partition info table.
	 */
	function buildInfoTable(){
		$disk = $this->session->getField('disk2');
		$disk = trim($disk);
		if (! ($this->hasInfo && ! empty($disk)))
			$this->page->setRowCount('partinfo', 0);
		else {
			$partitions = $this->getPartitionsOfDisk($disk);
			$this->page->setRowCount('partinfo', 0);
			foreach ($partitions as $dev => $item){
				$label = $item->label;
				$fs = $item->filesystem;
				$size = $item->size;
				$type = $item->partType;
				$info = $item->info;
				$dev = str_replace('/dev/', '', $dev);
				$row = "$dev|$label|$size|$type|$fs|$info";
				$this->page->setRow('partinfo', $row);
			}
		}
	}
	/** Returns a message that we must wait for the partition info.
	 * 
	 * @return '': Partition info is available. Otherwise: the info message
	 */
	function getWaitForPartitionMessage(){
		if ($this->hasInfo)
			$rc = '';
		else{
			$rc = $this->session->readFileFromPlugin('waitforpartinfo.txt', false);
			$text = $this->session->configuration->getValue('diskinfo.txt_wait_for_partinfo');
			$rc = str_replace('###txt_wait_for_partinfo###', $text, $rc);
		}
		return $rc;
	}
	/** Adapts the partition/label lists respecting the mountpoints.
	 * 
	 * The partitions belonging yet to a mountpoint will not appear in the selection lists.
	 */
	function respectMountPoints(){
		$page = $this->page;
		$count = $page->getRowCount('mounts');
		$value = $this->session->userData->getValue('mountpoint', 'opt_add_label');
		$labels = explode(';', $value);
		$value = $this->session->userData->getValue('mountpoint', 'opt_add_dev');
		$devices = explode(';', $value);
		for ($ix = 0; $ix < $count; $ix++){
			$line = $page->getRow('mounts', $ix);
			$cols = explode('|', $line);
			$dev = $cols[0];
			$label = $this->getPartitionLabel($dev);
			$ix2 = $this->session->findIndex($labels, $label);
			if ($ix2 >= 0)
				unset($labels[$ix2]);
			$ix2 = $this->session->findIndex($devices, $dev);
			if ($ix2 >= 0)
				unset($devices[$ix2]);
		}
		$value = implode(';', $labels);
		$this->session->userData->setValue('mountpoint', 'opt_add_label', $value);
		$value = implode(';', $devices);
		$this->session->userData->setValue('mountpoint', 'opt_add_dev', $value);
	}
}
/**
 * Implements a storage for a partition info.
 * @author hm
 */
class PartitionInfo{
	/// e.g. sda1
	var $device;
	/// volume label
	var $label;
	/// size and unit, e.g. 11GB
	var $size;
	/// partition type
	var $partType;
	/// e.g. ext4
	var $filesystem;
	/// additional info
	var $info;
	/// size in MByte
	var $megabytes;
	/** Constructor.
	 * 
	 * @param $info		the partition info, separated by "\t"
	 */
	function __construct($info){
		list($this->device, 
				$this->label, 
				$size,
				$this->partType, 
				$this->filesystem, 
				$this->info) 
			= explode(SEPARATOR_INFO, $info);
		$size = (int) $size;
		$this->megabytes = $size / 1000;
		if ($size < 10*1000)
			$size = sprintf('%dMB', $size);
		elseif ($size < 10*1000*1000)
			$size = sprintf('%dMB', $size / 1000);
		elseif ($size < 10*1000*1000*1000)
			$size = sprintf('%dGB', $size / 1000 / 1000);
		else
			$size = sprintf('%dTB', $size / 1000 / 1000 / 1000);
		$this->size = $size;
	}
}

?>