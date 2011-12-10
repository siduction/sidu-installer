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
		$this->diskInfo = new DiskInfo($session, $this, false);
		$ix = $this->getRowCount('mounts');
		$dev = $this->session->userData->getValue('rootfs', 'root');
		if ($ix == 0 && ! empty($dev)){
			$dev = $this->session->userData->getValue('rootfs', 'root');
			$label = $this->diskInfo->getPartitionLabel($dev);
			$fs = $this->session->userData->getValue('rootfs', 'filesys');
			$ix2 = $this->indexOfList('rootfs', 'filesys', NULL, 'opt_filesys');
			if ($ix2 <= 0) 
				$fs = $this->diskInfo->getPartitionFs($dev);
			$row = "$dev|$label|$fs|/|";
			$this->setRow('mounts', $row);
		}
		$this->diskInfo->respectMountPoints();
		$this->setDefaultOption('add_dev', 0, false);
		$this->setDefaultOption('add_label', 0, false);
		$this->setDefaultOption('add_mount', 0, false);
		$this->setField('add_mount2', '');
		$this->setDefaultOption('mountonboot', 1, true);
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
		$this->readHtmlTemplates();
		$this->setButtonSelectedPart('DEV_SELECTOR', 'DEVICE', 'LABEL');
		$this->setButtonSelectedPart('POINT_SELECTOR', 'POINT_COMBO', 'POINT_TEXT');
		$this->fillOptions('disk2', true);
		$this->fillOptions('add_dev', true);
		$this->fillOptions('add_label', true);
		$this->fillOptions('add_mount');
		$this->fillOptions('mountonboot');
		$this->fillRows('mounts');		
		$this->fillRows('partinfo');
		$text = $this->diskInfo->getWaitForPartitionMessage();
		$this->content = str_replace('###WAIT_FOR_PARTINFO###', $text, 
			$this->content);
	}
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('add_dev', 'add_label', 'add_mount', 
			'add_mount2', 'disk2', 'mountonboot');
		return $rc;
	}
	/** Handles the "add mountpoint" button.
	 */
	function addMount(){
		$ok = true;
		$devSelector = $this->getUserData('DEV_SELECTOR');
		if (strcmp($devSelector, 'DEVICE') == 0)
		{
			$dev = $this->session->getField('add_dev');
			$label = $this->diskInfo->getPartitionLabel($dev);
		} else {
			$label = $this->session->getField('add_label');
			$dev = $this->diskInfo->getPartitionName($label);
		}
			
		$val1 = $this->session->getField('add_mount');
		$val2 = $this->session->getField('add_mount2');
		if (strncmp($val1, '/', 1) == 0){
			if (empty($val2))
				$mount = $val1;
			else
				$ok = $this->setFieldErrorByKey('add_mount2', 'ERR_NO_MOUNT');
		} elseif (strncmp($val2, '/', 1) != 0)
			$ok = $this->setFieldErrorByKey('add_mount2', 'ERR_WRONG_MOUNT');
		elseif (strcmp($val2, '/') == 0)
			$ok = $this->setFieldErrorByKey('add_mount2', 'ERR_IS_ROOT');
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
		$this->diskInfo->respectMountPoints();
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
		} elseif (strcmp($button, 'button_DEV_SELECTOR') == 0){
			$this->switchPartByButton('DEV_SELECTOR', 'DEVICE', 'LABEL');
		} elseif (strcmp($button, 'button_POINT_SELECTOR') == 0){
			$this->switchPartByButton('POINT_SELECTOR', 'POINT_COMBO', 'POINT_TEXT');
		} elseif (strcmp($button, "button_next") == 0){
			$redraw = $this->navigation(false);
		} elseif (strcmp($button, "button_prev") == 0){
			$redraw = $this->navigation(true);
		} elseif (strncmp($button, 'button_del_', 11) == 0){
			$ix = (int) substr($button, 11);
			$this->delRow('mounts', $ix);
			$this->diskInfo->respectMountPoints();
		} else {
			$this->session->log("unknown button: $button");
		}
		return $redraw;
	} 
}
?>