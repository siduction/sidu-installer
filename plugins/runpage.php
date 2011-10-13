<?php
/**
 * Builds the core content of the last page which runs the installation.
 * Implements a plugin.
 * 
 * @author hm
 */
class RunPage extends Page{
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'run');
		$this->setDefaultOption('force', 0, true);
		$this->setReplacement('###BUTTON_OR_INFO###', 
			$this->getConfiguration('button'), false);
		$rootfs = $session->userData->getValue('rootfs', 'root');
		$this->setReplacement('###ROOT_FS###', $rootfs);
	}
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('force');
		return $rc;
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
		$this->fillOptions('force');
		return $this->content;
	}	
	/** Sends a request to the shell server and go into wait state.
	 */
	function startInstallation(){
		$answer = $this->session->getAnswerFileName('inst', '.ready');
		$description = $this->getConfiguration('description_wait'); 
		$program = 'installation';
		$progress = $this->session->getAnswerFileName('progress', '.dat');
		$params = array();
		$params[] = "progress=" . $progress;
		$params[] = "timezone=" . $this->session->userData->getValue('boot', 'region')
			. '/' . $this->session->userData->getValue('boot', 'city');
		$params[] = "rootpart=" . $this->session->userData->getValue('rootfs', 'root');
		$curValue = $this->session->userData->getValue('rootfs', 'filesys');
		if ($this->indexOfList('rootfs', 'filesys', NULL, 'opt_filesys') <= 0) 
			$curValue = '-';
		$params[] = "rootfs=" . $curValue;
		$ix = $this->indexOfList('rootfs', 'filesys', NULL, 'opt_filesys');
		$count = $this->session->userData->getValue('mountpoint', 'mounts.rowcount');
		$mounts = '';
		for ($ix = 0; $ix < $count; $ix++){
			$value = $this->session->userData->getValue('mountpoint', "mounts.row$ix");
			// /dev/sda9|data|ext4|/data|BUTTON_DEL_1
			$list = explode('|', $value);
			$mounts .= ';' . $list[0] . '|' . $list[3] . '|' . $list[2] . '|' . $list[1];
		}
		$params[] = substr($mounts, 1);
		$ix = $this->indexOfList('boot', 'loader', NULL, 'opt_loader');
		$params[] = "bootmanager=" . ($ix == 0 ? "-" : $this->session->userData->getValue('boot', 'loader'));
		$ix = $this->indexOfList('boot', 'target', NULL, 'opt_target');
		$params[] = "bootdest=" . ($ix == 0 ? 'mbr' : 'partition');
		$ix = $this->indexOfList('network', 'ssh', NULL, 'opt_ssh');
		$params[] = "ssh=$ix";
		$params[] = "rootpw=" . $this->session->userData->getValue('user', 'root_pass');
		$params[] = "username=" . $this->session->userData->getValue('user', 'real_name');
		$params[] = "login=" . $this->session->userData->getValue('user', 'name');
		$params[] = "pw=" . $this->session->userData->getValue('user', 'pass');
		$params[] = "hostname=" . $this->session->userData->getValue('network', 'host');
		$options = "background requestfile";
		$command = "install";
		$this->session->exec($answer, $options, $command, $params, 0);
		$redraw = $this->startWait($answer, $program, $description, $progress);
	}	
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$rc = true;
		$value = $this->session->getField('running');
		if (! empty($value))
		{
			$text = $this->getConfiguration('info_running');
			$this->setReplacement('###BUTTON_OR_INFO###', $text, false);
		}
			
		if (strcmp($button, 'button_install') == 0){
			$this->session->userData->setValue('run', 'running', 'T');
			$this->setField('running', 'T');
			$this->startInstallation();
		}
		elseif (strcmp($button, 'button_prev') == 0){
			$page = $this->session->getPrevPage('run');
			$this->session->gotoPage($page, 'run.next');
			$rc = false;
		} else {
			$this->session->log("unknown button: $button");
		}
		return $rc;
	} 
}
?>