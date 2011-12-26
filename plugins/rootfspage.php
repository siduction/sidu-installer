<?php
include "plugins/diskinfo.php";
/**
 * Builds the core content of the root file system page.
 * Implements a plugin.
 * 
 * @author hm
 */
class RootfsPage extends Page{
	/// an instance of DiskInfo
	var $diskInfo;
	/// name of the file containing the partition info
	var $filePartInfo;
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'rootfs');
		$value = $this->getUserData('reload.partinfo');
		$forceRebuild = ! empty($value);
		if ($forceRebuild)
			$this->setUserData('reload.partinfo', '');
		$this->diskInfo = new DiskInfo($session, $this, $forceRebuild);
			
		$this->setDefaultOption('filesys', 1, true);
		$this->setDefaultOption('disk', 0, true);
		$this->setDefaultOption('disk2', 0, true);
		$this->setDefaultOption('partman', 0, true);
		$this->setDefaultOption('filesys', 0, true);
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->session->trace(TRACE_RARE, 'RootfsPage.build()');
		$this->readContentTemplate();
		$this->readHtmlTemplates();
		if ($this->getRowCount('partinfo') > 0)
			$this->replacePartWithTemplate('INFO_TABLE');
		else
			$this->clearPart('INFO_TABLE');
		$this->fillOptions('filesys');
		$this->fillOptions('root', true);
		$this->fillOptions('disk2', true);
		$this->fillRows('partinfo');
		$this->diskInfo->buildInfoTable();
		$text = $this->diskInfo->getWaitForPartitionMessage();
		$this->content = str_replace('###WAIT_FOR_PARTINFO###', $text, 
			$this->content);
	}
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('disk', 'partman', 'root', 'filesys', 'disk2');
		return $rc;
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
		} elseif (strcmp($button, 'button_next') == 0){
			$this->session->userData->setValue('mountpoint', 'mounts.rowcount', 0);
			$value = $this->session->getField('root');
			if (strcmp($value, '-') == 0)
				$redraw = ! $this->setFieldError('root', 
					$this->i18n('ERR_EMPTY_ROOT', 'No root partition chosen!'));
			else
				$redraw = $this->navigation(false);
		} elseif (strcmp($button, 'button_prev') == 0){
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