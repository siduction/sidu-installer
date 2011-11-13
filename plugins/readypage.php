<?php
/**
 * Will be called when the installation is finished.
 * Implements a plugin.
 * 
 * @author hm
 */
class ReadyPage extends Page{
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'ready');
		$this->setDefaultOption('force', 0, true);
		$duration = $session->userData->getValue('run', 'duration');
		if (empty($duration)){
			$duration = time() - (int) $value;
			if ($duration > 3600)
				$duration = sprintf("%d:%02d:%02d", $duration / 3600, $duration % 3600 / 60, $duration % 60);
			else					
				$duration = sprintf("%02d:%02d", $duration % 3600 / 60, $duration % 60);
		}
		$session->userData->setValue('run', 'duration', $duration);

		# $this->setReplacement('###ROOT_FS###', $rootfs);
	}
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array();
		return $rc;
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
		$duration = $this->session->userData->getValue('run', 'duration');
		$text = $this->getConfiguration('txt_runtime');
		$text = str_replace('###DURATION###', $duration, $text);
		$this->content = str_replace('###txt_runtime###', $text, $this->content);
		$answer = $this->session->userData->getValue('wait', 'file.answer');
		$text = ! file_exists($answer) ? '' : $this->session->readFile($answer);
		$this->content = str_replace('###DETAILS###', $text, $this->content);
		return $this->content;
	}	
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$rc = true;
		if (strcmp($button, 'button_reboot') == 0){
			$this->session->exec(NULL, SVOPT_DEFAULT, 'reboot', "", 0);
		} else {
			$this->session->log("unknown button: $button");
		}
		return $rc;
	} 
}
?>