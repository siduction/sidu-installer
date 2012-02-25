<?php
/**
 * Builds the core content of the network page.
 * Implements a plugin.
 * 
 * @author hm
 */
class NetworkPage extends Page{
	
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'network');
		$this->setDefaultOption('ssh', 0, true);
		$this->setEmptyToDefault('host', 'network.DEFAULT_HOST');
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
		$this->fillOptions('ssh');
	}
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('host', 'ssh');
		return $rc;
	}
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$redraw = true;
		if (strcmp($button, 'button_next') == 0){
			$ok = $this->isValidContent('host', 'A-Za-z', '-A-Za-z0-9_', true);
			if ($ok)
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