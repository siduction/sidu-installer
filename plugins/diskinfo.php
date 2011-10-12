<?php
define ('SEPARATOR_PARTITION', '|');
define ('SEPARATOR_INFO', "\t");
/**
 * Administrates the disk and partition infos.
 * 
 */
class DiskInfo {
	/// the current plugin
	var $page;
	/// the session info
	var $session;
	/// an array of PartitionInfo.
	var $partitions;
	/** Constructor.
	 * 
	 * @param $session	the session info
	 * @param $page		the current plugin. Type: Derivation of Page
	 */
	function __construct(&$session, $page){
		$this->session = $session;
		$this->page = $page;
		$this->name = $page->name;
		$this->partitions = NULL;
	}
	/** Writes the partition info into the user data.
	 */
	function writePartitionInfo(){
		$this->session->trace(TRACE_RARE, 'DiskInfo.writePartitionInfo()');
		$file = File($this->page->filePartInfo);
		$partitions = '';
		while( (list($no, $line) = each($file))){
			$line = chop($line);
			$cols = explode("\t", $line);
			$dev = $cols[0];
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
	 * 
	 * @param $force	true: the data will be read always. false: reading is done 
	 */
	function readPartitionInfo($force = false){
		$this->session->trace(TRACE_RARE, 'DiskInfo.readPartitionInfo()');
		if ($force || $this->partitions == NULL)
		{
			// @todo Simulation!
			$value = $this->session->userData->getValue('', 'partinfo');
			if (empty($value))
				$this->writePartitionInfo();
			$disks = array();
			$devs = '-';
			$labels = '-';
			$info = $this->session->userData->getValue('', 'partinfo');
			$this->partitions = array();
			if (!empty($info)){
				$parts = explode(SEPARATOR_PARTITION, $info);
				foreach($parts as $key => $info){
					$item = new PartitionInfo($info);
					$disk = preg_replace('/[0-9]/', '', $item->device);
					if (empty($disk))
						continue;
					if (! isset($disks[$disk])){
						$disks[$disk] = 1;
					}
					$this->partitions[$item->device] = $item;
					$devs .= ';' . $item->device;
					if (! empty($item->label)){
						$labels .= ';' . $item->label;
					}
				}
				$disklist = '';
				foreach ($disks as $key => $val)
					$disklist .= ';' . $key;
					
				$this->session->userData->setValue('rootfs', 'opt_disk', $this->page->getConfiguration('txt_all') . $disklist);
				$this->session->userData->setValue('rootfs', 'opt_disk2', substr($disklist, 1));
				$this->session->userData->setValue('mountpoint', 'opt_disk2', substr($disklist, 1));
				$this->session->userData->setValue('rootfs', 'opt_root', substr($devs, 2));
				$this->session->userData->setValue('mountpoint', 'opt_add_dev', $devs);
				$this->session->userData->setValue('mountpoint', 'opt_add_label', $labels);
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
		$this->readPartitionInfo();
		$disk = $this->session->getField('disk2');
		if (! empty($disk)){
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
	/// size and unit, e.g. 1.2 GB
	var $size;
	/// partition type
	var $partType;
	/// e.g. ext4
	var $filesystem;
	/// additional info
	var $info;
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