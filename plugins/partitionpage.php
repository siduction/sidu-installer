<?php
include "plugins/diskinfo.php";
/**
 * Offers the possability to change the partition scheme.
 * Implements a plugin.
 *
 * @author hm
 */
class PartitionPage extends Page{
	/// an instance of DiskInfo
	var $diskInfo;
	/// name of the file containing the partition info
	var $filePartInfo;
	/** Constructor.
	 *
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'partition');
		$this->diskInfo = new DiskInfo($session, $this, false);

		$this->setDefaultOption('disk', 0, true);
		$this->setDefaultOption('disk2', 0, true);
		$this->setDefaultOption('partman', 0, true);
	}
	/** Builds the core content of the page.
	 *
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->session->trace(TRACE_RARE, 'Overview.build()');
		$this->readContentTemplate();
		$this->readHtmlTemplates();

		$text = $this->diskInfo->getWaitForPartitionMessage();
		if (empty($text)){
			$this->replacePartWithTemplate('PARTITION_INFO');
		} else {
			$this->replacePartWithTemplate('PARTITION_INFO', 'WAIT_FOR_PARTINFO');
			$this->content = str_replace('###txt_no_info###', $text, $this->content);
		}

		if ($this->getRowCount('partinfo') > 0)
			$this->replacePartWithTemplate('INFO_TABLE');
		else
			$this->clearPart('INFO_TABLE');

		$this->fillOptions('disk', true);
		$this->fillOptions('partman');
		$this->fillOptions('disk2', true);
		$this->fillRows('partinfo');
		$this->diskInfo->buildInfoTable();
	}
	/** Returns an array containing the input field names.
	 *
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('disk', 'partman', 'disk2');
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
		} elseif (strcmp($button, 'button_reload') == 0){
			$this->diskInfo->forceReload();
			$this->session->gotoPage('partition', 'partition.onButtonClick');
		} elseif (strcmp($button, 'button_exec') == 0){
			$answer = $this->session->getAnswerFileName('part', '.ready');
			$description = $this->getConfiguration('description_wait');
			$program = $this->session->getField('partman');
			$disk = $this->session->getField('disk');
			$progress = null;
			$value = $this->getConfiguration('cmd_' . $program);
			list($allDisksAllowed, $options, $command, $params) = explode(CONFIG_SEPARATOR, $value);
			// All disks?
			$ix = $this->indexOfList('partition', 'disk', 'opt_disk', null);
			if ($ix == 0)
				$disk = '';
			if (strcmp($allDisksAllowed, 'y') != 0 && empty($disk))
				$redraw = ! $this->setFieldErrorByKey('disk', 'ERR_ALL_NOT_ALLOWED');
			else{
				$params = str_replace('###DISK###', empty($disk) ? '' : "/dev/$disk", $params);
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
				// Partition info is potentially changed. Reload necessary:
				$this->setUserData('reload.partinfo', 'T');
				$redraw = $this->startWait($answer, $program, $description, $progress);
				$this->session->trace(TRACE_RARE, 'onButton(): redraw: ' . strval($redraw));
			}
		} elseif (strcmp($button, 'button_next') == 0){
			$redraw = $this->navigation(false);
		} elseif (strcmp($button, 'button_prev') == 0){
			$redraw = $this->navigation(true);
		} else {
			$this->session->log("unknown button: $button");
		}
		return $redraw;
	}
}
?>