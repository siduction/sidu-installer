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
		// Midori bug: midori calls page wait after reaching page ready.
		// Therefore we must block wait:
		$session->userData->setValue('wait', 'blocked', 'T');
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
		if (strpos($text, 'ended abnormally') > 0){
			$text = $this->getConfiguration('txt_failed');
			$this->replaceMarker('txt_intro', $text);
			// Enable the page "run":
			$this->session->userData->setValue('run', 'running', '');
			$this->session->userData->setValue('run', 'duration', '');
			$session->userData->setValue('wait', 'blocked', '');
		}
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