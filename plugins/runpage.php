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