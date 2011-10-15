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
		$this->diskInfo = new DiskInfo($session, $this);
		$this->setDefaultOption('disk', 0, true);
		$this->setDefaultOption('disk2', 0, true);
		$this->setDefaultOption('partman', 0, true);
		$this->setDefaultOption('filesys', 0, true);
		$this->filePartInfo = $this->getConfiguration('file.demo.partinfo');
		if (! file_exists($this->filePartInfo))
			$this->filePartInfo = $this->getConfiguration('file.partinfo');
		if (! file_exists($this->filePartInfo))
			$session->exec($this->filePartInfo, SVOPT_DEFAULT,
				 'partinfo', NULL, 0);
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->session->trace(TRACE_RARE, 'RootfsPage.build()');
		$this->diskInfo->readPartitionInfo();
		$this->readContentTemplate();
		$this->fillOptions('disk', true);
		$this->fillOptions('partman');
		$this->fillOptions('filesys');
		$this->fillOptions('root', true);
		$this->fillOptions('disk2', true);
		$this->fillRows('partinfo');		
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
		} elseif (strcmp($button, "button_exec") == 0){
			$answer = $this->session->getAnswerFileName('part', '.ready');
			$description = $this->getConfiguration('description_wait'); 
			$program = $this->session->getField('partman');
			$disk = $this->session->getField('disk');
			$progress = null;
			$value = $this->getConfiguration('cmd_' . $program);
			list($allDisksAllowed, $options, $command, $params) = explode(CONFIG_SEPARATOR, $value);
			// All disks?
			if (strpos($disk, '/') === FALSE)
				$disk = '';
			if (strcmp($allDisksAllowed, 'y') != 0 && empty($disk))
				$redraw = ! $this->setFieldErrorByKey('disk', 'ERR_ALL_NOT_ALLOWED');
			else{
				$params = str_replace('###DISK###', empty($disk) ? '' : $disk, $params);
				$user = posix_getlogin();
				if (empty($user)){
					// use standard user (uid=1000)
					$user = posix_getpwuid (1000);
					if ($user)
						$user = $user['name'];
				}
				$params = str_replace('###USER###', $user ? $user : 'root', $params);
				
				$params = explode('|', $params);
				$this->session->exec($answer, $options, $command, $params, 0);
				$redraw = $this->startWait($answer, $program, $description, $progress);
				$this->session->trace(TRACE_RARE, 'onButton(): redraw: ' . strval($redraw));
			}
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