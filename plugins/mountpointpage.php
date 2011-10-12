<?php
include "plugins/diskinfo.php";
/**
 * Builds the core content mountpoint definitions.
 * Implements a plugin.
 * 
 * @author hm
 */
class MountpointPage extends Page{
	/// instance of DiskInfo
	var $diskInfo;
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'mountpoint');
		$this->diskInfo = new DiskInfo($session, $this);
		$this->setDefaultOption('add_dev', 0, false);
		$this->setDefaultOption('add_label', 0, false);
		$this->setDefaultOption('add_mount', 0, false);
		$this->setField('add_mount2', '');
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->diskInfo->readPartitionInfo();
		$this->readContentTemplate();
		$this->fillOptions('disk2', true);
		$this->fillOptions('add_dev', true);
		$this->fillOptions('add_label', true);
		$this->fillOptions('add_mount');
		$this->fillRows('mounts');		
		$this->fillRows('partinfo');		
	}
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('add_dev', 'add_label', 'add_mount', 'add_mount2', 'disk2');
		return $rc;
	}
	/** Handles the "add mountpoint" button.
	 */
	function addMount(){
		$this->diskInfo->readPartitionInfo();
		$ok = true;
		$dev = $this->session->getField('add_dev');
		$label = $this->session->getField('add_label');
		if (strcmp($dev, '-') == 0 && strcmp($label, '-') == 0
			|| strcmp($dev, '-') != 0 && strcmp($label, '-') != 0)
			$ok = $this->setFieldErrorByKey('add_mount2', 'ERR_NO_DEVICE');
		else if (strcmp($dev, '-') == 0)
			$dev = $this->diskInfo->getPartitionName($label);
		else
			$label = $this->diskInfo->getPartitionLabel($dev);
			
		$val1 = $this->session->getField('add_mount');
		$val2 = $this->session->getField('add_mount2');
		if (strncmp($val1, '/', 1) == 0){
			if (empty($val2))
				$mount = $val1;
			else
				$ok = $this->setFieldErrorByKey('add_mount2', 'ERR_NO_MOUNT');
		} elseif (strncmp($val2, '/', 1) != 0)
			$ok = $this->setFieldErrorByKey('add_mount2', 'ERR_WRONG_MOUNT');
		else 
			$mount = $val2;
		if ($ok){
			$ix = $this->getRowCount('mounts');
			$fs = $this->diskInfo->getPartitionFs($dev);
			$row = "$dev|$label|$fs|$mount|BUTTON_DEL_$ix";
			$this->setRow('mounts', $row);
		}
		$this->setUserData('add_dev', '');
		$this->setUserData('add_label', '');
		$this->setUserData('add_mount', '');
		$this->setUserData('add_mount2', '');
		return $ok;
	}
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$redraw = true;
		if (strcmp($button, 'button_refresh') == 0){
			$this->diskInfo->buildInfoTable();
		} elseif (strcmp($button, 'button_add') == 0){
			$this->addMount();
		} elseif (strcmp($button, "button_next") == 0){
			$redraw = $this->navigation(false);
		} elseif (strcmp($button, "button_prev") == 0){
			$redraw = $this->navigation(true);
		} elseif (strncmp($button, 'button_del_', 11) == 0){
			$ix = (int) substr($button, 11);
			$this->delRow('mounts', $ix);
		} else {
			$this->session->log("unknown button: $button");
		}
		return $redraw;
	} 
}
?>