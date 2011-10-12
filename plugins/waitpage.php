<?php
/**
 * Waits for the end of an application.
 * 
 * Implements a plugin.
 * 
 * @author hm
 */
class WaitPage extends Page{
	
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'wait');
		$sleep = $this->getConfiguration('refresh');
		$session->metaDynamic = '<meta http-equiv="refresh" content="' . $sleep . '; URL="' . $session->urlForm . '/>';
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->session->trace(TRACE_RARE, 'WaitPage.build()');
		$demoText = '';
		$file = $this->getUserData('answer');
		if (file_exists($file)){
			unlink($file);
			$this->stop('wait.ready');
		} else{
			$this->readContentTemplate();
			// We bring forward the replacement because of the texts contain markers themself.
			$this->replaceTextMarkers();
			$this->replaceMarkers();
			$value = $this->getUserData('description');
			$this->content = str_replace('###DESCRIPTION###', $value, $this->content);
			$value = $this->getUserData('program');
			$this->content = str_replace('###PROGRAM###', $value, $this->content);
			$procent = -1;
			if (! file_exists('/etc/inosid/demo_progress')){
				$value = $this->getUserData('progress');
				if (file_exists($value))
					$procent = (int) $this->session->readFile($value);
			} else {
				$demoText = $this->getConfiguration('txt_demotext');
				$value = $this->getUserData('demo.progress');
				$this->session->trace(TRACE_FINE, 'WaitPage.build() Progress: ' . $value);
				$procent = (int) $value; 
				$this->setUserData('demo.progress', strval ($procent + 10));
			}				 
			if ($procent < 0)
				$this->content = str_replace('###PROGRESS###', '', $this->content);
			else {
				if ($procent > 100)
					$this->stop('wait.100%');
				$value = $this->session->readFileFromBase('plugins/wait.progress.txt', false);
				$value = str_replace('###PROCENT###', strval($procent) . '%', $value);
				$value = str_replace('###WIDTH###', strval ($procent), $value);
				$this->content = str_replace('###PROGRESS###', $value, $this->content);
				$this->content = str_replace('###DEMO_TEXT###', $demoText, $this->content);
			}
			
		}
	}
	/** Stops the waiting.
	 * 
	 * @param $from		the reason of the stop (for tracing)
	 * @return false
	 */
	function stop($from){
			$this->session->trace(TRACE_RARE, 'WaitPage.stop()');
			$this->setUserData('answer', '');
			$this->setUserData('program', '');
			$caller = $this->getUserData('caller');
			
			$this->setUserData('description', '');
			$this->setUserData('progress', '');
			$this->session->gotoPage($caller, $from);
			$this->session->userData->write();
			$this->setUserData('demo_progress', '');
			return false;
	}		
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array();
		return $rc;
	}
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$this->session->trace(TRACE_RARE, 'WaitPage.onButtonClick() ' . $button);
		$redraw = true;
		if (strcmp($button, "button_cancel") == 0){
			$redraw = $this->stop('wait.cancel');
		}
		return $redraw;
	} 
}
