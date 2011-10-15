<?php
/**
 * Builds the core content of the user settings page.
 * Implements a plugin.
 * 
 * @author hm
 */
class UserPage extends Page{
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'user');
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
	}
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('root_pass', 'root_pass2', 'real_name', 'name', 'pass', 'pass2');
		return $rc;
	}
	/** Checks the input fields for validity.
	 * 
	 * @return true: All fields have valid content. false: otherwise
	 */
	function validate(){
		$ok = true;
		if (! $this->validPasswords('root_pass', 'root_pass2', 6, 20))
			$ok = false;
		if (! $this->isValidContent('real_name', '^:', '^:', false))
			$ok = false;
		if (! $this->isValidContent('name', 'a-z', '-a-z0-9_', true))
			$ok = false;
		if (! $this->validPasswords('pass', 'pass2', 6, 20))
			$ok = false;
		return $ok;
	}
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$redraw = true;
		if (strcmp($button, "button_next") == 0){
			$ok = $this->validate();
			if ($ok)
				$redraw = $this->navigation(false);
		} else {
			if (strcmp($button, "button_prev") == 0){
				$redraw = $this->navigation(true);
			} else {
				$this->session->log("unknown button: $button");
			}
		}
		return $redraw;
	} 
}
?>